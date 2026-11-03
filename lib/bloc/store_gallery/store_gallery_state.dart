part of 'store_gallery_bloc.dart';

class StoreGalleryProductSection extends Equatable {
  const StoreGalleryProductSection({required this.product});

  final StoreProduct product;

  List<String> get imagePaths => product.imagePaths;

  int get tileCount => imagePaths.isEmpty ? 1 : imagePaths.length;

  @override
  List<Object?> get props => [product];
}

class StoreGalleryDaySection extends Equatable {
  const StoreGalleryDaySection({
    required this.date,
    required this.label,
    required this.products,
  });

  final DateTime date;
  final String label;
  final List<StoreGalleryProductSection> products;

  bool get isSingleProduct => products.length == 1;

  @override
  List<Object?> get props => [date, label, products];
}

class StoreGalleryState extends Equatable {
  const StoreGalleryState({
    required this.products,
    required this.storeName,
    required this.storeLink,
    required this.sections,
    this.storeId,
    this.isOwnStore = false,
    this.crossAxisCount = 4,
  });

  /// Align with channel Media / profile Gallery pinch (2…9).
  static const int minColumns = 2;
  static const int maxColumns = 9;

  final List<StoreProduct> products;
  final String storeName;
  final String storeLink;
  final String? storeId;
  final bool isOwnStore;
  final List<StoreGalleryDaySection> sections;
  final int crossAxisCount;

  StoreGalleryState copyWith({
    List<StoreProduct>? products,
    int? crossAxisCount,
  }) {
    final nextProducts = products ?? this.products;
    return StoreGalleryState(
      products: nextProducts,
      storeName: storeName,
      storeLink: storeLink,
      storeId: storeId,
      isOwnStore: isOwnStore,
      sections:
          products != null
              ? StoreGalleryState.buildSections(nextProducts)
              : sections,
      crossAxisCount: crossAxisCount ?? this.crossAxisCount,
    );
  }

  static List<StoreGalleryDaySection> buildSections(
    List<StoreProduct> products,
  ) {
    // Preserve incoming list order (same as store profile). Do not sort by
    // createdAt — mappers default it to DateTime.now() and that reshuffles.
    final grouped = <DateTime, List<StoreProduct>>{};
    final dateOrder = <DateTime>[];
    for (final product in products) {
      final day = product.addedDate;
      if (!grouped.containsKey(day)) {
        dateOrder.add(day);
        grouped[day] = [];
      }
      grouped[day]!.add(product);
    }

    return [
      for (final date in dateOrder)
        StoreGalleryDaySection(
          date: date,
          label: _dateLabel(date),
          products: [
            for (final product in grouped[date]!)
              StoreGalleryProductSection(product: product),
          ],
        ),
    ];
  }

  static String _dateLabel(DateTime date) => formatCatalogDayBucket(date);

  /// Flat photo order matching the gallery grid (day → listing → images).
  ///
  /// Enriched collection cards store nested CatalogProduct ids in
  /// [StoreProduct.photoAssetIds] — expand those so each feed item carries
  /// the jewel product (tap opens the right piece, not another listing).
  List<ProductDetailsFeedItem> buildPhotoFeed() {
    final feed = <ProductDetailsFeedItem>[];
    for (final day in sections) {
      for (final section in day.products) {
        final pieces = CatalogUiMapper.expandCollageToProducts(
          section.product,
        );
        for (final piece in pieces) {
          final paths = piece.imagePaths;
          if (paths.isEmpty) {
            feed.add(
              ProductDetailsFeedItem(
                product: piece,
                imageIndex: 0,
                path: '',
              ),
            );
            continue;
          }
          for (var i = 0; i < paths.length; i++) {
            feed.add(
              ProductDetailsFeedItem(
                product: piece,
                imageIndex: i,
                path: paths[i],
              ),
            );
          }
        }
      }
    }
    return feed;
  }

  /// Locate the feed slot for a collage / mosaic tap.
  ///
  /// Prefer exact [path] (master URL of the painted cell) so jewel-expanded
  /// feeds still hit the tapped frame when listing id ≠ nested product id.
  /// Falling back to `0` without a path check opened another listing's first
  /// photo — never return a slot whose path disagrees with a non-empty
  /// [path]; callers should omit the store-wide feed in that case.
  int feedIndexFor({
    required String productId,
    required int imageIndex,
    String path = '',
  }) {
    final feed = buildPhotoFeed();
    if (feed.isEmpty) return 0;

    final needle = path.trim();
    // 1) Exact master path — strongest signal for the painted cell.
    if (needle.isNotEmpty) {
      final byPath = feed.indexWhere((e) => e.path.trim() == needle);
      if (byPath >= 0) return byPath;
    }

    final id = productId.trim();
    if (id.isNotEmpty) {
      // 2) Nested jewel id + local album index.
      final byIdIndex = feed.indexWhere(
        (e) => e.product.id == id && e.imageIndex == imageIndex,
      );
      if (byIdIndex >= 0) return byIdIndex;

      // 3) First frame of that jewel (path unknown / album seed).
      final byId = feed.indexWhere((e) => e.product.id == id);
      if (byId >= 0) return byId;
    }

    return 0;
  }

  /// Feed + index for product-details open. When [path] is set and no slot
  /// matches it, [useFeed] is false so details opens [productId] at
  /// [imageIndex] instead of landing on another listing's feed[0].
  ({List<ProductDetailsFeedItem> feed, int index, bool useFeed}) resolveOpenFeed({
    required String productId,
    required int imageIndex,
    String path = '',
  }) {
    final feed = buildPhotoFeed();
    final index = feedIndexFor(
      productId: productId,
      imageIndex: imageIndex,
      path: path,
    );
    final needle = path.trim();
    if (feed.isEmpty) {
      return (feed: feed, index: 0, useFeed: false);
    }
    if (needle.isEmpty) {
      return (feed: feed, index: index, useFeed: true);
    }
    if (index < 0 ||
        index >= feed.length ||
        feed[index].path.trim() != needle) {
      return (feed: feed, index: 0, useFeed: false);
    }
    return (feed: feed, index: index, useFeed: true);
  }

  @override
  List<Object?> get props => [
    products,
    storeName,
    storeLink,
    storeId,
    isOwnStore,
    sections,
    crossAxisCount,
  ];
}
