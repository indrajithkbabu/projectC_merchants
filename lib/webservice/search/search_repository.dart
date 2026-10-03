import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/webservice/search/search_request.dart';

abstract class SearchRepository {
  Future<SearchMeta> fetchMeta({String? storeId});

  Future<SearchSuggestResponse> suggest({
    required String q,
    String? storeId,
  });

  Future<SearchPageResult> search(SearchQuery query);

  Future<StoreFacetsResponse> fetchStoreFacets(String storeId);

  Future<SearchPageResult> storeSearch({
    required String storeId,
    required SearchQuery query,
  });
}

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({required SearchRequest request}) : _request = request;

  static const _tag = 'SearchRepository';

  final SearchRequest _request;

  @override
  Future<SearchMeta> fetchMeta({String? storeId}) async {
    AppLog.d(_tag, 'fetchMeta storeId=${storeId ?? '-'}');
    return _request.fetchMeta(storeId: storeId);
  }

  @override
  Future<SearchSuggestResponse> suggest({
    required String q,
    String? storeId,
  }) async {
    return _request.suggest(q: q, storeId: storeId);
  }

  @override
  Future<SearchPageResult> search(SearchQuery query) {
    return _request.search(query);
  }

  @override
  Future<StoreFacetsResponse> fetchStoreFacets(String storeId) {
    AppLog.d(_tag, 'fetchStoreFacets store=$storeId');
    return _request.fetchStoreFacets(storeId);
  }

  @override
  Future<SearchPageResult> storeSearch({
    required String storeId,
    required SearchQuery query,
  }) {
    return _request.storeSearch(storeId: storeId, query: query);
  }
}
