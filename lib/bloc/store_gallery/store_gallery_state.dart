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
    this.crossAxisCount = 5,
  });

  static const int minColumns = 4;

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
    final sorted = List<StoreProduct>.from(products)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final grouped = <DateTime, List<StoreProduct>>{};
    for (final product in sorted) {
      grouped.putIfAbsent(product.addedDate, () => []).add(product);
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final date in dates)
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

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _dateLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}';
  }

  /// Flat photo order matching the gallery grid (day → product → images).
  List<ProductDetailsFeedItem> buildPhotoFeed() {
    final feed = <ProductDetailsFeedItem>[];
    for (final day in sections) {
      for (final section in day.products) {
        final paths = section.imagePaths;
        if (paths.isEmpty) {
          feed.add(
            ProductDetailsFeedItem(
              product: section.product,
              imageIndex: 0,
              path: '',
            ),
          );
          continue;
        }
        for (var i = 0; i < paths.length; i++) {
          feed.add(
            ProductDetailsFeedItem(
              product: section.product,
              imageIndex: i,
              path: paths[i],
            ),
          );
        }
      }
    }
    return feed;
  }

  int feedIndexFor({
    required String productId,
    required int imageIndex,
  }) {
    final feed = buildPhotoFeed();
    final idx = feed.indexWhere(
      (e) => e.product.id == productId && e.imageIndex == imageIndex,
    );
    return idx < 0 ? 0 : idx;
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
