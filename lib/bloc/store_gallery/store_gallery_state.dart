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
    final now = DateTime.now();
    return [
      for (final date in dates)
        StoreGalleryDaySection(
          date: date,
          label: _dateLabel(date, now),
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

  static String _dateLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final stamp = '${_months[date.month - 1]} ${date.day}';
    if (date == today) return '$stamp (Today)';
    if (date == yesterday) return '$stamp (Yesterday)';
    return stamp;
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
