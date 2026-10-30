import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/import_qa.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/webservice/import/import_request.dart';

abstract class ImportRepository {
  Future<CatalogPage<ImportTarget>> fetchTargets({
    required String listingId,
    int limit = 20,
    String? cursor,
  });

  Future<ImportRequest> createImportRequest({
    required String listingId,
    String? destinationStoreId,
  });

  Future<CatalogPage<ImportRequest>> listStoreRequests({
    required String storeId,
    String direction = 'incoming',
    int limit = 20,
    String? cursor,
  });

  Future<ImportRequest> decide({
    required String requestId,
    required String decision,
  });

  Future<QuickImportBatchResult> submitBatchImport({
    required String destinationStoreId,
    required String sourceStoreId,
    required List<Map<String, dynamic>> items,
    String destinationMode = 'original',
    String? targetCollectionId,
    String? newCollectionName,
  });

  Future<List<ImportRequestBatch>> listImportRequestBatches({
    required String storeId,
    String tab = 'received',
    String? status,
  });

  Future<ImportRequestBatch> decideBatch({
    required String storeId,
    required String requestId,
    required String decision,
    List<String> approvedProductIds = const [],
    List<String> declinedProductIds = const [],
  });

  /// Cancel a pending Sent import request (requester store).
  Future<ImportRequestBatch> cancelBatch({
    required String storeId,
    required String requestId,
  });
}

class ImportRepositoryImpl implements ImportRepository {
  ImportRepositoryImpl({required ImportApiRequest request}) : _request = request;

  static const _tag = 'ImportRepository';

  final ImportApiRequest _request;

  @override
  Future<CatalogPage<ImportTarget>> fetchTargets({
    required String listingId,
    int limit = 20,
    String? cursor,
  }) {
    AppLog.d(_tag, 'fetchTargets listing=$listingId');
    return _request.fetchTargets(
      listingId: listingId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<ImportRequest> createImportRequest({
    required String listingId,
    String? destinationStoreId,
  }) {
    AppLog.d(_tag, 'createImportRequest');
    return _request.createImportRequest(
      listingId: listingId,
      destinationStoreId: destinationStoreId,
    );
  }

  @override
  Future<CatalogPage<ImportRequest>> listStoreRequests({
    required String storeId,
    String direction = 'incoming',
    int limit = 20,
    String? cursor,
  }) {
    return _request.listStoreRequests(
      storeId: storeId,
      direction: direction,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<ImportRequest> decide({
    required String requestId,
    required String decision,
  }) {
    AppLog.d(_tag, 'decide $decision request=$requestId');
    return _request.decide(requestId: requestId, decision: decision);
  }

  @override
  Future<QuickImportBatchResult> submitBatchImport({
    required String destinationStoreId,
    required String sourceStoreId,
    required List<Map<String, dynamic>> items,
    String destinationMode = 'original',
    String? targetCollectionId,
    String? newCollectionName,
  }) {
    AppLog.d(
      _tag,
      'submitBatchImport dest=$destinationStoreId source=$sourceStoreId '
      'items=${items.length}',
    );
    ImportQa.step(
      'API submitBatchImport',
      detail:
          'dest=$destinationStoreId source=$sourceStoreId '
          'items=${items.length} mode=$destinationMode',
    );
    return _request.submitBatchImport(
      destinationStoreId: destinationStoreId,
      sourceStoreId: sourceStoreId,
      items: items,
      destinationMode: destinationMode,
      targetCollectionId: targetCollectionId,
      newCollectionName: newCollectionName,
    );
  }

  @override
  Future<List<ImportRequestBatch>> listImportRequestBatches({
    required String storeId,
    String tab = 'received',
    String? status,
  }) {
    AppLog.d(_tag, 'listImportRequestBatches store=$storeId tab=$tab');
    return _request.listImportRequestBatches(
      storeId: storeId,
      tab: tab,
      status: status,
    );
  }

  @override
  Future<ImportRequestBatch> decideBatch({
    required String storeId,
    required String requestId,
    required String decision,
    List<String> approvedProductIds = const [],
    List<String> declinedProductIds = const [],
  }) {
    AppLog.d(
      _tag,
      'decideBatch $decision store=$storeId request=$requestId '
      'approved=${approvedProductIds.length} declined=${declinedProductIds.length}',
    );
    return _request.decideBatch(
      storeId: storeId,
      requestId: requestId,
      decision: decision,
      approvedProductIds: approvedProductIds,
      declinedProductIds: declinedProductIds,
    );
  }

  @override
  Future<ImportRequestBatch> cancelBatch({
    required String storeId,
    required String requestId,
  }) {
    AppLog.d(_tag, 'cancelBatch store=$storeId request=$requestId');
    ImportQa.step(
      'Cancel → pending request',
      detail: 'store=$storeId request=$requestId',
    );
    return _request.cancelBatch(storeId: storeId, requestId: requestId);
  }
}
