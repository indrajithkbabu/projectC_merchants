import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

part 'add_store_product_event.dart';
part 'add_store_product_state.dart';

class AddStoreProductBloc
    extends Bloc<AddStoreProductEvent, AddStoreProductState> {
  AddStoreProductBloc({
    ImagePicker? imagePicker,
    AddStoreProductState? initialState,
    String? storeId,
    CollectionRepository? collectionRepository,
    CatalogDirectUploadService? directUploadService,
    CatalogSession? session,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _storeId = storeId,
       _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _directUpload =
           directUploadService ??
           ServiceLocator.get<CatalogDirectUploadService>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(
         initialState ??
             AddStoreProductState(
               storeId: storeId,
               galleryItems: List<GalleryImageItem>.generate(
                 12,
                 (index) => GalleryImageItem.placeholder(index),
               ),
             ),
       ) {
    on<AddStoreProductGalleryItemToggled>(_onGalleryItemToggled);
    on<AddStoreProductPickFromDevicePressed>(_onPickFromDevice);
    on<AddStoreProductContinueFromGalleryPressed>(_onContinueFromGallery);
    on<AddStoreProductClearGalleryContinue>(_onClearGalleryContinue);
    on<AddStoreProductTitleChanged>(_onTitleChanged);
    on<AddStoreProductDescriptionChanged>(_onDescriptionChanged);
    on<AddStoreProductTagDraftChanged>(_onTagDraftChanged);
    on<AddStoreProductTagAdded>(_onTagAdded);
    on<AddStoreProductTagRemoved>(_onTagRemoved);
    on<AddStoreProductSuggestedTagTapped>(_onSuggestedTagTapped);
    on<AddStoreProductImageRemoved>(_onImageRemoved);
    on<AddStoreProductImageReplaced>(_onImageReplaced);
    on<AddStoreProductImagesAppended>(_onImagesAppended);
    on<AddStoreProductAddMoreImagesPressed>(_onAddMoreImages);
    on<AddStoreProductPublishPressed>(_onPublishPressed);
    on<AddStoreProductClearPublished>(_onClearPublished);
    on<AddStoreProductClearMessage>(_onClearMessage);
  }

  final ImagePicker _imagePicker;
  final String? _storeId;
  final CollectionRepository _collectionRepository;
  final CatalogDirectUploadService _directUpload;
  final CatalogSession _session;
  static const _tag = 'AddStoreProductBloc';

  /// Matches CATALOG_IMAGES.md collection photo caps.
  static const maxPhotosPerCollection = 50;
  static const maxPhotoBytes = 500 * 1024 * 1024;

  /// Client downscale before multipart to reduce nginx 413 risk.
  static const _pickMaxDimension = 1920.0;
  static const _pickQuality = 85;

  static const suggestedTags = <String>[
    'gold',
    'silver',
    'rose gold',
    'necklace',
    'bracelet',
    'earrings',
    'pendant',
    'handmade',
    '22k',
  ];

  String? get _effectiveStoreId =>
      state.storeId ?? _storeId ?? _session.ownStoreId;

  void _onGalleryItemToggled(
    AddStoreProductGalleryItemToggled event,
    Emitter<AddStoreProductState> emit,
  ) {
    final selected = List<String>.from(state.selectedImageIds);
    if (selected.contains(event.imageId)) {
      selected.remove(event.imageId);
    } else {
      selected.add(event.imageId);
    }
    emit(state.copyWith(selectedImageIds: selected, clearError: true));
  }

  Future<void> _onPickFromDevice(
    AddStoreProductPickFromDevicePressed event,
    Emitter<AddStoreProductState> emit,
  ) async {
    emit(state.copyWith(isPickingImages: true, clearError: true));
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: _pickQuality,
        maxWidth: _pickMaxDimension,
        maxHeight: _pickMaxDimension,
      );
      if (picked.isEmpty) {
        emit(state.copyWith(isPickingImages: false));
        return;
      }

      final nextItems = List<GalleryImageItem>.from(state.galleryItems);
      final nextSelected = List<String>.from(state.selectedImageIds);
      for (final file in picked) {
        final id = 'device_${file.path.hashCode}_${nextItems.length}';
        nextItems.insert(
          0,
          GalleryImageItem(id: id, filePath: file.path, isPlaceholder: false),
        );
        if (!nextSelected.contains(id)) {
          nextSelected.add(id);
        }
      }
      emit(
        state.copyWith(
          galleryItems: nextItems,
          selectedImageIds: nextSelected,
          isPickingImages: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isPickingImages: false,
          errorMessage: 'Unable to open gallery right now.',
        ),
      );
    }
  }

  void _onContinueFromGallery(
    AddStoreProductContinueFromGalleryPressed event,
    Emitter<AddStoreProductState> emit,
  ) {
    if (!state.canContinueFromGallery) return;
    final hasLocal =
        state.selectedImages.any(
          (i) => i.filePath != null && !i.isPlaceholder,
        );
    if (!hasLocal) {
      emit(
        state.copyWith(
          errorMessage: 'Pick at least one photo from your device.',
        ),
      );
      return;
    }
    emit(state.copyWith(shouldOpenProductForm: true));
  }

  void _onClearGalleryContinue(
    AddStoreProductClearGalleryContinue event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(state.copyWith(clearShouldOpenProductForm: true));
  }

  void _onTitleChanged(
    AddStoreProductTitleChanged event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(state.copyWith(title: event.value, clearError: true));
  }

  void _onDescriptionChanged(
    AddStoreProductDescriptionChanged event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(state.copyWith(description: event.value, clearError: true));
  }

  void _onTagDraftChanged(
    AddStoreProductTagDraftChanged event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(state.copyWith(tagDraft: event.value));
  }

  void _onTagAdded(
    AddStoreProductTagAdded event,
    Emitter<AddStoreProductState> emit,
  ) {
    final tag = event.tag.trim().toLowerCase();
    if (tag.isEmpty || state.tags.contains(tag)) {
      emit(state.copyWith(tagDraft: ''));
      return;
    }
    emit(
      state.copyWith(
        tags: [...state.tags, tag],
        tagDraft: '',
        clearError: true,
      ),
    );
  }

  void _onTagRemoved(
    AddStoreProductTagRemoved event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(
      state.copyWith(
        tags: state.tags.where((t) => t != event.tag).toList(),
        clearError: true,
      ),
    );
  }

  void _onSuggestedTagTapped(
    AddStoreProductSuggestedTagTapped event,
    Emitter<AddStoreProductState> emit,
  ) {
    add(AddStoreProductTagAdded(event.tag));
  }

  void _onImageRemoved(
    AddStoreProductImageRemoved event,
    Emitter<AddStoreProductState> emit,
  ) {
    final nextSelected =
        state.selectedImageIds.where((id) => id != event.imageId).toList();
    final nextItems =
        state.galleryItems.where((item) => item.id != event.imageId).toList();
    emit(
      state.copyWith(
        selectedImageIds: nextSelected,
        galleryItems: nextItems,
        clearError: true,
      ),
    );
  }

  void _onImageReplaced(
    AddStoreProductImageReplaced event,
    Emitter<AddStoreProductState> emit,
  ) {
    final path = event.filePath.trim();
    if (path.isEmpty) return;
    emit(
      state.copyWith(
        galleryItems: [
          for (final item in state.galleryItems)
            item.id == event.imageId
                ? GalleryImageItem(
                  id: item.id,
                  filePath: path,
                  // Clear asset id so edit treats this as a new local upload.
                  assetId: null,
                  isPlaceholder: false,
                )
                : item,
        ],
        clearError: true,
      ),
    );
  }

  void _onImagesAppended(
    AddStoreProductImagesAppended event,
    Emitter<AddStoreProductState> emit,
  ) {
    final remainingSlots =
        maxPhotosPerCollection - state.selectedImageIds.length;
    if (remainingSlots <= 0) {
      emit(
        state.copyWith(
          errorMessage:
              'You can upload at most $maxPhotosPerCollection photos.',
        ),
      );
      return;
    }

    final nextItems = List<GalleryImageItem>.from(state.galleryItems);
    final nextSelected = List<String>.from(state.selectedImageIds);
    for (final path in event.filePaths.take(remainingSlots)) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) continue;
      final id = 'local_${trimmed.hashCode}_${nextItems.length}';
      nextItems.add(
        GalleryImageItem(id: id, filePath: trimmed, isPlaceholder: false),
      );
      nextSelected.add(id);
    }
    emit(
      state.copyWith(
        galleryItems: nextItems,
        selectedImageIds: nextSelected,
        isPickingImages: false,
        clearError: true,
      ),
    );
  }

  Future<void> _onAddMoreImages(
    AddStoreProductAddMoreImagesPressed event,
    Emitter<AddStoreProductState> emit,
  ) async {
    emit(state.copyWith(isPickingImages: true, clearError: true));
    try {
      final nextItems = List<GalleryImageItem>.from(state.galleryItems);
      final nextSelected = List<String>.from(state.selectedImageIds);
      final remainingSlots = maxPhotosPerCollection - nextSelected.length;
      if (remainingSlots <= 0) {
        emit(
          state.copyWith(
            isPickingImages: false,
            errorMessage:
                'You can upload at most $maxPhotosPerCollection photos.',
          ),
        );
        return;
      }

      if (event.source == ImageSource.camera) {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: _pickQuality,
          maxWidth: _pickMaxDimension,
          maxHeight: _pickMaxDimension,
        );
        if (photo == null) {
          emit(state.copyWith(isPickingImages: false));
          return;
        }
        final id = 'camera_${photo.path.hashCode}_${nextItems.length}';
        nextItems.add(
          GalleryImageItem(id: id, filePath: photo.path, isPlaceholder: false),
        );
        nextSelected.add(id);
      } else {
        final photos = await _imagePicker.pickMultiImage(
          imageQuality: _pickQuality,
          maxWidth: _pickMaxDimension,
          maxHeight: _pickMaxDimension,
        );
        if (photos.isEmpty) {
          emit(state.copyWith(isPickingImages: false));
          return;
        }
        for (final photo in photos.take(remainingSlots)) {
          final id = 'gallery_${photo.path.hashCode}_${nextItems.length}';
          nextItems.add(
            GalleryImageItem(
              id: id,
              filePath: photo.path,
              isPlaceholder: false,
            ),
          );
          nextSelected.add(id);
        }
      }

      emit(
        state.copyWith(
          galleryItems: nextItems,
          selectedImageIds: nextSelected,
          isPickingImages: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isPickingImages: false,
          errorMessage: 'Unable to open image picker right now.',
        ),
      );
    }
  }

  Future<void> _onPublishPressed(
    AddStoreProductPublishPressed event,
    Emitter<AddStoreProductState> emit,
  ) async {
    if (!state.canPublish) return;
    if (state.isEditMode) {
      await _publishEdit(emit);
      return;
    }
    await _publishCreate(emit);
  }

  Future<void> _publishCreate(Emitter<AddStoreProductState> emit) async {
    final storeId = _effectiveStoreId;
    if (storeId == null || storeId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Create a store before publishing products.',
        ),
      );
      return;
    }

    final localFiles =
        state.selectedImages
            .where((i) => i.filePath != null && !i.isPlaceholder)
            .take(maxPhotosPerCollection)
            .toList();
    if (localFiles.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Pick at least one photo from your device.',
        ),
      );
      return;
    }

    emit(state.copyWith(isPublishing: true, clearError: true));
    try {
      final photoFiles = [
        for (final item in localFiles) File(item.filePath!),
      ];
      await _assertPhotoSizes(photoFiles);

      final uploadBatch = await _directUpload.prepareAndUpload(
        storeId: storeId,
        localPaths: [for (final item in localFiles) item.filePath!],
      );
      if (uploadBatch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      final created = await _collectionRepository.createCollectionFromUploads(
        storeId: storeId,
        name: state.title.trim(),
        photos: uploadBatch.successful,
        tag: _apiTag(state.tags),
        description: state.description.trim(),
      );

      final revision = created.revision;
      final failedPhotos = [
        ...created.failedPhotos,
        for (final name in uploadBatch.failedNames)
          FailedPhoto(
            fileName: name,
            code: 'S3_UPLOAD_FAILED',
            message: 'Upload failed',
          ),
      ];

      StoreProduct product;
      try {
        final detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: created.id,
        );
        product = CatalogUiMapper.detailToProduct(detail);
      } catch (_) {
        product = StoreProduct(
          id: created.id,
          title: created.name,
          description:
              created.description.isNotEmpty
                  ? created.description
                  : state.description.trim(),
          tags: [
            if (created.tag.isNotEmpty) created.tag,
            ...state.tags.where((t) => t != created.tag),
          ],
          imagePaths: localFiles.map((e) => e.filePath!).toList(),
        );
      }

      final partialMessage =
          failedPhotos.isNotEmpty
              ? CatalogErrorMapper.failedPhotosSummary(failedPhotos)
              : null;

      AppLog.d(
        _tag,
        'Published collection ${created.id} '
        'photos=${product.imagePaths.length} failed=${failedPhotos.length}',
      );
      emit(
        state.copyWith(
          isPublishing: false,
          isPublished: true,
          publishedProduct: product,
          publishedRevision: revision,
          publishedApiTag: created.tag,
          errorMessage: partialMessage,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Publish failed', e);
      emit(
        state.copyWith(
          isPublishing: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _publishEdit(Emitter<AddStoreProductState> emit) async {
    final storeId = _effectiveStoreId;
    final listingId = state.listingId?.trim();
    if (storeId == null ||
        storeId.isEmpty ||
        listingId == null ||
        listingId.isEmpty) {
      emit(state.copyWith(errorMessage: 'Unable to update this product.'));
      return;
    }

    final selected =
        state.selectedImages
            .where((i) => i.filePath != null && !i.isPlaceholder)
            .take(maxPhotosPerCollection)
            .toList();
    if (selected.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Keep at least one photo on this product.',
        ),
      );
      return;
    }

    emit(state.copyWith(isPublishing: true, clearError: true));
    final tag = _apiTag(state.tags);
    final description = state.description.trim();
    final name = state.title.trim();

    try {
      if (!state.photosChangedInEdit) {
        final updated = await _collectionRepository.updateCollection(
          storeId: storeId,
          listingId: listingId,
          revision: state.revision,
          name: name,
          tag: tag,
          description: description,
        );
        await _emitEditedProduct(
          emit,
          storeId: storeId,
          listingId: listingId,
          fallback: updated,
          description: description,
          imagePaths: selected.map((e) => e.filePath!).toList(),
        );
        return;
      }

      // CATALOG_IMAGES: append new photos, delete removed photoIds, same listing.
      // Add first, then delete, so the collection never drops below 1 photo.
      var revision = state.revision;
      final failedPhotos = <FailedPhoto>[];

      var initialAssetIds = List<String>.from(state.initialPhotoAssetIds);
      final needsIdResolve =
          state.initialImagePaths.isNotEmpty &&
          (initialAssetIds.length < state.initialImagePaths.length ||
              initialAssetIds.every((e) => e.trim().isEmpty));
      if (needsIdResolve) {
        try {
          final detail = await _collectionRepository.fetchCollection(
            storeId: storeId,
            listingId: listingId,
          );
          initialAssetIds =
              detail.photos.map((p) => p.id?.trim() ?? '').toList();
          revision = detail.revision;
        } catch (e) {
          AppLog.e(_tag, 'Unable to resolve photo ids for edit', e);
        }
      }

      // Map selected network items back to asset ids via initial path index.
      final selectedWithIds = <GalleryImageItem>[];
      for (final item in selected) {
        final existing = item.assetId?.trim();
        if (existing != null && existing.isNotEmpty) {
          selectedWithIds.add(item);
          continue;
        }
        final path = item.filePath!;
        if (ProductImagePaths.isNetwork(path)) {
          final idx = state.initialImagePaths.indexOf(path);
          final resolved =
              idx >= 0 && idx < initialAssetIds.length
                  ? initialAssetIds[idx].trim()
                  : '';
          selectedWithIds.add(
            GalleryImageItem(
              id: item.id,
              filePath: item.filePath,
              assetId: resolved.isEmpty ? null : resolved,
              isPlaceholder: false,
            ),
          );
        } else {
          selectedWithIds.add(item);
        }
      }

      final keptAssetIds =
          selectedWithIds
              .map((e) => e.assetId?.trim() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
      final removedIds =
          initialAssetIds
              .map((e) => e.trim())
              .where((id) => id.isNotEmpty && !keptAssetIds.contains(id))
              .toList();

      final newLocals =
          selectedWithIds
              .where(
                (i) =>
                    i.filePath != null &&
                    !ProductImagePaths.isNetwork(i.filePath!) &&
                    (i.assetId == null || i.assetId!.trim().isEmpty),
              )
              .toList();

      if (newLocals.isNotEmpty) {
        final photoFiles = [for (final item in newLocals) File(item.filePath!)];
        await _assertPhotoSizes(photoFiles);
        final uploadBatch = await _directUpload.prepareAndUpload(
          storeId: storeId,
          localPaths: [for (final item in newLocals) item.filePath!],
        );
        if (uploadBatch.allFailed) {
          throw CatalogApiException(
            statusCode: 400,
            code: 'NO_VALID_PHOTOS',
            message: 'None of the new photos could be uploaded.',
          );
        }
        final added = await _collectionRepository.appendUploadedPhotos(
          storeId: storeId,
          listingId: listingId,
          photos: uploadBatch.successful,
          revision: revision,
        );
        revision = added.revision;
        failedPhotos.addAll(added.failedPhotos);
        failedPhotos.addAll([
          for (final name in uploadBatch.failedNames)
            FailedPhoto(
              fileName: name,
              code: 'S3_UPLOAD_FAILED',
              message: 'Upload failed',
            ),
        ]);
        // Metadata lives on JSON PATCH when photos were only appended.
        final meta = await _collectionRepository.updateCollection(
          storeId: storeId,
          listingId: listingId,
          revision: revision,
          name: name,
          tag: tag,
          description: description,
        );
        revision = meta.revision;
      }

      if (removedIds.isNotEmpty) {
        final deleted = await _collectionRepository.deletePhotos(
          storeId: storeId,
          listingId: listingId,
          photoIds: removedIds,
          revision: revision,
        );
        revision = deleted.revision;
      }

      if (newLocals.isEmpty) {
        final updated = await _collectionRepository.updateCollection(
          storeId: storeId,
          listingId: listingId,
          revision: revision,
          name: name,
          tag: tag,
          description: description,
        );
        revision = updated.revision;
        await _emitEditedProduct(
          emit,
          storeId: storeId,
          listingId: listingId,
          fallback: updated,
          description: description,
          imagePaths: selected.map((e) => e.filePath!).toList(),
          partialFailures: failedPhotos,
        );
        return;
      }

      await _emitEditedProduct(
        emit,
        storeId: storeId,
        listingId: listingId,
        fallback: CollectionMutation(
          id: listingId,
          name: name,
          tag: tag,
          description: description,
          revision: revision,
        ),
        description: description,
        imagePaths: selected.map((e) => e.filePath!).toList(),
        partialFailures: failedPhotos,
      );
      AppLog.d(_tag, 'Updated collection $listingId photos in place');
    } catch (e) {
      AppLog.e(_tag, 'Update collection failed', e);
      emit(
        state.copyWith(
          isPublishing: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _emitEditedProduct(
    Emitter<AddStoreProductState> emit, {
    required String storeId,
    required String listingId,
    required CollectionMutation fallback,
    required String description,
    required List<String> imagePaths,
    List<FailedPhoto> partialFailures = const [],
  }) async {
    final partialMessage =
        partialFailures.isNotEmpty
            ? CatalogErrorMapper.failedPhotosSummary(partialFailures)
            : null;
    try {
      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: listingId,
      );
      emit(
        state.copyWith(
          isPublishing: false,
          isPublished: true,
          publishedProduct: CatalogUiMapper.detailToProduct(detail),
          publishedRevision: detail.revision,
          publishedApiTag: detail.tag,
          revision: detail.revision,
          errorMessage: partialMessage,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isPublishing: false,
          isPublished: true,
          publishedProduct: StoreProduct(
            id: fallback.id,
            title: fallback.name,
            description:
                fallback.description.isNotEmpty
                    ? fallback.description
                    : description,
            tags: [
              if (fallback.tag.isNotEmpty) fallback.tag,
              ...state.tags.where((t) => t != fallback.tag),
            ],
            imagePaths: imagePaths,
          ),
          publishedRevision: fallback.revision,
          publishedApiTag: fallback.tag,
          revision: fallback.revision,
          errorMessage: partialMessage,
        ),
      );
    }
    AppLog.d(_tag, 'Updated collection $listingId rev=${fallback.revision}');
  }

  Future<void> _assertPhotoSizes(List<File> files) async {
    for (final file in files) {
      final length = await file.length();
      if (length <= 0 || length > maxPhotoBytes) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'IMAGE_TOO_LARGE',
          message: 'Image exceeds size limit',
        );
      }
    }
  }

  /// API accepts a single tag string (max 40). Join UI chips when possible.
  String _apiTag(List<String> tags) {
    if (tags.isEmpty) return '';
    final joined =
        tags.map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ');
    if (joined.length <= 40) return joined;
    return joined.substring(0, 40).trimRight();
  }

  void _onClearPublished(
    AddStoreProductClearPublished event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(state.copyWith(clearPublished: true));
  }

  void _onClearMessage(
    AddStoreProductClearMessage event,
    Emitter<AddStoreProductState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
