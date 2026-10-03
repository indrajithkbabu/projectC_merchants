import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/models/catalog/search_models.dart' as api;
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_product.dart';

/// Sort options — values match API `sort` query param.
enum SearchSortOption {
  newest('Newest', 'newest'),
  lightest('Lightest first', 'weight_asc'),
  heaviest('Heaviest first', 'weight_desc');

  const SearchSortOption(this.label, this.apiValue);
  final String label;
  final String apiValue;
}

/// Scope for the shared filter sheet.
enum SearchFilterScope {
  global,
  inStore,
}

class SearchFilterOption extends Equatable {
  const SearchFilterOption({
    required this.value,
    required this.label,
    required this.count,
  });

  final String value;
  final String label;
  final int count;

  bool get isAvailable => count > 0;

  factory SearchFilterOption.fromFacet(api.SearchFacetValue facet) {
    return SearchFilterOption(
      value: facet.value,
      label: facet.label,
      count: facet.count,
    );
  }

  @override
  List<Object?> get props => [value, label, count];
}

class SearchFilterCatalog extends Equatable {
  const SearchFilterCatalog({
    this.categories = const [],
    this.metals = const [],
    this.purities = const [],
    this.weights = const [],
    this.sizes = const [],
    this.wastages = const [],
    this.stores = const [],
    this.locations = const [],
  });

  final List<SearchFilterOption> categories;
  final List<SearchFilterOption> metals;
  final List<SearchFilterOption> purities;
  final List<SearchFilterOption> weights;
  final List<SearchFilterOption> sizes;
  final List<SearchFilterOption> wastages;
  final List<SearchFilterOption> stores;
  final List<SearchFilterOption> locations;

  factory SearchFilterCatalog.fromFacets(api.SearchFacets facets) {
    return SearchFilterCatalog(
      categories: facets.category.map(SearchFilterOption.fromFacet).toList(),
      metals: facets.metal.map(SearchFilterOption.fromFacet).toList(),
      purities: facets.purity.map(SearchFilterOption.fromFacet).toList(),
      weights: facets.weight.map(SearchFilterOption.fromFacet).toList(),
      sizes: facets.size.map(SearchFilterOption.fromFacet).toList(),
      wastages: facets.wastage.map(SearchFilterOption.fromFacet).toList(),
      stores: facets.store.map(SearchFilterOption.fromFacet).toList(),
      locations: facets.location.map(SearchFilterOption.fromFacet).toList(),
    );
  }

  String labelFor(String group, String value) {
    final list = switch (group) {
      'category' => categories,
      'metal' => metals,
      'purity' => purities,
      'weight' => weights,
      'size' => sizes,
      'wastage' => wastages,
      'store' => stores,
      'location' => locations,
      _ => const <SearchFilterOption>[],
    };
    for (final o in list) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  @override
  List<Object?> get props => [
        categories,
        metals,
        purities,
        weights,
        sizes,
        wastages,
        stores,
        locations,
      ];
}

class SearchActiveChip extends Equatable {
  const SearchActiveChip({
    required this.group,
    required this.value,
    required this.label,
  });

  final String group;
  final String value;
  final String label;

  @override
  List<Object?> get props => [group, value, label];
}

class SearchFilterSelection extends Equatable {
  const SearchFilterSelection({
    this.categories = const {},
    this.metals = const {},
    this.purities = const {},
    this.weights = const {},
    this.sizes = const {},
    this.wastages = const {},
    this.stores = const {},
    this.locations = const {},
    this.sort = SearchSortOption.newest,
  });

  final Set<String> categories;
  final Set<String> metals;
  final Set<String> purities;
  final Set<String> weights;
  final Set<String> sizes;
  final Set<String> wastages;
  final Set<String> stores;
  final Set<String> locations;
  final SearchSortOption sort;

  bool get hasActiveFilters =>
      categories.isNotEmpty ||
      metals.isNotEmpty ||
      purities.isNotEmpty ||
      weights.isNotEmpty ||
      sizes.isNotEmpty ||
      wastages.isNotEmpty ||
      stores.isNotEmpty ||
      locations.isNotEmpty;

  int get activeFilterCount =>
      categories.length +
      metals.length +
      purities.length +
      weights.length +
      sizes.length +
      wastages.length +
      stores.length +
      locations.length;

  List<SearchActiveChip> chips(SearchFilterCatalog catalog) {
    return [
      for (final v in categories)
        SearchActiveChip(
          group: 'category',
          value: v,
          label: catalog.labelFor('category', v),
        ),
      for (final v in metals)
        SearchActiveChip(
          group: 'metal',
          value: v,
          label: catalog.labelFor('metal', v),
        ),
      for (final v in purities)
        SearchActiveChip(
          group: 'purity',
          value: v,
          label: catalog.labelFor('purity', v),
        ),
      for (final v in weights)
        SearchActiveChip(
          group: 'weight',
          value: v,
          label: catalog.labelFor('weight', v),
        ),
      for (final v in sizes)
        SearchActiveChip(
          group: 'size',
          value: v,
          label: catalog.labelFor('size', v),
        ),
      for (final v in wastages)
        SearchActiveChip(
          group: 'wastage',
          value: v,
          label: catalog.labelFor('wastage', v),
        ),
      for (final v in stores)
        SearchActiveChip(
          group: 'store',
          value: v,
          label: catalog.labelFor('store', v),
        ),
      for (final v in locations)
        SearchActiveChip(
          group: 'location',
          value: v,
          label: catalog.labelFor('location', v),
        ),
    ];
  }

  SearchFilterSelection copyWith({
    Set<String>? categories,
    Set<String>? metals,
    Set<String>? purities,
    Set<String>? weights,
    Set<String>? sizes,
    Set<String>? wastages,
    Set<String>? stores,
    Set<String>? locations,
    SearchSortOption? sort,
  }) {
    return SearchFilterSelection(
      categories: categories ?? this.categories,
      metals: metals ?? this.metals,
      purities: purities ?? this.purities,
      weights: weights ?? this.weights,
      sizes: sizes ?? this.sizes,
      wastages: wastages ?? this.wastages,
      stores: stores ?? this.stores,
      locations: locations ?? this.locations,
      sort: sort ?? this.sort,
    );
  }

  SearchFilterSelection clearedFilters({SearchSortOption? keepSort}) {
    return SearchFilterSelection(sort: keepSort ?? sort);
  }

  SearchFilterSelection removeChip(SearchActiveChip chip) {
    switch (chip.group) {
      case 'category':
        return copyWith(categories: {...categories}..remove(chip.value));
      case 'metal':
        return copyWith(metals: {...metals}..remove(chip.value));
      case 'purity':
        return copyWith(purities: {...purities}..remove(chip.value));
      case 'weight':
        return copyWith(weights: {...weights}..remove(chip.value));
      case 'size':
        return copyWith(sizes: {...sizes}..remove(chip.value));
      case 'wastage':
        return copyWith(wastages: {...wastages}..remove(chip.value));
      case 'store':
        return copyWith(stores: {...stores}..remove(chip.value));
      case 'location':
        return copyWith(locations: {...locations}..remove(chip.value));
      default:
        return this;
    }
  }

  api.SearchQuery toApiQuery({
    String? q,
    String? cursor,
    int limit = 20,
  }) {
    return api.SearchQuery(
      q: q,
      categories: categories.toList(),
      metals: metals.toList(),
      purities: purities.toList(),
      weights: weights.toList(),
      sizes: sizes.toList(),
      wastages: wastages.toList(),
      stores: stores.toList(),
      locations: locations.toList(),
      sort: sort.apiValue,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  List<Object?> get props => [
        categories,
        metals,
        purities,
        weights,
        sizes,
        wastages,
        stores,
        locations,
        sort,
      ];
}

/// UI card model mapped from [api.SearchHit].
class SearchProductResult extends Equatable {
  const SearchProductResult({
    required this.id,
    required this.title,
    required this.collectionId,
    this.subGroupId,
    this.storeId = '',
    this.storeName = '',
    this.storeSlug = '',
    this.city = '',
    this.category = '',
    this.categoryLabel = '',
    this.metals = const [],
    this.purity = '',
    this.netWeight,
    this.wastage,
    this.sizeLabel = '',
    this.precisionTag = '',
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String collectionId;
  final String? subGroupId;
  final String storeId;
  final String storeName;
  final String storeSlug;
  final String city;
  final String category;
  final String categoryLabel;
  final List<String> metals;
  final String purity;
  final double? netWeight;
  final double? wastage;
  final String sizeLabel;
  final String precisionTag;
  final String? thumbnailUrl;

  List<String> get imagePaths =>
      thumbnailUrl == null || thumbnailUrl!.isEmpty
          ? const []
          : [thumbnailUrl!];

  int get toneIndex => id.hashCode.abs() % 6;

  Color get storeMarkColor {
    const palette = <Color>[
      AppColors.primary,
      Color(0xFFE8A838),
      Color(0xFF4FAE4E),
      Color(0xFFE67E22),
      Color(0xFF9B59B6),
      Color(0xFF1ABC9C),
    ];
    return palette[toneIndex % palette.length];
  }

  String get weightChip {
    if (netWeight == null) return '';
    final v = netWeight!;
    if (v == v.roundToDouble()) return '${v.toInt()} g';
    return '${v.toStringAsFixed(1)} g';
  }

  String get purityChip => purity.isEmpty ? '' : '$purity purity';

  String get wastageChip {
    if (wastage == null) return '';
    final v = wastage!;
    if (v == v.roundToDouble()) return '${v.toInt()}% wastage';
    return '${v.toStringAsFixed(1)}% wastage';
  }

  factory SearchProductResult.fromHit(api.SearchHit hit) {
    final details = hit.details;
    final store = hit.store;
    final category = details.category;
    return SearchProductResult(
      id: hit.id,
      title: hit.title,
      collectionId: hit.collectionId ?? hit.id,
      subGroupId: hit.subGroupId,
      storeId: store?.id ?? '',
      storeName: store?.name ?? '',
      storeSlug: store?.slug ?? '',
      city: store?.city ?? '',
      category: category,
      categoryLabel: _titleCase(category),
      metals: details.metalType,
      purity: details.purity,
      netWeight: details.netWeight,
      wastage: details.wastage,
      sizeLabel: details.size,
      precisionTag: details.precisionTag,
      thumbnailUrl: hit.thumbnailUrl,
    );
  }

  /// Product typeahead row — includes top-level [api.SearchSuggestMatch.storeId].
  factory SearchProductResult.fromSuggest(api.SearchSuggestMatch match) {
    return SearchProductResult(
      id: match.id,
      title: match.title,
      collectionId: match.collectionId ?? match.id,
      subGroupId: match.subGroupId,
      storeId: match.storeId ?? '',
      storeName: match.storeName,
      storeSlug: match.slug ?? '',
      city: match.city,
      purity: match.purity ?? '',
      netWeight: match.netWeight,
      thumbnailUrl: match.thumbnailUrl,
    );
  }

  /// Public listing id for `GET .../collections/:collectionId`.
  String get listingId {
    final cid = collectionId.trim();
    if (cid.isNotEmpty) return cid;
    return id.trim();
  }

  /// Seed card for product details; id is the public listing id.
  StoreProduct toStoreProduct() {
    return StoreProduct(
      id: listingId,
      title: title,
      description: precisionTag,
      tags: [
        if (categoryLabel.isNotEmpty) categoryLabel,
        if (purityChip.isNotEmpty) purityChip,
        if (weightChip.isNotEmpty) weightChip,
      ],
      imagePaths: imagePaths,
      toneIndex: toneIndex % 4,
    );
  }

  /// Args for [Routes.productDetailsRoute] from a single hit (suggest fallback).
  Map<String, Object?> toProductDetailsArgs({
    required String storeId,
    String? storeNameFallback,
    String storeLink = '',
    bool isOwnStore = false,
  }) {
    return productDetailsArgsFromResults(
      results: [this],
      tappedIndex: 0,
      storeIdFallback: storeId,
      storeNameFallback: storeNameFallback,
      storeLinkFallback: storeLink,
      isOwnStore: isOwnStore,
    );
  }

  /// Build a swipe feed of **search result hits** (filtered list), seated on
  /// [tappedIndex]. Swipe moves to the next/previous hit — not other photos of
  /// the same collection.
  static Map<String, Object?> productDetailsArgsFromResults({
    required List<SearchProductResult> results,
    required int tappedIndex,
    String storeIdFallback = '',
    String? storeNameFallback,
    String storeLinkFallback = '',
    bool isOwnStore = false,
  }) {
    final safe =
        results
            .where(
              (r) =>
                  r.listingId.isNotEmpty &&
                  (r.storeId.trim().isNotEmpty ||
                      storeIdFallback.trim().isNotEmpty),
            )
            .toList();
    if (safe.isEmpty) {
      return <String, Object?>{
        'product': StoreProduct(
          id: '',
          title: '',
          description: '',
          tags: const [],
          imagePaths: const [],
        ),
        'storeId': storeIdFallback,
        'storeName': storeNameFallback ?? 'Store',
        'storeLink': storeLinkFallback,
        'isOwnStore': isOwnStore,
        'imageIndex': 0,
        'galleryFeed': <ProductDetailsFeedItem>[],
        'galleryFeedIndex': 0,
      };
    }
    final index = tappedIndex.clamp(0, safe.length - 1);
    final feed = <ProductDetailsFeedItem>[
      for (final hit in safe) hit._toFeedItem(storeIdFallback: storeIdFallback),
    ];
    final tapped = safe[index];
    final storeId =
        tapped.storeId.trim().isNotEmpty
            ? tapped.storeId.trim()
            : storeIdFallback.trim();
    final slug = tapped.storeSlug.trim();
    final name =
        tapped.storeName.trim().isNotEmpty
            ? tapped.storeName.trim()
            : (storeNameFallback?.trim().isNotEmpty == true
                ? storeNameFallback!.trim()
                : 'Store');
    final link =
        slug.isNotEmpty
            ? '$slug.jewelflow.app'
            : storeLinkFallback;
    return <String, Object?>{
      'product': tapped.toStoreProduct(),
      'storeId': storeId,
      'storeName': name,
      'storeLink': link,
      'isOwnStore': isOwnStore,
      'imageIndex': 0,
      'galleryFeed': feed,
      'galleryFeedIndex': index,
      if (tapped.category.trim().isNotEmpty) 'category': tapped.category.trim(),
      'showStoreGroupLink': true,
    };
  }

  ProductDetailsFeedItem _toFeedItem({String storeIdFallback = ''}) {
    final product = toStoreProduct();
    final path = product.imagePaths.isEmpty ? '' : product.imagePaths.first;
    final sid =
        storeId.trim().isNotEmpty ? storeId.trim() : storeIdFallback.trim();
    final slug = storeSlug.trim();
    return ProductDetailsFeedItem(
      product: product,
      imageIndex: 0,
      path: path,
      storeId: sid.isEmpty ? null : sid,
      storeName: storeName.trim().isEmpty ? null : storeName.trim(),
      storeLink: slug.isEmpty ? null : '$slug.jewelflow.app',
      seedCategory: category.trim().isEmpty ? null : category.trim(),
    );
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  @override
  List<Object?> get props => [
        id,
        title,
        collectionId,
        subGroupId,
        storeId,
        storeName,
        storeSlug,
        city,
        category,
        categoryLabel,
        metals,
        purity,
        netWeight,
        wastage,
        sizeLabel,
        precisionTag,
        thumbnailUrl,
      ];
}
