import 'dart:async';
import 'dart:io';

import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/catalog_upload_story.dart';
import 'package:project_c/helper/jewel_upload_qa.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
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
  final Map<String, CatalogUploadCancelToken> _cancelTokens = {};
  static const _tag = 'ProductUploadCoordinator';
  static const _maxPhotoBytes = 500 * 1024 * 1024;

  Stream<ProductUploadEvent> get events => _controller.stream;

  /// Stops further S3 PUTs for [pendingId]. Staging objects stay uncommitted
  /// and are purged by S3 lifecycle. Create commit is skipped when cancelled
  /// before success. Intentional Back→store continues upload (not cancelled).
  bool cancelPending(String pendingId) {
    final token = _cancelTokens[pendingId];
    if (token == null) return false;
    token.cancel();
    AppLog.d(_tag, 'cancel requested pending=$pendingId');
    return true;
  }

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
    _cancelTokens[pendingId] = CatalogUploadCancelToken();
    _controller.add(
      ProductUploadStarted(
        pendingId: pendingId,
        storeId: request.storeId,
        title: title,
        photoCount: request.imagePaths.length,
      ),
    );
    CatalogMediaDebug.upload(
      'coordinator startTitleOnly pending=$pendingId store=${request.storeId} '
      'photos=${request.imagePaths.length} title=$title',
    );
    CatalogUploadStory.beginPublish(
      title: title,
      photoCount: request.imagePaths.length,
      storeId: request.storeId,
      mode: 'titleOnly',
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
    _cancelTokens[pendingId] = CatalogUploadCancelToken();
    _controller.add(
      ProductUploadStarted(
        pendingId: pendingId,
        storeId: request.storeId,
        title: title,
        photoCount: request.items.length,
      ),
    );
    CatalogMediaDebug.upload(
      'coordinator startWithSpecs pending=$pendingId store=${request.storeId} '
      'photos=${request.items.length} title=$title',
    );
    CatalogUploadStory.beginPublish(
      title: title,
      photoCount: request.items.length,
      storeId: request.storeId,
      mode: 'withSpecs',
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

      final cancelToken = _cancelTokens[pendingId];
      final batch = await _directUpload.prepareAndUpload(
        storeId: request.storeId,
        localPaths: request.imagePaths,
        cancelToken: cancelToken,
      );
      if (batch.cancelled) {
        _finishFailure(
          pendingId: pendingId,
          storeId: request.storeId,
          message: 'Upload cancelled.',
        );
        return;
      }
      if (batch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      final thumbYes =
          batch.successful
              .where((p) => (p.thumbhash ?? '').trim().isNotEmpty)
              .length;
      CatalogUploadStory.beginCommit(
        photoCount: batch.successful.length,
        thumbhashYes: thumbYes,
        title: title,
      );

      final stockWire = request.stockStatus.apiValue;
      final canBatch = batch.successful.every(
        (p) => p.imageId.trim().isNotEmpty,
      );

      StoreProduct product;
      List<FailedPhoto> failedPhotos = _failedFromNames(batch.failedNames);

      if (canBatch) {
        JewelUploadQa.step(
          'Commit branch: products/batch',
          detail:
              'titleOnly pending=$pendingId count=${batch.successful.length} '
              'all imageId present',
        );
        final rows = request.photoRows;
        final products = <Map<String, dynamic>>[];
        for (var i = 0; i < batch.successful.length; i++) {
          final photo = batch.successful[i];
          final row = i < rows.length ? rows[i] : null;
          final spec = row?.spec ?? request.composeSpec;
          final rowStock = row?.stockStatus.apiValue ?? stockWire;
          final rowMto = row?.mtoDays ?? request.mtoDays;
          final rowLocked = row?.isLocked ?? request.isLocked;
          final rowTags =
              (row != null && row.tags.isNotEmpty) ? row.tags : request.tags;
          products.add(
            spec.toBatchProductJson(
              imageId: photo.imageId.trim(),
              stockStatus: rowStock,
              mtoDays: rowMto,
              isLocked: rowLocked,
              tags: rowTags,
              title: title.isEmpty ? null : title,
              thumbhash: photo.thumbhash,
              imageKey: photo.key,
              imageBytes: photo.bytes,
              imageWidth: photo.width,
              imageHeight: photo.height,
            ),
          );
        }
        final defaults = _collectionDefaultsFromSpec(
          rows.isNotEmpty ? rows.first.spec : request.composeSpec,
        );
        CatalogMediaDebug.upload(
          'coordinator commit products/batch pending=$pendingId '
          'count=${products.length} thumbhashYES=$thumbYes',
        );
        final created = await _collectionRepository.createProductsBatch(
          storeId: request.storeId,
          products: products,
          collectionName: title.isEmpty ? null : title,
          collectionDefaults: defaults.isEmpty ? null : defaults,
          idempotencyKey: pendingId,
        );
        final collectionId = created.collection?.id.trim() ?? '';
        if (collectionId.isNotEmpty) {
          _bindListing(pendingId, request.storeId, collectionId);
        } else if (created.products.isNotEmpty) {
          _bindListing(pendingId, request.storeId, created.products.first.id);
        }
        CatalogUploadStory.commitOk(
          listingId: collectionId.isNotEmpty
              ? collectionId
              : (created.products.isNotEmpty ? created.products.first.id : ''),
          photoCount: batch.successful.length,
        );
        product = _productFromBatchResult(
          created: created,
          fallbackTitle: title,
          fallbackDescription: description,
          fallbackTags: request.tags,
          fallbackPaths: request.imagePaths,
          isLocked: request.isLocked,
          stockStatus: request.stockStatus,
          mtoDays: request.mtoDays,
          uploadedPhotos: batch.successful,
        );
      } else {
        // Sign had no imageId — legacy collection commit.
        JewelUploadQa.step(
          'Commit branch: legacy collections',
          detail:
              'titleOnly pending=$pendingId photos=${batch.successful.length} '
              '(missing imageId)',
        );
        CatalogMediaDebug.upload(
          'coordinator commit createCollectionFromUploads pending=$pendingId '
          'photos=${batch.successful.length} (no imageId)',
        );
        final created = await _collectionRepository.createCollectionFromUploads(
          storeId: request.storeId,
          name: title,
          photos: batch.successful,
          tag: tag,
          description: description,
        );
        _bindListing(pendingId, request.storeId, created.id);
        CatalogUploadStory.commitOk(
          listingId: created.id,
          photoCount: batch.successful.length,
        );
        failedPhotos = [
          ...created.failedPhotos,
          ..._failedFromNames(batch.failedNames),
        ];
        try {
          final detail = await _collectionRepository.fetchCollection(
            storeId: request.storeId,
            listingId: created.id,
          );
          product = CatalogUiMapper.detailToProduct(detail).copyWith(
            isLocked: request.isLocked,
            stockStatus: request.stockStatus,
            mtoDays: request.mtoDays,
          );
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
            isLocked: request.isLocked,
            stockStatus: request.stockStatus,
            mtoDays: request.mtoDays,
          );
        }
      }

      AppLog.d(_tag, 'titleOnly OK pending=$pendingId id=${product.id}');
      CatalogUploadStory.done();
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
      CatalogUploadStory.note(
        'Upload failed: ${CatalogErrorMapper.toUserMessage(e)}',
      );
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

      final cancelToken = _cancelTokens[pendingId];
      final batch = await _directUpload.prepareAndUpload(
        storeId: request.storeId,
        localPaths: [for (final item in items) item.imagePath],
        cancelToken: cancelToken,
      );
      if (batch.cancelled) {
        _finishFailure(
          pendingId: pendingId,
          storeId: request.storeId,
          message: 'Upload cancelled.',
        );
        return;
      }
      if (batch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      final thumbYes =
          batch.successful
              .where((p) => (p.thumbhash ?? '').trim().isNotEmpty)
              .length;
      CatalogUploadStory.beginCommit(
        photoCount: batch.successful.length,
        thumbhashYes: thumbYes,
        title: groupTitle,
      );

      final successfulLocalItems = _itemsForSuccessfulUploads(
        items: items,
        successful: batch.successful,
      );

      final stockWire = request.stockStatus.apiValue;
      final canBatch = batch.successful.every(
        (p) => p.imageId.trim().isNotEmpty,
      );

      StoreProduct product;
      List<FailedPhoto> failedPhotos = _failedFromNames(batch.failedNames);

      if (canBatch) {
        JewelUploadQa.step(
          'Commit branch: products/batch',
          detail:
              'withSpecs pending=$pendingId count=${batch.successful.length} '
              'all imageId present photoRows=${request.photoRows.length}',
        );
        final photoRowsByItemId = <String, TitleOnlyPhotoRow>{
          for (var i = 0;
              i < request.items.length && i < request.photoRows.length;
              i++)
            request.items[i].id: request.photoRows[i],
        };
        final products = _batchProductsFromSpecs(
          items: successfulLocalItems,
          photos: batch.successful,
          groupSpec: request.groupSpec,
          stockStatus: stockWire,
          mtoDays: request.mtoDays,
          isLocked: request.isLocked,
          tags: request.tags,
          groupTitle: groupTitle,
          photoRowsByItemId: photoRowsByItemId,
        );
        JewelUploadQa.step(
          'Batch stock/lock (withSpecs)',
          detail: [
            for (var i = 0; i < products.length; i++)
              '[$i] stock=${products[i]['stock_status']} '
              'locked=${products[i]['is_locked']}',
          ].join(' '),
        );
        final defaults = _collectionDefaultsFromSpec(request.groupSpec);
        CatalogMediaDebug.upload(
          'coordinator specs commit products/batch pending=$pendingId '
          'count=${products.length}',
        );
        final created = await _collectionRepository.createProductsBatch(
          storeId: request.storeId,
          products: products,
          collectionName: groupTitle.isEmpty ? null : groupTitle,
          collectionDefaults: defaults.isEmpty ? null : defaults,
          idempotencyKey: pendingId,
        );
        final collectionId = created.collection?.id.trim() ?? '';
        if (collectionId.isNotEmpty) {
          _bindListing(pendingId, request.storeId, collectionId);
        } else if (created.products.isNotEmpty) {
          _bindListing(pendingId, request.storeId, created.products.first.id);
        }
        CatalogUploadStory.commitOk(
          listingId: collectionId.isNotEmpty
              ? collectionId
              : (created.products.isNotEmpty ? created.products.first.id : ''),
          photoCount: batch.successful.length,
        );
        product = _productFromBatchResult(
          created: created,
          fallbackTitle: groupTitle,
          fallbackDescription: description,
          fallbackTags: [
            ...request.tags,
            request.groupSpec.category,
            ...request.groupSpec.metalType,
          ],
          fallbackPaths: [for (final item in items) item.imagePath],
          isLocked: request.isLocked,
          stockStatus: request.stockStatus,
          mtoDays: request.mtoDays,
          uploadedPhotos: batch.successful,
        );
      } else {
        // Legacy collection + subgroup commit when imageId missing.
        JewelUploadQa.step(
          'Commit branch: legacy collections',
          detail:
              'withSpecs pending=$pendingId photos=${batch.successful.length} '
              '(missing imageId)',
        );
        CatalogMediaDebug.upload(
          'coordinator specs commit createCollectionFromUploads pending=$pendingId '
          'photos=${batch.successful.length} (no imageId)',
        );
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
        CatalogUploadStory.commitOk(
          listingId: created.id,
          photoCount: batch.successful.length,
        );
        failedPhotos = [
          ...created.failedPhotos,
          ..._failedFromNames(batch.failedNames),
        ];

        var detail = await _collectionRepository.fetchCollection(
          storeId: request.storeId,
          listingId: created.id,
        );
        var revision = detail.revision;

        final localToPhotoId = <String, String>{};
        final photos = detail.photos;
        for (var i = 0;
            i < successfulLocalItems.length && i < photos.length;
            i++) {
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

        try {
          detail = await _collectionRepository.fetchCollection(
            storeId: request.storeId,
            listingId: created.id,
          );
          product = CatalogUiMapper.detailToProduct(detail).copyWith(
            isLocked: request.isLocked,
            stockStatus: request.stockStatus,
            mtoDays: request.mtoDays,
          );
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
            isLocked: request.isLocked,
            stockStatus: request.stockStatus,
            mtoDays: request.mtoDays,
          );
        }
      }

      AppLog.d(_tag, 'specs OK pending=$pendingId id=${product.id}');
      CatalogUploadStory.done();
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
      CatalogUploadStory.note(
        'Upload failed: ${CatalogErrorMapper.toUserMessage(e)}',
      );
      _finishFailure(
        pendingId: pendingId,
        storeId: request.storeId,
        message: CatalogErrorMapper.toUserMessage(e),
      );
    }
  }

  Map<String, dynamic> _collectionDefaultsFromSpec(ProductSpec spec) {
    final out = <String, dynamic>{};
    final metalRaw =
        spec.metalType.isEmpty
            ? ''
            : spec.metalType.first.trim().toLowerCase();
    if (metalRaw.isNotEmpty) {
      out['metal'] = switch (metalRaw) {
        'rose gold' || 'rosegold' => 'rose_gold',
        _ => metalRaw.replaceAll(' ', '_'),
      };
    }
    final purity = (spec.purity ?? '').replaceAll('%', '').trim();
    if (purity.isNotEmpty) out['purity'] = purity;
    if (spec.wastagePercent != null) {
      out['wastage_pct'] = spec.wastagePercent;
    }
    return out;
  }

  /// One product per photo; Precise/Standalone clusters with 2+ photos →
  /// `image_ids` (same physical piece).
  List<Map<String, dynamic>> _batchProductsFromSpecs({
    required List<BulkUploadItem> items,
    required List<CatalogUploadedPhoto> photos,
    required ProductSpec groupSpec,
    required String stockStatus,
    int? mtoDays,
    required bool isLocked,
    required List<String> tags,
    required String groupTitle,
    Map<String, TitleOnlyPhotoRow> photoRowsByItemId = const {},
  }) {
    final byPath = <String, CatalogUploadedPhoto>{
      for (final p in photos)
        if ((p.localPath ?? '').trim().isNotEmpty) p.localPath!.trim(): p,
    };
    CatalogUploadedPhoto? photoFor(BulkUploadItem item) {
      final path = item.imagePath.trim();
      final matched = byPath[path];
      if (matched != null) return matched;
      final i = items.indexOf(item);
      if (i >= 0 && i < photos.length) return photos[i];
      return null;
    }

    ({String stock, int? mto, bool locked}) stockFor(BulkUploadItem item) {
      final row = photoRowsByItemId[item.id];
      return (
        stock: row?.stockStatus.apiValue ?? stockStatus,
        mto: row?.mtoDays ?? mtoDays,
        locked: row?.isLocked ?? isLocked,
      );
    }

    final products = <Map<String, dynamic>>[];
    final groupItems =
        items.where((i) => i.tag == BulkItemTag.group).toList();
    for (final item in groupItems) {
      final photo = photoFor(item);
      final imageId = photo?.imageId.trim() ?? '';
      if (imageId.isEmpty) continue;
      final spec = item.spec.isValid ? item.spec : groupSpec;
      final wire = stockFor(item);
      products.add(
        spec.toBatchProductJson(
          imageId: imageId,
          stockStatus: wire.stock,
          mtoDays: wire.mto,
          isLocked: wire.locked,
          tags: [
            ...tags,
            if (spec.category.trim().isNotEmpty) spec.category.trim(),
          ],
          title: groupTitle.isEmpty ? null : groupTitle,
          thumbhash: photo?.thumbhash,
          imageKey: photo?.key,
          imageBytes: photo?.bytes,
          imageWidth: photo?.width,
          imageHeight: photo?.height,
        ),
      );
    }

    final clusters = <String, List<BulkUploadItem>>{};
    for (final item in items) {
      if (item.tag != BulkItemTag.precise &&
          item.tag != BulkItemTag.standalone) {
        continue;
      }
      clusters.putIfAbsent(_precisionClusterKey(item), () => []).add(item);
    }
    for (final entry in clusters.entries) {
      final cluster = entry.value;
      final clusterPhotos = [
        for (final item in cluster)
          if (photoFor(item) != null) photoFor(item)!,
      ];
      final imageIds = [
        for (final p in clusterPhotos)
          if (p.imageId.trim().isNotEmpty) p.imageId.trim(),
      ];
      if (imageIds.isEmpty) continue;
      final spec =
          cluster.first.spec.isValid ? cluster.first.spec : groupSpec;
      final primary = clusterPhotos.first;
      final wire = stockFor(cluster.first);
      products.add(
        spec.toBatchProductJson(
          imageId: imageIds.length == 1 ? imageIds.first : null,
          imageIds: imageIds.length > 1 ? imageIds : null,
          stockStatus: wire.stock,
          mtoDays: wire.mto,
          isLocked: wire.locked,
          tags: [
            ...tags,
            if (spec.category.trim().isNotEmpty) spec.category.trim(),
          ],
          title: groupTitle.isEmpty ? null : groupTitle,
          thumbhash: primary.thumbhash,
          imageKey: primary.key,
          imageBytes: primary.bytes,
          imageWidth: primary.width,
          imageHeight: primary.height,
        ),
      );
    }

    // Fallback: if tagging left nothing, one row per uploaded photo.
    if (products.isEmpty) {
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final imageId = photo.imageId.trim();
        if (imageId.isEmpty) continue;
        final item = i < items.length ? items[i] : null;
        final spec =
            (item != null && item.spec.isValid) ? item.spec : groupSpec;
        final wire =
            item != null
                ? stockFor(item)
                : (stock: stockStatus, mto: mtoDays, locked: isLocked);
        products.add(
          spec.toBatchProductJson(
            imageId: imageId,
            stockStatus: wire.stock,
            mtoDays: wire.mto,
            isLocked: wire.locked,
            tags: tags,
            title: groupTitle.isEmpty ? null : groupTitle,
            thumbhash: photo.thumbhash,
            imageKey: photo.key,
            imageBytes: photo.bytes,
            imageWidth: photo.width,
            imageHeight: photo.height,
          ),
        );
      }
    }
    return products;
  }

  StoreProduct _productFromBatchResult({
    required CatalogProductBatchResult created,
    required String fallbackTitle,
    required String fallbackDescription,
    required List<String> fallbackTags,
    required List<String> fallbackPaths,
    required bool isLocked,
    required CatalogStockStatus stockStatus,
    int? mtoDays,
    List<CatalogUploadedPhoto> uploadedPhotos = const [],
  }) {
    final mapped =
        created.products
            .map(CatalogUiMapper.catalogProductToStoreProduct)
            .map((p) => _mergeLocalThumbhashes(p, uploadedPhotos))
            .toList();
    final collectionId = created.collection?.id.trim() ?? '';
    final localHashes = [
      for (final u in uploadedPhotos) (u.thumbhash ?? '').trim(),
    ];
    if (mapped.isEmpty) {
      return StoreProduct(
        id:
            collectionId.isNotEmpty
                ? collectionId
                : 'batch_${DateTime.now().microsecondsSinceEpoch}',
        title: fallbackTitle,
        description: fallbackDescription,
        tags: fallbackTags,
        imagePaths: fallbackPaths,
        imageThumbhashes: localHashes,
        canEdit: true,
        canDelete: true,
        isLocked: isLocked,
        stockStatus: stockStatus,
        mtoDays: mtoDays,
        collectionId: collectionId,
      );
    }
    if (mapped.length == 1) {
      final one = mapped.first;
      return one.copyWith(
        title: one.title.trim().isEmpty ? fallbackTitle : one.title,
        isLocked: isLocked,
        stockStatus: stockStatus,
        mtoDays: mtoDays,
        collectionId:
            one.collectionId.isNotEmpty ? one.collectionId : collectionId,
        imageThumbhashes:
            one.imageThumbhashes.any((h) => h.trim().isNotEmpty)
                ? one.imageThumbhashes
                : localHashes,
      );
    }
    final urls = [
      for (final p in mapped)
        ...p.imagePaths.where((u) => u.trim().isNotEmpty),
    ];
    // Prefer per-product hashes; fill gaps from local upload order.
    final mergedHashes = <String>[];
    var localIndex = 0;
    for (final p in mapped) {
      if (p.imageThumbhashes.any((h) => h.trim().isNotEmpty)) {
        mergedHashes.addAll(p.imageThumbhashes);
        localIndex += p.imagePaths.length;
      } else {
        for (var i = 0; i < p.imagePaths.length; i++) {
          final h =
              localIndex < localHashes.length ? localHashes[localIndex] : '';
          mergedHashes.add(h);
          localIndex++;
        }
      }
    }
    return StoreProduct(
      id: collectionId.isNotEmpty ? collectionId : mapped.first.id,
      title: fallbackTitle.isNotEmpty ? fallbackTitle : mapped.first.title,
      description: fallbackDescription,
      tags: fallbackTags,
      imagePaths: urls,
      photoAssetIds: [for (final p in mapped) ...p.photoAssetIds],
      imageThumbhashes:
          mergedHashes.isNotEmpty ? mergedHashes : localHashes,
      canEdit: true,
      canDelete: true,
      isLocked: isLocked || mapped.any((p) => p.isLocked),
      stockStatus: stockStatus,
      mtoDays: mtoDays ?? mapped.first.mtoDays,
      precisionTag: mapped.first.precisionTag,
      collectionId: collectionId,
      createdAt: mapped.first.createdAt,
    );
  }

  /// When batch response omits thumbhash / responsive URLs, keep sign-time values.
  StoreProduct _mergeLocalThumbhashes(
    StoreProduct product,
    List<CatalogUploadedPhoto> uploaded,
  ) {
    if (uploaded.isEmpty) return product;
    final byImageId = <String, CatalogUploadedPhoto>{
      for (final u in uploaded)
        if (u.imageId.trim().isNotEmpty) u.imageId.trim(): u,
    };
    final hashes = <String>[];
    final thumbs = <String>[];
    final details = <String>[];
    var serverYes = 0;
    var mergedFromLocal = 0;
    var thumbFromSign = 0;
    var detailFromSign = 0;
    for (var i = 0; i < product.imagePaths.length; i++) {
      final existing =
          i < product.imageThumbhashes.length
              ? product.imageThumbhashes[i].trim()
              : '';
      final existingThumb =
          i < product.imageThumbnailUrls.length
              ? product.imageThumbnailUrls[i].trim()
              : '';
      final existingDetail =
          i < product.imageDetailUrls.length
              ? product.imageDetailUrls[i].trim()
              : '';
      final assetId =
          i < product.photoAssetIds.length
              ? product.photoAssetIds[i].trim()
              : '';
      final fromId = assetId.isNotEmpty ? byImageId[assetId] : null;
      final fromOrder = i < uploaded.length ? uploaded[i] : null;
      final local = fromId ?? fromOrder;

      if (existing.isNotEmpty) {
        hashes.add(existing);
        serverYes++;
      } else {
        final localHash = (local?.thumbhash ?? '').trim();
        if (localHash.isNotEmpty) mergedFromLocal++;
        hashes.add(localHash);
      }

      if (existingThumb.isNotEmpty) {
        thumbs.add(existingThumb);
      } else {
        final t = (local?.thumbnailUrl ?? '').trim();
        if (t.isNotEmpty) thumbFromSign++;
        thumbs.add(t);
      }

      if (existingDetail.isNotEmpty) {
        details.add(existingDetail);
      } else {
        final d = (local?.detailUrl ?? '').trim();
        if (d.isNotEmpty) detailFromSign++;
        details.add(d);
      }
    }
    BeVerify.step(
      '2 batch thumbhash',
      detail:
          'product=${BeVerify.shortId(product.id)} '
          'serverYES=$serverYes localMerge=$mergedFromLocal '
          'paths=${product.imagePaths.length}',
    );
    CatalogMediaDebug.upload(
      'batch merge product=${product.id} thumbhash serverYES=$serverYes '
      'localMerge=$mergedFromLocal thumbFromSign=$thumbFromSign '
      'detailFromSign=$detailFromSign',
    );
    if (serverYes == product.imagePaths.length && product.imagePaths.isNotEmpty) {
      BeVerify.ok('thumbhash from server batch response');
    } else if (mergedFromLocal > 0) {
      BeVerify.fail(
        'thumbhash missing on batch response — FE merged local',
        detail: 'serverYES=$serverYes localMerge=$mergedFromLocal',
      );
    }
    if (thumbFromSign > 0 || detailFromSign > 0) {
      CatalogMediaDebug.gap(
        'batch response omitted responsive URLs — FE merged from sign '
        'thumb=$thumbFromSign detail=$detailFromSign',
      );
    }
    final noChange =
        hashes.every((h) => h.isEmpty) &&
        product.imageThumbhashes.every((h) => h.trim().isEmpty) &&
        thumbs.every((h) => h.isEmpty) &&
        details.every((h) => h.isEmpty);
    if (noChange) return product;
    return product.copyWith(
      imageThumbhashes: hashes,
      imageThumbnailUrls: thumbs,
      imageDetailUrls: details,
    );
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
    _cancelTokens.remove(pendingId);
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
    _cancelTokens.remove(pendingId);
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
