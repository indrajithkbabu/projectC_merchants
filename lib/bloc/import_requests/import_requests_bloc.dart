import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/import/import_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'import_requests_event.dart';
part 'import_requests_state.dart';

class ImportRequestItem extends Equatable {
  const ImportRequestItem({
    required this.request,
    required this.direction,
    this.collectionName = '',
    this.counterpartyStoreName = '',
    this.isActing = false,
  });

  final ImportRequest request;
  final ImportRequestDirection direction;
  final String collectionName;
  final String counterpartyStoreName;
  final bool isActing;

  bool get isIncoming => direction == ImportRequestDirection.incoming;
  bool get isOutgoing => direction == ImportRequestDirection.outgoing;

  String get title {
    final name = collectionName.trim();
    return name.isEmpty ? 'Collection' : name;
  }

  String get subtitle {
    final name = counterpartyStoreName.trim();
    final who = name.isEmpty ? 'Their store' : name;

    if (isIncoming) {
      // Someone asked to import from my store into theirs.
      if (request.isPending) {
        return '$who wants to import this';
      }
      if (request.isApproved) {
        return 'You accepted $who\'s request';
      }
      if (request.isRejected) {
        return 'You declined $who\'s request';
      }
      return 'Request ${request.status}';
    }

    // Sent: I asked to import from their store into mine.
    if (request.isPending) {
      return '$who hasn\'t responded yet';
    }
    if (request.isApproved) {
      return '$who accepted — it\'s in your store';
    }
    if (request.isRejected) {
      return '$who declined your request';
    }
    if (request.isCancelled) {
      return 'You cancelled this request';
    }
    return 'Request ${request.status}';
  }

  ImportRequestItem copyWith({
    ImportRequest? request,
    ImportRequestDirection? direction,
    String? collectionName,
    String? counterpartyStoreName,
    bool? isActing,
  }) {
    return ImportRequestItem(
      request: request ?? this.request,
      direction: direction ?? this.direction,
      collectionName: collectionName ?? this.collectionName,
      counterpartyStoreName:
          counterpartyStoreName ?? this.counterpartyStoreName,
      isActing: isActing ?? this.isActing,
    );
  }

  @override
  List<Object?> get props => [
    request,
    direction,
    collectionName,
    counterpartyStoreName,
    isActing,
  ];
}

enum ImportRequestDirection { incoming, outgoing }

class ImportRequestsBloc
    extends Bloc<ImportRequestsEvent, ImportRequestsState> {
  ImportRequestsBloc({
    required String storeId,
    required String storeName,
    ImportRepository? importRepository,
    CollectionRepository? collectionRepository,
    StoreRepository? storeRepository,
  }) : _storeId = storeId,
       _importRepository =
           importRepository ?? ServiceLocator.get<ImportRepository>(),
       _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       super(
         ImportRequestsState(
           storeId: storeId,
           storeName: storeName,
           isLoading: true,
         ),
       ) {
    on<ImportRequestsStarted>(_onStarted);
    on<ImportRequestsRefreshed>(_onRefreshed);
    on<ImportRequestsAcceptPressed>(_onAccept);
    on<ImportRequestsRejectPressed>(_onReject);
    on<ImportRequestsClearMessage>(_onClearMessage);
    add(const ImportRequestsStarted());
  }

  final String _storeId;
  final ImportRepository _importRepository;
  final CollectionRepository _collectionRepository;
  final StoreRepository _storeRepository;
  static const _tag = 'ImportRequestsBloc';

  Future<void> _onStarted(
    ImportRequestsStarted event,
    Emitter<ImportRequestsState> emit,
  ) => _load(emit);

  Future<void> _onRefreshed(
    ImportRequestsRefreshed event,
    Emitter<ImportRequestsState> emit,
  ) => _load(emit);

  Future<void> _load(Emitter<ImportRequestsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final incoming = await _fetchDirection('incoming');
      final outgoing = await _fetchDirection('outgoing');
      final items = <ImportRequestItem>[
        for (final r in incoming)
          ImportRequestItem(
            request: r,
            direction: ImportRequestDirection.incoming,
          ),
        for (final r in outgoing)
          ImportRequestItem(
            request: r,
            direction: ImportRequestDirection.outgoing,
          ),
      ];
      // Pending first, then by expiresAt descending.
      items.sort((a, b) {
        final pendingCmp =
            (b.request.isPending ? 1 : 0) - (a.request.isPending ? 1 : 0);
        if (pendingCmp != 0) return pendingCmp;
        return b.request.expiresAt.compareTo(a.request.expiresAt);
      });

      final enriched = await Future.wait(items.map(_enrichItem));
      AppLog.d(_tag, 'Loaded ${enriched.length} import requests');
      emit(
        state.copyWith(
          isLoading: false,
          items: enriched,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Load import requests failed', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<List<ImportRequest>> _fetchDirection(String direction) async {
    final all = <ImportRequest>[];
    String? cursor;
    do {
      final page = await _importRepository.listStoreRequests(
        storeId: _storeId,
        direction: direction,
        limit: 50,
        cursor: cursor,
      );
      all.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);
    return all;
  }

  Future<ImportRequestItem> _enrichItem(ImportRequestItem item) async {
    var collectionName = item.collectionName;
    var counterparty = item.counterpartyStoreName;

    try {
      final detail = await _collectionRepository.fetchCollection(
        storeId: item.request.sourceStoreId,
        listingId: item.request.sourceListingId,
      );
      collectionName = detail.name;
    } catch (_) {}

    final otherStoreId =
        item.isIncoming
            ? item.request.destinationStoreId
            : item.request.sourceStoreId;
    try {
      final store = await _storeRepository.fetchStore(otherStoreId);
      counterparty = store.name;
    } catch (_) {}

    return item.copyWith(
      collectionName: collectionName,
      counterpartyStoreName: counterparty,
    );
  }

  Future<void> _onAccept(
    ImportRequestsAcceptPressed event,
    Emitter<ImportRequestsState> emit,
  ) => _decide(event.requestId, 'approved', emit, successMessage: 'Import request accepted.');

  Future<void> _onReject(
    ImportRequestsRejectPressed event,
    Emitter<ImportRequestsState> emit,
  ) => _decide(event.requestId, 'rejected', emit, successMessage: 'Import request rejected.');

  Future<void> _decide(
    String requestId,
    String decision,
    Emitter<ImportRequestsState> emit, {
    required String successMessage,
  }) async {
    if (state.actingRequestId != null) return;
    emit(
      state.copyWith(
        actingRequestId: requestId,
        items: [
          for (final item in state.items)
            item.request.id == requestId
                ? item.copyWith(isActing: true)
                : item,
        ],
        clearError: true,
        clearInfo: true,
      ),
    );
    try {
      final updated = await _importRepository.decide(
        requestId: requestId,
        decision: decision,
      );
      AppLog.d(_tag, 'Decided $decision for $requestId → ${updated.status}');
      emit(
        state.copyWith(
          clearActing: true,
          infoMessage: successMessage,
          items: [
            for (final item in state.items)
              item.request.id == requestId
                  ? item.copyWith(request: updated, isActing: false)
                  : item,
          ],
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Decide failed $decision', e);
      emit(
        state.copyWith(
          clearActing: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
          items: [
            for (final item in state.items)
              item.request.id == requestId
                  ? item.copyWith(isActing: false)
                  : item,
          ],
        ),
      );
    }
  }

  void _onClearMessage(
    ImportRequestsClearMessage event,
    Emitter<ImportRequestsState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearInfo: true));
  }
}
