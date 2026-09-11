part of 'add_store_product_bloc.dart';

class GalleryImageItem extends Equatable {
  const GalleryImageItem({
    required this.id,
    this.filePath,
    this.assetId,
    this.isPlaceholder = true,
    this.placeholderTone = 0,
  });

  factory GalleryImageItem.placeholder(int index) {
    return GalleryImageItem(
      id: 'placeholder_$index',
      isPlaceholder: true,
      placeholderTone: index % 4,
    );
  }

  final String id;
  final String? filePath;

  /// Catalog photo/asset id for an existing published photo.
  final String? assetId;
  final bool isPlaceholder;
  final int placeholderTone;

  @override
  List<Object?> get props => [
    id,
    filePath,
    assetId,
    isPlaceholder,
    placeholderTone,
  ];
}

class AddStoreProductState extends Equatable {
  const AddStoreProductState({
    this.storeId,
    this.isEditMode = false,
    this.listingId,
    this.revision = 1,
    this.initialImagePaths = const [],
    this.initialPhotoAssetIds = const [],
    this.galleryItems = const [],
    this.selectedImageIds = const [],
    this.isPickingImages = false,
    this.shouldOpenProductForm = false,
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.tagDraft = '',
    this.isPublishing = false,
    this.isPublished = false,
    this.publishedProduct,
    this.publishedRevision,
    this.publishedApiTag,
    this.replacedListingId,
    this.errorMessage,
  });

  final String? storeId;
  final bool isEditMode;
  final String? listingId;
  final int revision;
  final List<String> initialImagePaths;
  final List<String> initialPhotoAssetIds;
  final List<GalleryImageItem> galleryItems;
  final List<String> selectedImageIds;
  final bool isPickingImages;
  final bool shouldOpenProductForm;
  final String title;
  final String description;
  final List<String> tags;
  final String tagDraft;
  final bool isPublishing;
  final bool isPublished;
  final StoreProduct? publishedProduct;
  final int? publishedRevision;
  final String? publishedApiTag;
  final String? replacedListingId;
  final String? errorMessage;

  bool get canContinueFromGallery =>
      selectedImageIds.isNotEmpty && !isPickingImages;

  bool get canPublish {
    if (isPublishing) return false;
    if (title.trim().isEmpty) return false;
    return selectedImageIds.isNotEmpty;
  }

  /// True when edit-mode photo set differs from what was loaded.
  bool get photosChangedInEdit {
    if (!isEditMode) return false;
    final current =
        selectedImages
            .map((e) => e.filePath)
            .whereType<String>()
            .toList(growable: false);
    if (current.length != initialImagePaths.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != initialImagePaths[i]) return true;
    }
    return false;
  }

  GalleryImageItem? get primaryImage {
    final images = selectedImages;
    if (images.isEmpty) return null;
    return images.first;
  }

  List<GalleryImageItem> get selectedImages {
    final itemsById = {for (final item in galleryItems) item.id: item};
    return selectedImageIds
        .map((id) => itemsById[id])
        .whereType<GalleryImageItem>()
        .toList();
  }

  int selectionOrderOf(String imageId) {
    final index = selectedImageIds.indexOf(imageId);
    return index < 0 ? 0 : index + 1;
  }

  AddStoreProductState copyWith({
    String? storeId,
    bool? isEditMode,
    String? listingId,
    int? revision,
    List<String>? initialImagePaths,
    List<String>? initialPhotoAssetIds,
    List<GalleryImageItem>? galleryItems,
    List<String>? selectedImageIds,
    bool? isPickingImages,
    bool? shouldOpenProductForm,
    bool clearShouldOpenProductForm = false,
    String? title,
    String? description,
    List<String>? tags,
    String? tagDraft,
    bool? isPublishing,
    bool? isPublished,
    bool clearPublished = false,
    StoreProduct? publishedProduct,
    int? publishedRevision,
    String? publishedApiTag,
    String? replacedListingId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddStoreProductState(
      storeId: storeId ?? this.storeId,
      isEditMode: isEditMode ?? this.isEditMode,
      listingId: listingId ?? this.listingId,
      revision: revision ?? this.revision,
      initialImagePaths: initialImagePaths ?? this.initialImagePaths,
      initialPhotoAssetIds: initialPhotoAssetIds ?? this.initialPhotoAssetIds,
      galleryItems: galleryItems ?? this.galleryItems,
      selectedImageIds: selectedImageIds ?? this.selectedImageIds,
      isPickingImages: isPickingImages ?? this.isPickingImages,
      shouldOpenProductForm:
          clearShouldOpenProductForm
              ? false
              : (shouldOpenProductForm ?? this.shouldOpenProductForm),
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      tagDraft: tagDraft ?? this.tagDraft,
      isPublishing: isPublishing ?? this.isPublishing,
      isPublished: clearPublished ? false : (isPublished ?? this.isPublished),
      publishedProduct:
          clearPublished ? null : (publishedProduct ?? this.publishedProduct),
      publishedRevision:
          clearPublished
              ? null
              : (publishedRevision ?? this.publishedRevision),
      publishedApiTag:
          clearPublished ? null : (publishedApiTag ?? this.publishedApiTag),
      replacedListingId:
          clearPublished
              ? null
              : (replacedListingId ?? this.replacedListingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    storeId,
    isEditMode,
    listingId,
    revision,
    initialImagePaths,
    initialPhotoAssetIds,
    galleryItems,
    selectedImageIds,
    isPickingImages,
    shouldOpenProductForm,
    title,
    description,
    tags,
    tagDraft,
    isPublishing,
    isPublished,
    publishedProduct,
    publishedRevision,
    publishedApiTag,
    replacedListingId,
    errorMessage,
  ];
}
