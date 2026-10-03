import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/import/import_repository.dart';

part 'store_import_event.dart';
part 'store_import_state.dart';

class StoreImportBloc extends Bloc<StoreImportEvent, StoreImportState> {
  StoreImportBloc({
    required StoreChannel sourceStore,
    ImportRepository? importRepository,
    CatalogSession? session,
  }) : _importRepository =
           importRepository ?? ServiceLocator.get<ImportRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(
         StoreImportState(
           sourceStore: sourceStore,
           // Selection refined after per-listing target probe.
           selectedIds: const {},
           isLoadingTargets: true,
         ),
       ) {
    on<StoreImportStarted>(_onStarted);
    on<StoreImportProductToggled>(_onProductToggled);
    on<StoreImportSelectAllPressed>(_onSelectAll);
    on<StoreImportDestinationSelected>(_onDestinationSelected);
    on<StoreImportRequestPressed>(_onRequestPressed);
    on<StoreImportClearRequestSent>(_onClearRequestSent);
    on<StoreImportSimulateApprovedPressed>(_onDecideApproved);
    on<StoreImportClearApproved>(_onClearApproved);
    on<StoreImportClearMessage>(_onClearMessage);
    add(const StoreImportStarted());
  }

  final ImportRepository _importRepository;
  final CatalogSession _session;
  static const _tag = 'StoreImportBloc';

  Future<void> _onStarted(
    StoreImportStarted event,
    Emitter<StoreImportState> emit,
  ) async {
    await _probeListings(emit);
  }

  void _onProductToggled(
    StoreImportProductToggled event,
    Emitter<StoreImportState> emit,
  ) {
    if (state.isBlocked(event.productId)) return;
    if (!state.isImportable(event.productId) &&
        state.listingAvailability.isNotEmpty) {
      return;
    }

    final next = Set<String>.from(state.selectedIds);
    if (next.contains(event.productId)) {
      next.remove(event.productId);
    } else {
      next.add(event.productId);
    }
    final resolved = _resolveDestination(
      selectedIds: next,
      listingTargets: state.listingTargets,
      listingAvailability: state.listingAvailability,
    );
    emit(
      state.copyWith(
        selectedIds: next,
        targets: resolved.pickerTargets,
        selectedDestinationId: resolved.destinationId,
        clearDestination: resolved.destinationId == null,
        clearError: resolved.error == null,
        errorMessage: resolved.error,
      ),
    );
  }

  void _onSelectAll(
    StoreImportSelectAllPressed event,
    Emitter<StoreImportState> emit,
  ) {
    final importable = state.importableIds;
    final allSelected =
        importable.isNotEmpty &&
        state.requestableSelectedIds.length == importable.length;
    final next = allSelected ? <String>{} : Set<String>.from(importable);
    final resolved = _resolveDestination(
      selectedIds: next,
      listingTargets: state.listingTargets,
      listingAvailability: state.listingAvailability,
    );
    emit(
      state.copyWith(
        selectedIds: next,
        targets: resolved.pickerTargets,
        selectedDestinationId: resolved.destinationId,
        clearDestination: resolved.destinationId == null,
        clearError: resolved.error == null,
        errorMessage: resolved.error,
      ),
    );
  }

  void _onDestinationSelected(
    StoreImportDestinationSelected event,
    Emitter<StoreImportState> emit,
  ) {
    emit(
      state.copyWith(
        selectedDestinationId: event.destinationStoreId,
        clearError: true,
      ),
    );
  }

  Future<void> _onRequestPressed(
    StoreImportRequestPressed event,
    Emitter<StoreImportState> emit,
  ) async {
    if (!state.canRequestImport) return;
    final destinationId = state.selectedDestinationId!;
    final listingIds = state.requestableSelectedIds.toList();
    if (listingIds.isEmpty) return;

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      String? lastRequestId;
      var sent = 0;
      for (final listingId in listingIds) {
        final created = await _importRepository.createImportRequest(
          listingId: listingId,
          destinationStoreId: destinationId,
        );
        lastRequestId = created.id;
        sent++;
      }
      AppLog.d(_tag, 'Import requests sent count=$sent');
      emit(
        state.copyWith(
          isSubmitting: false,
          requestSent: true,
          lastRequestId: lastRequestId,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Import request failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearRequestSent(
    StoreImportClearRequestSent event,
    Emitter<StoreImportState> emit,
  ) {
    emit(state.copyWith(clearRequestSent: true));
  }

  /// Approves the last outgoing request when acting as a source-store member.
  Future<void> _onDecideApproved(
    StoreImportSimulateApprovedPressed event,
    Emitter<StoreImportState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final requestId = state.lastRequestId;
      if (requestId != null && requestId.isNotEmpty) {
        await _importRepository.decide(
          requestId: requestId,
          decision: 'approved',
        );
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          isApproved: true,
          importedCount: state.requestableSelectedIds.length,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Import decision failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearApproved(
    StoreImportClearApproved event,
    Emitter<StoreImportState> emit,
  ) {
    emit(state.copyWith(clearApproved: true));
  }

  void _onClearMessage(
    StoreImportClearMessage event,
    Emitter<StoreImportState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _probeListings(Emitter<StoreImportState> emit) async {
    final ownId = _session.ownStoreId;
    if (ownId == null || ownId.isEmpty) {
      emit(
        state.copyWith(
          isLoadingTargets: false,
          selectedIds: const {},
          clearDestination: true,
          errorMessage: 'Join or create a store before importing catalogues.',
        ),
      );
      return;
    }

    final products = state.sourceStore.products;
    if (products.isEmpty) {
      emit(
        state.copyWith(
          isLoadingTargets: false,
          selectedIds: const {},
          clearDestination: true,
          errorMessage: 'No collections available to import from this store.',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoadingTargets: true, clearError: true));
    try {
      final listingTargets = <String, List<ImportTarget>>{};
      final availability = <String, ListingImportAvailability>{};

      final results = await Future.wait([
        for (final product in products)
          _fetchAllTargets(product.id).then((targets) => (product.id, targets)),
      ]);

      for (final (listingId, targets) in results) {
        listingTargets[listingId] = targets;
        availability[listingId] = listingAvailabilityFor(targets);
      }

      final importable =
          products
              .map((p) => p.id)
              .where(
                (id) =>
                    availability[id] == ListingImportAvailability.available,
              )
              .toSet();

      AppLog.d(
        _tag,
        'Probed ${products.length} listings; '
        'importable=${importable.length} '
        'blocked=${products.length - importable.length}',
      );

      final selected = Set<String>.from(importable);
      final resolved = _resolveDestination(
        selectedIds: selected,
        listingTargets: listingTargets,
        listingAvailability: availability,
      );

      String? bootError = resolved.error;
      if (importable.isEmpty) {
        final anyTarget = listingTargets.values.any((t) => t.isNotEmpty);
        bootError =
            anyTarget
                ? 'All products from this store are already in your stores or pending.'
                : 'Join or create a store before importing catalogues.';
      }

      emit(
        state.copyWith(
          isLoadingTargets: false,
          listingTargets: listingTargets,
          listingAvailability: availability,
          selectedIds: selected,
          targets: resolved.pickerTargets,
          selectedDestinationId: resolved.destinationId,
          clearDestination: resolved.destinationId == null,
          clearError: bootError == null,
          errorMessage: bootError,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Import targets probe failed', e);
      emit(
        state.copyWith(
          isLoadingTargets: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  _DestinationResolution _resolveDestination({
    required Set<String> selectedIds,
    required Map<String, List<ImportTarget>> listingTargets,
    required Map<String, ListingImportAvailability> listingAvailability,
  }) {
    final selectedImportable =
        selectedIds
            .where(
              (id) =>
                  listingAvailability[id] ==
                  ListingImportAvailability.available,
            )
            .toList();

    if (selectedImportable.isEmpty) {
      return const _DestinationResolution(
        destinationId: null,
        pickerTargets: [],
        error: null,
      );
    }

    Set<String>? intersection;
    final targetById = <String, ImportTarget>{};

    for (final listingId in selectedImportable) {
      final targets = listingTargets[listingId] ?? const <ImportTarget>[];
      final requestable = targets.where((t) => t.canRequest).toList();
      for (final t in requestable) {
        targetById[t.id] = t;
      }
      final ids = requestable.map((t) => t.id).toSet();
      intersection = intersection == null ? ids : intersection.intersection(ids);
    }

    final shared = intersection ?? <String>{};
    if (shared.isEmpty) {
      return const _DestinationResolution(
        destinationId: null,
        pickerTargets: [],
        error:
            'Selected products cannot be imported into the same store. Try fewer products.',
      );
    }

    final pickerTargets = [
      for (final id in shared)
        if (targetById[id] != null) targetById[id]!,
    ];

    final ownId = _session.ownStoreId;
    String? destinationId;
    if (pickerTargets.length == 1) {
      destinationId = pickerTargets.first.id;
    } else if (ownId != null && shared.contains(ownId)) {
      destinationId = ownId;
    } else {
      destinationId = pickerTargets.first.id;
    }

    return _DestinationResolution(
      destinationId: destinationId,
      pickerTargets: pickerTargets,
      error: null,
    );
  }

  Future<List<ImportTarget>> _fetchAllTargets(String listingId) async {
    final all = <ImportTarget>[];
    String? cursor;
    do {
      final page = await _importRepository.fetchTargets(
        listingId: listingId,
        cursor: cursor,
      );
      all.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);
    return all;
  }
}

class _DestinationResolution {
  const _DestinationResolution({
    required this.destinationId,
    required this.pickerTargets,
    required this.error,
  });

  final String? destinationId;
  final List<ImportTarget> pickerTargets;
  final String? error;
}
