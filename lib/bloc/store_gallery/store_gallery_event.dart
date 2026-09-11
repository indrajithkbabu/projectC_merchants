part of 'store_gallery_bloc.dart';

sealed class StoreGalleryEvent extends Equatable {
  const StoreGalleryEvent();

  @override
  List<Object?> get props => [];
}

class StoreGalleryColumnsChanged extends StoreGalleryEvent {
  const StoreGalleryColumnsChanged(this.columns);

  final int columns;

  @override
  List<Object?> get props => [columns];
}

class StoreGalleryProductUpdated extends StoreGalleryEvent {
  const StoreGalleryProductUpdated(
    this.product, {
    this.replacedListingId,
  });

  final StoreProduct product;
  final String? replacedListingId;

  @override
  List<Object?> get props => [product, replacedListingId];
}

class StoreGalleryProductDeleted extends StoreGalleryEvent {
  const StoreGalleryProductDeleted(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}
