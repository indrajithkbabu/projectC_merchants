import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class StoreRequest {
  StoreRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<CatalogPage<CatalogStore>> fetchHome({
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.home,
      query: query,
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return _pageStores(json);
  }

  Future<CatalogStore> fetchStore(String storeId) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeById(storeId),
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return CatalogStore.fromJson(json ?? const {});
  }

  Future<CatalogStore> fetchStoreBySlug(String slug) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeBySlug(slug),
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return CatalogStore.fromJson(json ?? const {});
  }

  Future<SlugAvailability> checkSlugAvailability(String slug) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.slugAvailability(slug),
      requiresAuth: false,
    );
    return SlugAvailability.fromJson(json ?? const {});
  }

  Future<CatalogStore> createStore({
    required String name,
    required String slug,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.stores,
      body: {'name': name, 'slug': slug},
      requiresAuth: true,
    );
    return CatalogStore.fromJson(json ?? const {});
  }

  Future<CatalogStore> renameStore({
    required String storeId,
    required String name,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.patch,
      path: Endpoints.storeById(storeId),
      body: {'name': name},
      requiresAuth: true,
    );
    return CatalogStore.fromJson(json ?? const {});
  }

  Future<ContactBatchResult> addContacts({
    required String storeId,
    required List<String> phones,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeContacts(storeId),
      body: {'phones': phones},
      requiresAuth: true,
    );
    return ContactBatchResult.fromJson(json ?? const {});
  }

  Future<CatalogPage<StoreMember>> fetchMembers({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeMembers(storeId),
      query: query,
      requiresAuth: true,
    );
    final items =
        (json?['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StoreMember.fromJson)
            .toList();
    return CatalogPage(
      items: items,
      nextCursor: json?['nextCursor'] as String?,
    );
  }

  Future<void> removeMember({
    required String storeId,
    required String userId,
  }) async {
    await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.storeMember(storeId, userId),
      requiresAuth: true,
    );
  }

  Future<void> leaveStore(String storeId) async {
    await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeLeave(storeId),
      body: const <String, dynamic>{},
      requiresAuth: true,
    );
  }

  CatalogPage<CatalogStore> _pageStores(Map<String, dynamic>? json) {
    final items =
        (json?['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogStore.fromJson)
            .toList();
    return CatalogPage(
      items: items,
      nextCursor: json?['nextCursor'] as String?,
    );
  }
}
