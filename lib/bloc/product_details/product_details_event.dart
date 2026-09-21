part of 'product_details_bloc.dart';

sealed class ProductDetailsEvent extends Equatable {
  const ProductDetailsEvent();

  @override
  List<Object?> get props => [];
}

class ProductDetailsLoadPhotos extends ProductDetailsEvent {
  const ProductDetailsLoadPhotos();
}

class ProductDetailsActivateProduct extends ProductDetailsEvent {
  const ProductDetailsActivateProduct(this.product);

  final StoreProduct product;

  @override
  List<Object?> get props => [product];
}

class ProductDetailsSharePressed extends ProductDetailsEvent {
  const ProductDetailsSharePressed();
}

class ProductDetailsEditPressed extends ProductDetailsEvent {
  const ProductDetailsEditPressed();
}

class ProductDetailsDeletePressed extends ProductDetailsEvent {
  const ProductDetailsDeletePressed({required this.imageIndex});

  final int imageIndex;

  @override
  List<Object?> get props => [imageIndex];
}

class ProductDetailsClearOpenEdit extends ProductDetailsEvent {
  const ProductDetailsClearOpenEdit();
}

class ProductDetailsApplyEditedProduct extends ProductDetailsEvent {
  const ProductDetailsApplyEditedProduct({
    required this.product,
    required this.revision,
    this.apiTag = '',
  });

  final StoreProduct product;
  final int revision;
  final String apiTag;

  @override
  List<Object?> get props => [product, revision, apiTag];
}

class ProductDetailsClearDeleted extends ProductDetailsEvent {
  const ProductDetailsClearDeleted();
}

class ProductDetailsMorePressed extends ProductDetailsEvent {
  const ProductDetailsMorePressed();
}

class ProductDetailsClearMessage extends ProductDetailsEvent {
  const ProductDetailsClearMessage();
}
