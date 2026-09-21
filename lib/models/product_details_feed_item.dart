import 'package:equatable/equatable.dart';
import 'package:project_c/models/store_product.dart';

/// One photo in a multi-product details swipe feed (e.g. store gallery).
class ProductDetailsFeedItem extends Equatable {
  const ProductDetailsFeedItem({
    required this.product,
    required this.imageIndex,
    required this.path,
  });

  final StoreProduct product;

  /// Index within [product.imagePaths] (0 when the product has no paths).
  final int imageIndex;
  final String path;

  @override
  List<Object?> get props => [product.id, imageIndex, path];
}
