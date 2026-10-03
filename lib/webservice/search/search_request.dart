import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class SearchRequest {
  SearchRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<SearchMeta> fetchMeta({String? storeId}) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.searchMeta,
      query: {
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      },
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return SearchMeta.fromJson(json ?? const {});
  }

  Future<SearchSuggestResponse> suggest({
    required String q,
    String? storeId,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.searchSuggest,
      query: {
        'q': q,
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      },
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return SearchSuggestResponse.fromJson(json ?? const {});
  }

  Future<SearchPageResult> search(SearchQuery query) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.search,
      query: query.toQueryMap(includeStoreLocation: true),
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return SearchPageResult.fromJson(json ?? const {});
  }

  Future<StoreFacetsResponse> fetchStoreFacets(String storeId) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeFacets(storeId),
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return StoreFacetsResponse.fromJson(json ?? const {});
  }

  Future<SearchPageResult> storeSearch({
    required String storeId,
    required SearchQuery query,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeSearch(storeId),
      query: query.toQueryMap(includeStoreLocation: false),
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return SearchPageResult.fromJson(json ?? const {});
  }
}
