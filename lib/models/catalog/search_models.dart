import 'package:equatable/equatable.dart';

/// `GET /search/meta` response (Discover pre-search).
class SearchMeta extends Equatable {
  const SearchMeta({
    this.trendingTags = const [],
    this.recentSearches = const [],
    this.categories = const [],
  });

  final List<String> trendingTags;
  final List<SearchRecentEntry> recentSearches;
  final List<SearchMetaCategory> categories;

  factory SearchMeta.fromJson(Map<String, dynamic> json) {
    final rawRecent = json['recentSearches'];
    final rawCategories = json['categories'];
    final rawTags = json['trendingTags'];
    return SearchMeta(
      trendingTags:
          rawTags is List
              ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : const [],
      recentSearches:
          rawRecent is List
              ? rawRecent
                  .whereType<Map>()
                  .map((e) => SearchRecentEntry.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
      categories:
          rawCategories is List
              ? rawCategories
                  .whereType<Map>()
                  .map((e) => SearchMetaCategory.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [trendingTags, recentSearches, categories];
}

class SearchRecentEntry extends Equatable {
  const SearchRecentEntry({
    required this.type,
    this.text = '',
    this.name = '',
    this.label = '',
    this.storeId,
    this.slug,
  });

  /// `query` | `store`
  final String type;
  final String text;
  final String name;
  final String label;

  /// Not in current API sample for store recents — may be null.
  final String? storeId;
  final String? slug;

  bool get isStore => type == 'store';

  String get displayText => isStore ? name : text;

  factory SearchRecentEntry.fromJson(Map<String, dynamic> json) {
    return SearchRecentEntry(
      type: json['type'] as String? ?? 'query',
      text: json['text'] as String? ?? '',
      name: json['name'] as String? ?? '',
      label: json['label'] as String? ?? '',
      storeId: json['id'] as String? ?? json['storeId'] as String?,
      slug: json['slug'] as String?,
    );
  }

  @override
  List<Object?> get props => [type, text, name, label, storeId, slug];
}

class SearchMetaCategory extends Equatable {
  const SearchMetaCategory({
    required this.key,
    required this.label,
    required this.productCount,
  });

  final String key;
  final String label;
  final int productCount;

  factory SearchMetaCategory.fromJson(Map<String, dynamic> json) {
    return SearchMetaCategory(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [key, label, productCount];
}

/// One row from `GET /search/suggest`.
class SearchSuggestMatch extends Equatable {
  const SearchSuggestMatch({
    required this.type,
    required this.id,
    this.name = '',
    this.title = '',
    this.slug,
    this.city = '',
    this.storeImage,
    this.collectionId,
    this.subGroupId,
    this.storeId,
    this.storeName = '',
    this.netWeight,
    this.purity,
    this.thumbnailUrl,
  });

  /// `store` | `product`
  final String type;
  final String id;
  final String name;
  final String title;
  final String? slug;
  final String city;
  final String? storeImage;
  final String? collectionId;
  final String? subGroupId;
  /// Present on product matches so the client can open browse without a lookup.
  final String? storeId;
  final String storeName;
  final double? netWeight;
  final String? purity;
  final String? thumbnailUrl;

  bool get isStore => type == 'store';

  factory SearchSuggestMatch.fromJson(Map<String, dynamic> json) {
    return SearchSuggestMatch(
      type: json['type'] as String? ?? 'product',
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String?,
      city: json['city'] as String? ?? '',
      storeImage: json['storeImage'] as String?,
      collectionId: json['collectionId'] as String?,
      subGroupId: json['subGroupId'] as String?,
      storeId: json['storeId'] as String?,
      storeName: json['storeName'] as String? ?? '',
      netWeight: (json['netWeight'] as num?)?.toDouble(),
      purity: json['purity']?.toString(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        type,
        id,
        name,
        title,
        slug,
        city,
        storeImage,
        collectionId,
        subGroupId,
        storeId,
        storeName,
        netWeight,
        purity,
        thumbnailUrl,
      ];
}

class SearchSuggestResponse extends Equatable {
  const SearchSuggestResponse({
    required this.query,
    this.matches = const [],
  });

  final String query;
  final List<SearchSuggestMatch> matches;

  factory SearchSuggestResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['matches'];
    return SearchSuggestResponse(
      query: json['query'] as String? ?? '',
      matches:
          raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => SearchSuggestMatch.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [query, matches];
}

class SearchFacetValue extends Equatable {
  const SearchFacetValue({
    required this.value,
    required this.label,
    required this.count,
    this.id,
  });

  /// Filter key sent to the API (`necklace`, `under_10`, …).
  final String value;
  final String label;
  final int count;

  /// Present on store facets (`id` + `name`).
  final String? id;

  factory SearchFacetValue.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final value =
        (json['value'] as String?) ??
        id ??
        name ??
        '';
    final label =
        (json['label'] as String?) ??
        name ??
        value;
    return SearchFacetValue(
      value: value,
      label: label,
      count: (json['count'] as num?)?.toInt() ?? 0,
      id: id,
    );
  }

  @override
  List<Object?> get props => [value, label, count, id];
}

class SearchFacets extends Equatable {
  const SearchFacets({
    this.category = const [],
    this.metal = const [],
    this.purity = const [],
    this.weight = const [],
    this.size = const [],
    this.wastage = const [],
    this.store = const [],
    this.location = const [],
  });

  final List<SearchFacetValue> category;
  final List<SearchFacetValue> metal;
  final List<SearchFacetValue> purity;
  final List<SearchFacetValue> weight;
  final List<SearchFacetValue> size;
  final List<SearchFacetValue> wastage;
  final List<SearchFacetValue> store;
  final List<SearchFacetValue> location;

  factory SearchFacets.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SearchFacets();
    List<SearchFacetValue> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => SearchFacetValue.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return SearchFacets(
      category: parse('category'),
      metal: parse('metal'),
      purity: parse('purity'),
      weight: parse('weight'),
      size: parse('size'),
      wastage: parse('wastage'),
      store: parse('store'),
      location: parse('location'),
    );
  }

  @override
  List<Object?> get props => [
        category,
        metal,
        purity,
        weight,
        size,
        wastage,
        store,
        location,
      ];
}

class SearchResultSummary extends Equatable {
  const SearchResultSummary({
    this.totalProducts = 0,
    this.totalStores = 0,
    this.countLine = '',
  });

  final int totalProducts;
  final int totalStores;
  final String countLine;

  factory SearchResultSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SearchResultSummary();
    return SearchResultSummary(
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      totalStores: (json['totalStores'] as num?)?.toInt() ?? 0,
      countLine: json['countLine'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [totalProducts, totalStores, countLine];
}

class SearchHitStore extends Equatable {
  const SearchHitStore({
    required this.id,
    required this.name,
    this.slug = '',
    this.city = '',
  });

  final String id;
  final String name;
  final String slug;
  final String city;

  factory SearchHitStore.fromJson(Map<String, dynamic> json) {
    return SearchHitStore(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      city: json['city'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, slug, city];
}

class SearchHitDetails extends Equatable {
  const SearchHitDetails({
    this.category = '',
    this.metalType = const [],
    this.netWeight,
    this.grossWeight,
    this.deduction,
    this.purity = '',
    this.wastage,
    this.size = '',
    this.precisionTag = '',
  });

  final String category;
  final List<String> metalType;
  final double? netWeight;
  final double? grossWeight;
  final double? deduction;
  final String purity;
  final double? wastage;
  final String size;
  final String precisionTag;

  factory SearchHitDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SearchHitDetails();
    final metals = json['metalType'];
    return SearchHitDetails(
      category: json['category'] as String? ?? '',
      metalType:
          metals is List
              ? metals.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : const [],
      netWeight: (json['netWeight'] as num?)?.toDouble(),
      grossWeight: (json['grossWeight'] as num?)?.toDouble(),
      deduction: (json['deduction'] as num?)?.toDouble(),
      purity: json['purity']?.toString() ?? '',
      wastage: (json['wastage'] as num?)?.toDouble(),
      size: json['size']?.toString() ?? '',
      precisionTag: json['precisionTag'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        category,
        metalType,
        netWeight,
        grossWeight,
        deduction,
        purity,
        wastage,
        size,
        precisionTag,
      ];
}

class SearchHit extends Equatable {
  const SearchHit({
    required this.id,
    required this.title,
    this.collectionId,
    this.subGroupId,
    this.thumbnailUrl,
    this.store,
    this.details = const SearchHitDetails(),
  });

  final String id;
  final String title;
  final String? collectionId;
  final String? subGroupId;
  final String? thumbnailUrl;
  final SearchHitStore? store;
  final SearchHitDetails details;

  factory SearchHit.fromJson(Map<String, dynamic> json) {
    final rawStore = json['store'];
    final rawDetails = json['details'];
    return SearchHit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      collectionId: json['collectionId'] as String?,
      subGroupId: json['subGroupId'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      store:
          rawStore is Map
              ? SearchHitStore.fromJson(Map<String, dynamic>.from(rawStore))
              : null,
      details:
          rawDetails is Map
              ? SearchHitDetails.fromJson(Map<String, dynamic>.from(rawDetails))
              : const SearchHitDetails(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        collectionId,
        subGroupId,
        thumbnailUrl,
        store,
        details,
      ];
}

class SearchPageResult extends Equatable {
  const SearchPageResult({
    this.summary = const SearchResultSummary(),
    this.items = const [],
    this.facets = const SearchFacets(),
    this.nextCursor,
  });

  final SearchResultSummary summary;
  final List<SearchHit> items;
  final SearchFacets facets;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory SearchPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawFacets = json['facets'];
    final rawSummary = json['summary'];
    return SearchPageResult(
      summary:
          rawSummary is Map
              ? SearchResultSummary.fromJson(Map<String, dynamic>.from(rawSummary))
              : const SearchResultSummary(),
      items:
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map((e) => SearchHit.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
      facets:
          rawFacets is Map
              ? SearchFacets.fromJson(Map<String, dynamic>.from(rawFacets))
              : const SearchFacets(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  List<Object?> get props => [summary, items, facets, nextCursor];
}

class StoreFacetsResponse extends Equatable {
  const StoreFacetsResponse({
    this.storeId = '',
    this.storeName = '',
    this.slug = '',
    this.city = '',
    this.totalProducts = 0,
    this.summaryChips = const [],
  });

  final String storeId;
  final String storeName;
  final String slug;
  final String city;
  final int totalProducts;
  final List<StoreSummaryChip> summaryChips;

  factory StoreFacetsResponse.fromJson(Map<String, dynamic> json) {
    final rawStore = json['store'];
    final store =
        rawStore is Map ? Map<String, dynamic>.from(rawStore) : const <String, dynamic>{};
    final rawChips = json['summaryChips'];
    return StoreFacetsResponse(
      storeId: store['id'] as String? ?? '',
      storeName: store['name'] as String? ?? '',
      slug: store['slug'] as String? ?? '',
      city: store['city'] as String? ?? '',
      totalProducts: (store['totalProducts'] as num?)?.toInt() ?? 0,
      summaryChips:
          rawChips is List
              ? rawChips
                  .whereType<Map>()
                  .map((e) => StoreSummaryChip.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [
        storeId,
        storeName,
        slug,
        city,
        totalProducts,
        summaryChips,
      ];
}

class StoreSummaryChip extends Equatable {
  const StoreSummaryChip({
    required this.type,
    required this.value,
    required this.label,
  });

  /// `category` | `purity` | `metal`
  final String type;
  final String value;
  final String label;

  factory StoreSummaryChip.fromJson(Map<String, dynamic> json) {
    return StoreSummaryChip(
      type: json['type'] as String? ?? '',
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [type, value, label];
}

/// Query params shared by global + in-store search.
class SearchQuery extends Equatable {
  const SearchQuery({
    this.q,
    this.categories = const [],
    this.metals = const [],
    this.purities = const [],
    this.weights = const [],
    this.sizes = const [],
    this.wastages = const [],
    this.stores = const [],
    this.locations = const [],
    this.sort = 'newest',
    this.limit = 20,
    this.cursor,
  });

  final String? q;
  final List<String> categories;
  final List<String> metals;
  final List<String> purities;
  final List<String> weights;
  final List<String> sizes;
  final List<String> wastages;
  final List<String> stores;
  final List<String> locations;
  final String sort;
  final int limit;
  final String? cursor;

  Map<String, String> toQueryMap({bool includeStoreLocation = true}) {
    final map = <String, String>{
      if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
      if (categories.isNotEmpty) 'category': categories.join(','),
      if (metals.isNotEmpty) 'metal': metals.join(','),
      if (purities.isNotEmpty) 'purity': purities.join(','),
      if (weights.isNotEmpty) 'weight': weights.join(','),
      if (sizes.isNotEmpty) 'size': sizes.join(','),
      if (wastages.isNotEmpty) 'wastage': wastages.join(','),
      if (includeStoreLocation && stores.isNotEmpty) 'store': stores.join(','),
      if (includeStoreLocation && locations.isNotEmpty)
        'location': locations.join(','),
      'sort': sort,
      'limit': '$limit',
      if (cursor != null && cursor!.isNotEmpty) 'cursor': cursor!,
    };
    return map;
  }

  @override
  List<Object?> get props => [
        q,
        categories,
        metals,
        purities,
        weights,
        sizes,
        wastages,
        stores,
        locations,
        sort,
        limit,
        cursor,
      ];
}
