import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class ImportApiRequest {
  ImportApiRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<CatalogPage<ImportTarget>> fetchTargets({
    required String listingId,
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{
      'listingId': listingId,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.importTargets,
      query: query,
      requiresAuth: true,
    );
    final items =
        (json?['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ImportTarget.fromJson)
            .toList();
    return CatalogPage(
      items: items,
      nextCursor: json?['nextCursor'] as String?,
    );
  }

  Future<ImportRequest> createImportRequest({
    required String listingId,
    String? destinationStoreId,
  }) async {
    final body = <String, dynamic>{'listingId': listingId};
    if (destinationStoreId != null && destinationStoreId.isNotEmpty) {
      body['destinationStoreId'] = destinationStoreId;
    }
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.importRequests,
      body: body,
      requiresAuth: true,
    );
    return ImportRequest.fromJson(json ?? const {});
  }

  Future<CatalogPage<ImportRequest>> listStoreRequests({
    required String storeId,
    String direction = 'incoming',
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{
      'direction': direction,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeImportRequests(storeId),
      query: query,
      requiresAuth: true,
    );
    final items =
        (json?['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ImportRequest.fromJson)
            .toList();
    return CatalogPage(
      items: items,
      nextCursor: json?['nextCursor'] as String?,
    );
  }

  Future<ImportRequest> decide({
    required String requestId,
    required String decision,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.importDecision(requestId),
      body: {'decision': decision},
      requiresAuth: true,
    );
    return ImportRequest.fromJson(json ?? const {});
  }
}
