part of 'add_store_product_bloc.dart';

sealed class AddStoreProductEvent extends Equatable {
  const AddStoreProductEvent();

  @override
  List<Object?> get props => [];
}

class AddStoreProductGalleryItemToggled extends AddStoreProductEvent {
  const AddStoreProductGalleryItemToggled(this.imageId);

  final String imageId;

  @override
  List<Object?> get props => [imageId];
}

class AddStoreProductPickFromDevicePressed extends AddStoreProductEvent {
  const AddStoreProductPickFromDevicePressed();
}

class AddStoreProductContinueFromGalleryPressed extends AddStoreProductEvent {
  const AddStoreProductContinueFromGalleryPressed();
}

class AddStoreProductClearGalleryContinue extends AddStoreProductEvent {
  const AddStoreProductClearGalleryContinue();
}

class AddStoreProductTitleChanged extends AddStoreProductEvent {
  const AddStoreProductTitleChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AddStoreProductDescriptionChanged extends AddStoreProductEvent {
  const AddStoreProductDescriptionChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AddStoreProductTagDraftChanged extends AddStoreProductEvent {
  const AddStoreProductTagDraftChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class AddStoreProductTagAdded extends AddStoreProductEvent {
  const AddStoreProductTagAdded(this.tag);

  final String tag;

  @override
  List<Object?> get props => [tag];
}

class AddStoreProductTagRemoved extends AddStoreProductEvent {
  const AddStoreProductTagRemoved(this.tag);

  final String tag;

  @override
  List<Object?> get props => [tag];
}

class AddStoreProductSuggestedTagTapped extends AddStoreProductEvent {
  const AddStoreProductSuggestedTagTapped(this.tag);

  final String tag;

  @override
  List<Object?> get props => [tag];
}

class AddStoreProductImageRemoved extends AddStoreProductEvent {
  const AddStoreProductImageRemoved(this.imageId);

  final String imageId;

  @override
  List<Object?> get props => [imageId];
}

/// Replace a gallery item's local/network path (e.g. after crop).
/// Clears [assetId] so edit treats it as a new local photo.
class AddStoreProductImageReplaced extends AddStoreProductEvent {
  const AddStoreProductImageReplaced({
    required this.imageId,
    required this.filePath,
  });

  final String imageId;
  final String filePath;

  @override
  List<Object?> get props => [imageId, filePath];
}

/// Append already-picked (and optionally edited) local photo paths.
class AddStoreProductImagesAppended extends AddStoreProductEvent {
  const AddStoreProductImagesAppended(this.filePaths);

  final List<String> filePaths;

  @override
  List<Object?> get props => [filePaths];
}

class AddStoreProductAddMoreImagesPressed extends AddStoreProductEvent {
  const AddStoreProductAddMoreImagesPressed(this.source);

  final ImageSource source;

  @override
  List<Object?> get props => [source];
}

class AddStoreProductPublishPressed extends AddStoreProductEvent {
  const AddStoreProductPublishPressed();
}

class AddStoreProductClearPublished extends AddStoreProductEvent {
  const AddStoreProductClearPublished();
}

class AddStoreProductClearMessage extends AddStoreProductEvent {
  const AddStoreProductClearMessage();
}
