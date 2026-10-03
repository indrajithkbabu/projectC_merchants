/// How products are laid out on the store profile screen.
enum ProductViewMode {
  /// Current 2-column collection / group cards.
  group,

  /// One large product card per row; scroll for the rest.
  single,

  /// Photo gallery mosaic (all product images).
  gallery,
}

extension ProductViewModeX on ProductViewMode {
  String get storageValue => name;

  String get label => switch (this) {
    ProductViewMode.group => 'Group view',
    ProductViewMode.single => 'Single view',
    ProductViewMode.gallery => 'Gallery view',
  };

  String get subtitle => switch (this) {
    ProductViewMode.group => 'Collections in a two-column grid',
    ProductViewMode.single => 'One large product per row',
    ProductViewMode.gallery => 'Browse all photos like a gallery',
  };

  static ProductViewMode fromStorage(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return ProductViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ProductViewMode.group,
    );
  }
}
