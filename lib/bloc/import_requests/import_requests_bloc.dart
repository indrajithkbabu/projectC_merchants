import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/import_qa.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/import/import_repository.dart';

part 'import_requests_event.dart';
part 'import_requests_state.dart';

enum ImportRequestDirection { incoming, outgoing }

class ImportRequestListItem extends Equatable {
  const ImportRequestListItem({
    required this.batch,
    required this.direction,
    this.productIndex,
    this.isActing = false,
    this.actingProductId = '',
  });

  final ImportRequestBatch batch;
  final ImportRequestDirection direction;

  /// When set, this row is one product from [batch.products]
  /// (Received Approve/Decline cards and Sent status cards).
  final int? productIndex;
  final bool isActing;

  /// Product id currently being approved/declined (item-level).
  final String actingProductId;

  bool get isIncoming => direction == ImportRequestDirection.incoming;
  bool get isOutgoing => direction == ImportRequestDirection.outgoing;

  /// Focused product for per-item Received / Sent cards.
  ImportRequestProductRow? get focusProduct {
    final i = productIndex;
    if (i == null || i < 0 || i >= batch.products.length) return null;
    return batch.products[i];
  }

  ImportRequestListItem copyWith({
    ImportRequestBatch? batch,
    int? productIndex,
    bool? isActing,
    String? actingProductId,
    bool clearActingProduct = false,
  }) {
    return ImportRequestListItem(
      batch: batch ?? this.batch,
      direction: direction,
      productIndex: productIndex ?? this.productIndex,
      isActing: isActing ?? this.isActing,
      actingProductId:
          clearActingProduct
              ? ''
              : (actingProductId ?? this.actingProductId),
    );
  }

  @override
  List<Object?> get props => [
    batch,
    direction,
    productIndex,
    isActing,
    actingProductId,
  ];
}

class ImportRequestsBloc
    extends Bloc<ImportRequestsEvent, ImportRequestsState> {
  ImportRequestsBloc({
    required String storeId,
    required String storeName,
    ImportRepository? importRepository,
  }) : _storeId = storeId,
       _importRepository =
           importRepository ?? ServiceLocator.get<ImportRepository>(),
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
    on<ImportRequestsCancelPressed>(_onCancel);
    on<ImportRequestsClearMessage>(_onClearMessage);
    add(const ImportRequestsStarted());
  }

  final String _storeId;
  final ImportRepository _importRepository;
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
      final received = await _fetchTab('received');
      final sent = await _fetchTab('sent');
      // Received: one row per unique product (newest batch wins). Avoids
      // duplicate cards when BE returns multiple batches for the same Send.
      // Sent: one row per product so mixed approve/decline is visible
      // (batch envelope stays one request; Cancel remains batch-level).
      final items = <ImportRequestListItem>[
        ..._expandReceivedUnique(received),
        ..._expandSent(sent),
      ];
      items.sort((a, b) {
        final aPending = a.focusProduct?.isItemPending ?? a.batch.hasActionablePending;
        final bPending = b.focusProduct?.isItemPending ?? b.batch.hasActionablePending;
        final pendingCmp = (bPending ? 1 : 0) - (aPending ? 1 : 0);
        if (pendingCmp != 0) return pendingCmp;
        final at = a.batch.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.batch.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      AppLog.d(
        _tag,
        'Loaded ${items.length} import request rows '
        '(receivedBatches=${received.length} sentBatches=${sent.length})',
      );
      emit(state.copyWith(isLoading: false, items: items));
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

  /// One Received card per product; prefer newest batch when IDs collide.
  List<ImportRequestListItem> _expandReceivedUnique(
    List<ImportRequestBatch> batches,
  ) {
    final sorted = [...batches]..sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    final seen = <String>{};
    final out = <ImportRequestListItem>[];
    for (final batch in sorted) {
      if (batch.products.isEmpty) {
        final key = 'batch:${batch.id}';
        if (!seen.add(key)) continue;
        out.add(
          ImportRequestListItem(
            batch: batch,
            direction: ImportRequestDirection.incoming,
          ),
        );
        continue;
      }
      for (var i = 0; i < batch.products.length; i++) {
        final product = batch.products[i];
        final id = product.decisionProductId;
        final key =
            id.isNotEmpty
                ? 'product:$id'
                : 'batch:${batch.id}:src:${product.sourceProductId}:$i';
        if (!seen.add(key)) continue;
        out.add(
          ImportRequestListItem(
            batch: batch,
            direction: ImportRequestDirection.incoming,
            productIndex: i,
          ),
        );
      }
    }
    return out;
  }

  /// One Sent card per product in each batch (no cross-batch dedupe).
  List<ImportRequestListItem> _expandSent(List<ImportRequestBatch> batches) {
    final out = <ImportRequestListItem>[];
    for (final batch in batches) {
      if (batch.products.isEmpty) {
        out.add(
          ImportRequestListItem(
            batch: batch,
            direction: ImportRequestDirection.outgoing,
          ),
        );
        continue;
      }
      for (var i = 0; i < batch.products.length; i++) {
        out.add(
          ImportRequestListItem(
            batch: batch,
            direction: ImportRequestDirection.outgoing,
            productIndex: i,
          ),
        );
      }
    }
    return out;
  }

  Future<List<ImportRequestBatch>> _fetchTab(String tab) async {
    try {
      return await _importRepository.listImportRequestBatches(
        storeId: _storeId,
        tab: tab,
      );
    } on CatalogApiException catch (e) {
      if (e.statusCode == 404 ||
          e.code == 'NOT_FOUND' ||
          e.message.toLowerCase().contains('disabled')) {
        AppLog.d(_tag, 'import tab=$tab stub/empty (${e.statusCode})');
        return const [];
      }
      rethrow;
    }
  }

  Future<void> _onAccept(
    ImportRequestsAcceptPressed event,
    Emitter<ImportRequestsState> emit,
  ) => _decideItem(
    requestId: event.requestId,
    productId: event.productId,
    approve: true,
    emit: emit,
  );

  Future<void> _onReject(
    ImportRequestsRejectPressed event,
    Emitter<ImportRequestsState> emit,
  ) => _decideItem(
    requestId: event.requestId,
    productId: event.productId,
    approve: false,
    emit: emit,
  );

  Future<void> _onCancel(
    ImportRequestsCancelPressed event,
    Emitter<ImportRequestsState> emit,
  ) async {
    final requestId = event.requestId.trim();
    if (requestId.isEmpty) return;
    if (state.actingRequestId != null) return;

    emit(
      state.copyWith(
        actingRequestId: requestId,
        items: [
          for (final item in state.items)
            item.batch.id == requestId
                ? item.copyWith(isActing: true)
                : item,
        ],
        clearError: true,
        clearInfo: true,
      ),
    );

    try {
      ImportQa.step(
        'Cancel → pending request',
        detail: 'store=$_storeId request=$requestId',
      );
      final updated = await _importRepository.cancelBatch(
        storeId: _storeId,
        requestId: requestId,
      );
      AppLog.d(
        _tag,
        'Cancelled request $requestId → ${updated.status}',
      );
      ImportQa.step(
        'Cancel result',
        detail: 'request=$requestId → ${updated.status}',
      );
      emit(
        state.copyWith(
          clearActing: true,
          infoMessage: 'Import request cancelled.',
          items: [
            for (final item in state.items)
              if (item.batch.id != requestId)
                item
              else
                item.copyWith(
                  batch: item.batch.copyWith(
                    status: updated.status.trim().isNotEmpty
                        ? updated.status
                        : 'cancelled',
                    decidedAt: updated.decidedAt ?? DateTime.now(),
                  ),
                  isActing: false,
                ),
          ],
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Cancel request failed', e);
      emit(
        state.copyWith(
          clearActing: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
          items: [
            for (final item in state.items)
              item.batch.id == requestId
                  ? item.copyWith(isActing: false)
                  : item,
          ],
        ),
      );
    }
  }

  Future<void> _decideItem({
    required String requestId,
    required String productId,
    required bool approve,
    required Emitter<ImportRequestsState> emit,
  }) async {
    final id = productId.trim();
    if (id.isEmpty) return;
    if (state.actingRequestId != null) return;

    emit(
      state.copyWith(
        actingRequestId: requestId,
        items: [
          for (final item in state.items)
            item.batch.id == requestId
                ? item.copyWith(isActing: true, actingProductId: id)
                : item,
        ],
        clearError: true,
        clearInfo: true,
      ),
    );

    final decision = approve ? 'approve' : 'decline';
    try {
      ImportQa.step(
        'Decision → partial/$decision',
        detail: 'store=$_storeId request=$requestId product=$id',
      );
      final updated = await _importRepository.decideBatch(
        storeId: _storeId,
        requestId: requestId,
        decision: 'partial',
        approvedProductIds: approve ? [id] : const [],
        declinedProductIds: approve ? const [] : [id],
      );
      AppLog.d(
        _tag,
        'Decided item $decision for $requestId product=$id → ${updated.status}',
      );
      ImportQa.step(
        'Decision result',
        detail: 'request=$requestId product=$id → ${updated.status}',
      );

      final itemStatus = approve ? 'live' : 'declined';
      final successMessage =
          approve ? 'Product approved.' : 'Product declined.';

      final decidedAt = updated.decidedAt ?? DateTime.now();
      emit(
        state.copyWith(
          clearActing: true,
          infoMessage: successMessage,
          items: [
            for (final item in state.items)
              _itemMatchesDecision(item, requestId: requestId, productId: id)
                  ? item.copyWith(
                    batch: _applyItemDecision(
                      batch: item.batch,
                      productId: id,
                      itemStatus: itemStatus,
                      batchStatus: updated.status,
                      decidedAt: decidedAt,
                    ),
                    isActing: false,
                    clearActingProduct: true,
                  )
                  : item,
          ],
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Decide item failed $decision', e);
      emit(
        state.copyWith(
          clearActing: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
          items: [
            for (final item in state.items)
              item.batch.id == requestId
                  ? item.copyWith(isActing: false, clearActingProduct: true)
                  : item,
          ],
        ),
      );
    }
  }

  bool _itemMatchesDecision(
    ImportRequestListItem item, {
    required String requestId,
    required String productId,
  }) {
    if (item.batch.id == requestId) return true;
    final focus = item.focusProduct;
    if (focus == null) return false;
    return focus.decisionProductId == productId ||
        focus.sourceProductId == productId ||
        focus.createdProductId == productId;
  }

  ImportRequestBatch _applyItemDecision({
    required ImportRequestBatch batch,
    required String productId,
    required String itemStatus,
    required String batchStatus,
    required DateTime decidedAt,
  }) {
    final nextProducts = [
      for (final p in batch.products)
        p.decisionProductId == productId ||
                p.sourceProductId == productId ||
                p.createdProductId == productId
            ? p.copyWith(importStatus: itemStatus)
            : p,
    ];
    final resolvedStatus =
        batchStatus.trim().isNotEmpty
            ? batchStatus.trim().toLowerCase()
            : _rollupBatchStatus(nextProducts);
    return batch.copyWith(
      status: resolvedStatus,
      decidedAt: decidedAt,
      products: nextProducts,
    );
  }

  String _rollupBatchStatus(List<ImportRequestProductRow> products) {
    if (products.isEmpty) return 'pending';
    final anyPending = products.any((p) => p.isItemPending);
    final anyApproved = products.any((p) => p.isItemApproved);
    final anyDeclined = products.any((p) => p.isItemDeclined);
    if (!anyPending && anyApproved && !anyDeclined) return 'approved';
    if (!anyPending && anyDeclined && !anyApproved) return 'declined';
    if (!anyPending && anyApproved && anyDeclined) {
      return 'partially_approved';
    }
    if (anyPending && (anyApproved || anyDeclined)) {
      return 'partially_approved';
    }
    return 'pending';
  }

  void _onClearMessage(
    ImportRequestsClearMessage event,
    Emitter<ImportRequestsState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearInfo: true));
  }
}
