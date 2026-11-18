import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/store_product.dart';

/// One photo in a multi-product details swipe feed (e.g. store gallery / search).
class ProductDetailsFeedItem extends Equatable {
  const ProductDetailsFeedItem({
    required this.product,
    required this.imageIndex,
    required this.path,
    this.storeId,
    this.storeName,
    this.storeLink,
    this.seedCategory,
    this.seedCatalog,
  });

  final StoreProduct product;

  /// Index within [product.imagePaths] (0 when the product has no paths).
  final int imageIndex;
  final String path;

  /// Per-hit store context (global search can span stores). Null = keep route store.
  final String? storeId;
  final String? storeName;
  final String? storeLink;

  /// Category seed until detail specs load (search hits).
  final String? seedCategory;

  /// Full list/detail [CatalogProduct] when the opener already loaded it
  /// (e.g. collection browse `products?collectionId=`). Details can hydrate
  /// specs / liked / wishlisted from this and skip `GET /products/:id`.
  final CatalogProduct? seedCatalog;

  @override
  List<Object?> get props => [
        product.id,
        imageIndex,
        path,
        storeId,
        storeName,
        storeLink,
        seedCategory,
        seedCatalog?.id,
        seedCatalog?.liked,
        seedCatalog?.wishlisted,
        seedCatalog?.likeCount,
        seedCatalog?.viewCount,
      ];
}
