import 'dart:async';
import 'dart:io';

import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_upload_models.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/storage/store_products_cache.dart';

sealed class ProductUploadEvent {
  const ProductUploadEvent({required this.pendingId, required this.storeId});

  final String pendingId;
  final String storeId;
}

class ProductUploadStarted extends ProductUploadEvent {
  const ProductUploadStarted({
    required super.pendingId,
    required super.storeId,
    required this.title,
    required this.photoCount,
  });

  final String title;
  final int photoCount;
}

/// Fired after create returns a listing id — profile must hide that listing
/// until [ProductUploadSucceeded] (partial appends otherwise paint real tiles).
class ProductUploadListingBound extends ProductUploadEvent {
  const ProductUploadListingBound({
    required super.pendingId,
    required super.storeId,
    required this.listingId,
  });

  final String listingId;
}

class ProductUploadSucceeded extends ProductUploadEvent {
  const ProductUploadSucceeded({
    required super.pendingId,
    required super.storeId,
    required this.product,
    this.partialMessage,
  });

  final StoreProduct product;
  final String? partialMessage;
}

class ProductUploadFailed extends ProductUploadEvent {
  const ProductUploadFailed({
    required super.pendingId,
    required super.storeId,
    required this.message,
  });

  final String message;
}

/// Runs create uploads off the add-product screens so UI can return to store
/// immediately and show a pending shimmer until completion.
///
/// Photos are compressed on-device, uploaded directly to S3 via pre-signed URLs,
/// then committed as JSON (`photos: [{key, thumbhash, …}]`) — binaries never
/// pass through the Node.js application server.
class ProductUploadCoordinator {
  ProductUploadCoordinator({
    CollectionRepository? collectionRepository,
    CatalogDirectUploadService? directUploadService,
  }) : _collectionRepository =
           collectionRepository ?? ServiceLocator.get<CollectionRepository>(),
       _directUpload =
           directUploadService ??
           ServiceLocator.get<CatalogDirectUploadService>();

  final CollectionRepository _collectionRepository;
  final CatalogDirectUploadService _directUpload;
  final _controller = StreamController<ProductUploadEvent>.broadcast();
  final Map<String, PendingProductUpload> _active = {};
  static const _tag = 'ProductUploadCoordinator';
  static const _maxPhotoBytes = 500 * 1024 * 1024;

  Stream<ProductUploadEvent> get events => _controller.stream;

  /// In-flight uploads for [storeId] (survives store-profile route dispose).
  List<PendingProductUpload> pendingForStore(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return const [];
    return [
      for (final pending in _active.values)
        if (pending.storeId == id) pending,
    ];
  }

  /// Collection ids already created but still finishing — hide from grid.
  Set<String> inFlightListingIdsForStore(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return const {};
    return {
      for (final pending in _active.values)
        if (pending.storeId == id)
          if ((pending.listingId ?? '').trim().isNotEmpty)
            pending.listingId!.trim(),
    };
  }

  bool get hasActiveUploads => _active.isNotEmpty;

  String startTitleOnly(TitleOnlyUploadRequest request) {
    final pendingId = _newId();
    final title =
        request.title.trim().isEmpty ? 'Uploading…' : request.title.trim();
    _active[pendingId] = PendingProductUpload(
      id: pendingId,
      storeId: request.storeId,
      title: title,
      photoCount: request.imagePaths.length,
    );
    _controller.add(
      ProductUploadStarted(
        pendingId: pendingId,
        storeId: request.storeId,
        title: title,
        photoCount: request.imagePaths.length,
      ),
    );
    unawaited(_runTitleOnly(pendingId, request));
    return pendingId;
  }

  String startWithSpecs(SpecsUploadRequest request) {
    final pendingId = _newId();
    final title =
        request.title.trim().isEmpty ? 'Uploading…' : request.title.trim();
    _active[pendingId] = PendingProductUpload(
      id: pendingId,
      storeId: request.storeId,
      title: title,
      photoCount: request.items.length,
    );
    _controller.add(
      ProductUploadStarted(
        pendingId: pendingId,
        storeId: request.storeId,
        title: title,
        photoCount: request.items.length,
      ),
    );
    unawaited(_runWithSpecs(pendingId, request));
    return pendingId;
  }

  String _newId() =>
      'pending_${DateTime.now().microsecondsSinceEpoch}_${_controller.hashCode}';

  void _bindListing(String pendingId, String storeId, String listingId) {
    final id = listingId.trim();
    if (id.isEmpty) return;
    final existing = _active[pendingId];
    if (existing == null) return;
    _active[pendingId] = existing.copyWith(listingId: id);
    AppLog.d(
      'ProductUploadCoordinator',
      'listingBound pending=$pendingId id=$id',
    );
    _controller.add(
      ProductUploadListingBound(
        pendingId: pendingId,
        storeId: storeId,
        listingId: id,
      ),
    );
  }

  Future<void> _runTitleOnly(
    String pendingId,
    TitleOnlyUploadRequest request,
  ) async {
    try {
      final photoFiles = [
        for (final path in request.imagePaths) File(path),
      ];
      await _assertPhotoSizes(photoFiles);
      if (photoFiles.isEmpty) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_PHOTOS',
          message: 'Pick at least one photo.',
        );
      }

      final title = request.title.trim();
      final tag = _apiTag(request.tags);
      final description = request.description.trim();

      final batch = await _directUpload.prepareAndUpload(
        storeId: request.storeId,
        localPaths: request.imagePaths,
      );
      if (batch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      final created = await _collectionRepository.createCollectionFromUploads(
        storeId: request.storeId,
        name: title,
        photos: batch.successful,
        tag: tag,
        description: description,
      );
      _bindListing(pendingId, request.storeId, created.id);

      final failedPhotos = [
        ...created.failedPhotos,
        ..._failedFromNames(batch.failedNames),
      ];

      StoreProduct product;
      try {
        final detail = await _collectionRepository.fetchCollection(
          storeId: request.storeId,
          listingId: created.id,
        );
        product = CatalogUiMapper.detailToProduct(detail);
      } catch (_) {
        product = StoreProduct(
          id: created.id,
          title: created.name.isNotEmpty ? created.name : title,
          description:
              created.description.isNotEmpty
                  ? created.description
                  : description,
          tags: [
            if (created.tag.isNotEmpty) created.tag,
            ...request.tags.where((t) => t != created.tag),
          ],
          imagePaths: request.imagePaths,
          canEdit: true,
          canDelete: true,
        );
      }

      AppLog.d(_tag, 'titleOnly OK pending=$pendingId id=${product.id}');
      _finishSuccess(
        pendingId: pendingId,
        storeId: request.storeId,
        product: product,
        partialMessage:
            failedPhotos.isNotEmpty
                ? CatalogErrorMapper.failedPhotosSummary(failedPhotos)
                : null,
      );
    } catch (e) {
      AppLog.e(_tag, 'titleOnly failed pending=$pendingId', e);
      _finishFailure(
        pendingId: pendingId,
        storeId: request.storeId,
        message: CatalogErrorMapper.toUserMessage(e),
      );
    }
  }

  Future<void> _runWithSpecs(
    String pendingId,
    SpecsUploadRequest request,
  ) async {
    try {
      if (!request.groupSpec.isValid) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'INVALID_SPEC',
          message:
              'Group details are incomplete. Fill weight, purity, wastage, size, metal, and category.',
        );
      }

      final items = request.items;
      final photoFiles = [for (final item in items) File(item.imagePath)];
      await _assertPhotoSizes(photoFiles);
      if (photoFiles.isEmpty) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_PHOTOS',
          message: 'Pick at least one photo.',
        );
      }

      final groupTitle = request.title.trim();
      final tag = _apiTag(request.tags);
      final description = request.description.trim();

      final batch = await _directUpload.prepareAndUpload(
        storeId: request.storeId,
        localPaths: [for (final item in items) item.imagePath],
      );
      if (batch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      // Keep item↔photo order for subgroup mapping: only commit photos that
      // uploaded, aligned with the matching local items by successful key order.
      final created = await _collectionRepository.createCollectionFromUploads(
        storeId: request.storeId,
        name: groupTitle,
        photos: batch.successful,
        tag: tag,
        description: description,
        specifications: request.groupSpec.toApiJson(),
        usePrecisionTag: true,
      );
      _bindListing(pendingId, request.storeId, created.id);

      final failedPhotos = [
        ...created.failedPhotos,
        ..._failedFromNames(batch.failedNames),
      ];

      var detail = await _collectionRepository.fetchCollection(
        storeId: request.storeId,
        listingId: created.id,
      );
      var revision = detail.revision;

      // Map successful uploads back to local items by original path basename
      // order: prepareAndUpload preserves input order for successful items that
      // correspond to the same indices that succeeded. Prefer photo order from
      // the commit response (same order as [batch.successful]).
      final successfulLocalItems = _itemsForSuccessfulUploads(
        items: items,
        successful: batch.successful,
      );

      final localToPhotoId = <String, String>{};
      final photos = detail.photos;
      for (var i = 0; i < successfulLocalItems.length && i < photos.length; i++) {
        final photoId = photos[i].id?.trim() ?? '';
        if (photoId.isNotEmpty) {
          localToPhotoId[successfulLocalItems[i].id] = photoId;
        }
      }

      final subgroupCandidates =
          successfulLocalItems
              .where(
                (item) =>
                    item.tag == BulkItemTag.precise ||
                    item.tag == BulkItemTag.standalone,
              )
              .toList();

      final clusters = <String, List<BulkUploadItem>>{};
      for (final item in subgroupCandidates) {
        clusters.putIfAbsent(_precisionClusterKey(item), () => []).add(item);
      }

      var subIndex = 1;
      for (final entry in clusters.entries) {
        final photoIds =
            entry.value
                .map((item) => localToPhotoId[item.id])
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toList();
        if (photoIds.isEmpty) continue;
        final clusterSpec = entry.value.first.spec;
        if (!clusterSpec.isValid) continue;

        final isStandaloneCluster = entry.value.every(
          (item) => item.tag == BulkItemTag.standalone,
        );
        final label = _clusterDisplayName(
          items: entry.value,
          groupTitle: groupTitle,
          subIndex: subIndex,
          isStandalone: isStandaloneCluster,
          knownSubGroups: request.knownSubGroups,
        );

        try {
          await _collectionRepository.createSubGroup(
            storeId: request.storeId,
            listingId: created.id,
            name: label,
            tag: clusterSpec.category,
            photoIds: photoIds,
            revision: revision,
            specifications: clusterSpec.toApiJson(),
            usePrecisionTag: true,
          );
          detail = await _collectionRepository.fetchCollection(
            storeId: request.storeId,
            listingId: created.id,
          );
          revision = detail.revision;
        } catch (e) {
          AppLog.e(_tag, 'createSubGroup failed for $label', e);
        }
        subIndex++;
      }

      StoreProduct product;
      try {
        detail = await _collectionRepository.fetchCollection(
          storeId: request.storeId,
          listingId: created.id,
        );
        product = CatalogUiMapper.detailToProduct(detail);
      } catch (_) {
        product = StoreProduct(
          id: created.id,
          title: created.name.isNotEmpty ? created.name : groupTitle,
          description:
              created.description.isNotEmpty
                  ? created.description
                  : description,
          tags: [
            if (created.tag.isNotEmpty) created.tag,
            ...request.tags.where((t) => t != created.tag),
            request.groupSpec.category,
            ...request.groupSpec.metalType,
          ],
          imagePaths: items.map((e) => e.imagePath).toList(),
          canEdit: true,
          canDelete: true,
        );
      }

      AppLog.d(_tag, 'specs OK pending=$pendingId id=${product.id}');
      _finishSuccess(
        pendingId: pendingId,
        storeId: request.storeId,
        product: product,
        partialMessage:
            failedPhotos.isNotEmpty
                ? CatalogErrorMapper.failedPhotosSummary(failedPhotos)
                : null,
      );
    } catch (e) {
      AppLog.e(_tag, 'specs failed pending=$pendingId', e);
      _finishFailure(
        pendingId: pendingId,
        storeId: request.storeId,
        message: CatalogErrorMapper.toUserMessage(e),
      );
    }
  }

  /// Align successful S3 uploads back to local items (same path order).
  List<BulkUploadItem> _itemsForSuccessfulUploads({
    required List<BulkUploadItem> items,
    required List<CatalogUploadedPhoto> successful,
  }) {
    if (successful.length == items.length) return items;
    final byPath = <String, BulkUploadItem>{
      for (final item in items) item.imagePath.trim(): item,
    };
    final matched = <BulkUploadItem>[];
    final used = <String>{};
    for (final photo in successful) {
      final path = photo.localPath?.trim() ?? '';
      final item = path.isNotEmpty ? byPath[path] : null;
      if (item != null && used.add(item.id)) {
        matched.add(item);
      }
    }
    return matched.isEmpty ? items.take(successful.length).toList() : matched;
  }

  List<FailedPhoto> _failedFromNames(List<String> names) {
    return [
      for (final name in names)
        FailedPhoto(
          fileName: name,
          code: 'S3_UPLOAD_FAILED',
          message: 'Upload failed',
        ),
    ];
  }

  void _finishSuccess({
    required String pendingId,
    required String storeId,
    required StoreProduct product,
    String? partialMessage,
  }) {
    _active.remove(pendingId);
    // Persist even if store profile is not open so return visits see the product.
    unawaited(_cachePublishedProduct(storeId: storeId, product: product));
    _controller.add(
      ProductUploadSucceeded(
        pendingId: pendingId,
        storeId: storeId,
        product: product,
        partialMessage: partialMessage,
      ),
    );
  }

  void _finishFailure({
    required String pendingId,
    required String storeId,
    required String message,
  }) {
    _active.remove(pendingId);
    _controller.add(
      ProductUploadFailed(
        pendingId: pendingId,
        storeId: storeId,
        message: message,
      ),
    );
  }

  Future<void> _cachePublishedProduct({
    required String storeId,
    required StoreProduct product,
  }) async {
    try {
      final existing =
          StoreProductsCache.instance.readMemory(storeId) ??
          const <StoreProduct>[];
      final next = [
        product,
        ...existing.where((p) => p.id != product.id),
      ];
      await StoreProductsCache.instance.write(storeId, next);
    } catch (e) {
      AppLog.e(_tag, 'cache published product failed', e);
    }
  }

  Future<void> _assertPhotoSizes(List<File> files) async {
    for (final file in files) {
      final length = await file.length();
      if (length <= 0 || length > _maxPhotoBytes) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'IMAGE_TOO_LARGE',
          message: 'Image exceeds size limit',
        );
      }
    }
  }

  String _apiTag(List<String> tags) {
    if (tags.isEmpty) return '';
    final joined =
        tags.map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ');
    if (joined.length <= 40) return joined;
    return joined.substring(0, 40).trim();
  }

  static String _precisionClusterKey(BulkUploadItem item) {
    final sub = item.subGroupId?.trim();
    if (sub != null && sub.isNotEmpty) return 'sub:$sub';
    return 'spec:${item.spec.hashCode}|${item.tag.name}';
  }

  static String _clusterDisplayName({
    required List<BulkUploadItem> items,
    required String groupTitle,
    required int subIndex,
    required bool isStandalone,
    required List<BulkKnownSubGroup> knownSubGroups,
  }) {
    final custom =
        items
            .map((item) => item.customTitle.trim())
            .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (custom.isNotEmpty) return custom;

    final knownName =
        items
            .map((item) => item.subGroupId?.trim() ?? '')
            .where((id) => id.isNotEmpty)
            .map((id) {
              for (final sub in knownSubGroups) {
                if (sub.id == id) return sub.name.trim();
              }
              return '';
            })
            .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    if (knownName.isNotEmpty) return knownName;

    final prefix = groupTitle.trim().isEmpty ? 'Item' : groupTitle.trim();
    return isStandalone
        ? '$prefix standalone $subIndex'
        : '$prefix precise $subIndex';
  }

  void dispose() {
    unawaited(_controller.close());
  }
}
