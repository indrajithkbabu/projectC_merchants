/// Merchant stock state for jewel products (`stock_status` API).
enum CatalogStockStatus {
  inStock,
  outOfStock,
  mto;

  static CatalogStockStatus? tryParse(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'in':
      case 'in_stock':
      case 'instock':
        return CatalogStockStatus.inStock;
      case 'out':
      case 'out_of_stock':
      case 'outofstock':
        return CatalogStockStatus.outOfStock;
      case 'mto':
      case 'to_order':
      case 'toorder':
        return CatalogStockStatus.mto;
      default:
        return null;
    }
  }

  /// Wire value for `POST …/products/batch`.
  String get apiValue => switch (this) {
    CatalogStockStatus.inStock => 'in',
    CatalogStockStatus.outOfStock => 'out',
    CatalogStockStatus.mto => 'mto',
  };

  String get shortLabel => switch (this) {
    CatalogStockStatus.inStock => 'In stock',
    CatalogStockStatus.outOfStock => 'Out',
    CatalogStockStatus.mto => 'To order',
  };
}
