import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

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

  /// Quick import batch — `POST /stores/:storeId/imports`.
  Future<QuickImportBatchResult> submitBatchImport({
    required String destinationStoreId,
    required String sourceStoreId,
    required List<Map<String, dynamic>> items,
    String destinationMode = 'original',
    String? targetCollectionId,
    String? newCollectionName,
  }) async {
    final destination = <String, dynamic>{
      'mode': destinationMode,
      'targetCollectionId': targetCollectionId,
      'newCollectionName': newCollectionName,
    };
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeImports(destinationStoreId),
      body: <String, dynamic>{
        'sourceStoreId': sourceStoreId,
        'destination': destination,
        'items': items,
      },
      requiresAuth: true,
    );
    return QuickImportBatchResult.fromJson(json);
  }

  /// Received / Sent tabs — `GET …/import-requests?tab=`.
  Future<List<ImportRequestBatch>> listImportRequestBatches({
    required String storeId,
    String tab = 'received',
    String? status,
  }) async {
    final query = <String, String>{'tab': tab};
    if (status != null && status.isNotEmpty) query['status'] = status;
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeImportRequests(storeId),
      query: query,
      requiresAuth: true,
    );
    final raw = json?['items'];
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map)
          ImportRequestBatch.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Approve / decline — bulk (`approve`|`decline`) or item-level (`partial`).
  ///
  /// Item-level: pass [approvedProductIds] / [declinedProductIds] (source or
  /// created product ids). Forces `decision: partial` when either list is set.
  Future<ImportRequestBatch> decideBatch({
    required String storeId,
    required String requestId,
    required String decision,
    List<String> approvedProductIds = const [],
    List<String> declinedProductIds = const [],
  }) async {
    final approved = [
      for (final id in approvedProductIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final declined = [
      for (final id in declinedProductIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final itemLevel = approved.isNotEmpty || declined.isNotEmpty;
    final resolvedDecision =
        itemLevel ? 'partial' : decision.trim().toLowerCase();
    final body = <String, dynamic>{'decision': resolvedDecision};
    if (itemLevel) {
      body['approvedProductIds'] = approved;
      body['declinedProductIds'] = declined;
    }
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeImportRequestDecision(storeId, requestId),
      body: body,
      requiresAuth: true,
    );
    final status =
        (json?['status'] as String?)?.trim().toLowerCase() ??
        (resolvedDecision == 'approve'
            ? 'approved'
            : resolvedDecision == 'decline'
            ? 'declined'
            : 'partially_approved');
    return ImportRequestBatch(
      id: requestId,
      status: status,
      createdAt: null,
      decidedAt: DateTime.now(),
    );
  }

  /// Cancel a pending Sent request — prefers DELETE, falls back to POST cancel.
  Future<ImportRequestBatch> cancelBatch({
    required String storeId,
    required String requestId,
  }) async {
    Map<String, dynamic>? json;
    try {
      json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.storeImportRequest(storeId, requestId),
        requiresAuth: true,
      );
    } on CatalogApiException catch (e) {
      // Some environments expose POST …/cancel instead of DELETE.
      if (e.statusCode == 404 || e.statusCode == 405) {
        json = await _api.sendJson(
          method: HttpMethod.post,
          path: Endpoints.storeImportRequestCancel(storeId, requestId),
          body: const <String, dynamic>{},
          requiresAuth: true,
        );
      } else {
        rethrow;
      }
    }
    final status =
        (json?['status'] as String?)?.trim().toLowerCase() ?? 'cancelled';
    return ImportRequestBatch(
      id:
          (json?['requestId'] as String?)?.trim().isNotEmpty == true
              ? (json!['requestId'] as String).trim()
              : requestId,
      status: status,
      createdAt: null,
      decidedAt: DateTime.now(),
    );
  }
}
