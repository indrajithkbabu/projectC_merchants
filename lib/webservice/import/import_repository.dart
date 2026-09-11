import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/import_models.dart';
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
}
