import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_subgroup_name.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/whatsapp_invite.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/services/wishlist_prefetcher.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

part 'product_details_event.dart';
part 'product_details_state.dart';

class ProductDetailsBloc
    extends Bloc<ProductDetailsEvent, ProductDetailsState> {
  ProductDetailsBloc({
    required StoreProduct product,
    required String storeName,
    required String storeLink,
    String? storeId,
    bool isOwnStore = false,
    int initialImageIndex = 0,
    List<ProductDetailsFeedItem>? galleryFeed,
    int galleryFeedIndex = 0,
    String seedCategory = '',
    bool showStoreGroupLink = false,
    Set<String> initialLikedPhotoIds = const {},
    bool initialIsWishlisted = false,
    CollectionRepository? collectionRepository,
    WishlistRepository? wishlistRepository,
  }) : _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _wishlistRepository =
           wishlistRepository ?? ServiceLocator.get<WishlistRepository>(),
       super(
         ProductDetailsState(
           product: product,
           storeName: storeName,
           storeLink: storeLink,
           storeId: storeId,
           isOwnStore: isOwnStore,
           initialImageIndex: _clampIndex(initialImageIndex, product),
           galleryFeed: galleryFeed,
           galleryFeedIndex:
               (galleryFeed == null || galleryFeed.isEmpty)
                   ? 0
                   : galleryFeedIndex.clamp(0, galleryFeed.length - 1),
           isLoadingPhotos: _canFetchPhotos(storeId, product),
           seedCategory: seedCategory.trim(),
           showStoreGroupLink: showStoreGroupLink,
           canEdit: _resolveCanEdit(
             explicit: product.canEdit,
             isOwnStore: isOwnStore,
             kind: _kindFromProduct(product),
           ),
           canDelete: product.canDelete || isOwnStore,
           likedPhotoIds: initialLikedPhotoIds,
           isWishlisted: initialIsWishlisted,
           wishlistedProductIds:
               initialIsWishlisted && product.id.trim().isNotEmpty
                   ? {product.id.trim()}
                   : const {},
         ),
       ) {
    on<ProductDetailsLoadPhotos>(_onLoadPhotos);
    on<ProductDetailsActivateProduct>(_onActivateProduct);
    on<ProductDetailsSharePressed>(_onSharePressed);
    on<ProductDetailsEditPressed>(_onEditPressed);
    on<ProductDetailsDeletePressed>(_onDeletePressed);
    on<ProductDetailsClearOpenEdit>(_onClearOpenEdit);
    on<ProductDetailsApplyEditedProduct>(_onApplyEditedProduct);
    on<ProductDetailsClearDeleted>(_onClearDeleted);
    on<ProductDetailsMorePressed>(_onMorePressed);
    on<ProductDetailsClearMessage>(_onClearMessage);
    on<ProductDetailsLikePressed>(_onLikePressed);
    on<ProductDetailsWishlistPressed>(_onWishlistPressed);
    on<ProductDetailsClearWishlistSnack>(_onClearWishlistSnack);
    if (_canFetchPhotos(storeId, product)) {
      add(const ProductDetailsLoadPhotos());
    }
  }

  final CollectionRepository _collectionRepository;
  final WishlistRepository _wishlistRepository;
  static const _tag = 'ProductDetailsBloc';

  static bool _canFetchPhotos(String? storeId, StoreProduct product) {
    if (storeId == null || storeId.isEmpty) return false;
    if (storeId == 'my_store' || storeId == 'other_store') return false;
    if (product.id.trim().isEmpty) return false;
    return true;
  }

  static String? _kindFromProduct(StoreProduct product) {
    if (product.tags.contains('imported')) return 'imported';
    if (product.tags.contains('original')) return 'original';
    return null;
  }

  static bool _resolveCanEdit({
    bool? explicit,
    required bool isOwnStore,
    String? kind,
  }) {
    if (explicit == true) return true;
    if (!isOwnStore) return false;
    return kind != 'imported';
  }

  static int _clampIndex(int index, StoreProduct product) {
    final last = product.imagePaths.isEmpty ? 0 : product.imagePaths.length - 1;
    if (index < 0) return 0;
    if (index > last) return last;
    return index;
  }

  /// Map a seeded / previous photo onto [updated] after collection detail load.
  static int _resolvePreferredImageIndex({
    required StoreProduct previous,
    required StoreProduct updated,
    required int previousIndex,
    Set<String> preferredPhotoIds = const {},
  }) {
    String seedId = '';
    if (previousIndex >= 0 && previousIndex < previous.photoAssetIds.length) {
      seedId = previous.photoAssetIds[previousIndex].trim();
    }
    if (seedId.isEmpty && preferredPhotoIds.length == 1) {
      seedId = preferredPhotoIds.first;
    }
    if (seedId.isNotEmpty) {
      final byId = updated.photoAssetIds.indexWhere((e) => e.trim() == seedId);
      if (byId >= 0) return byId;
    }

    String seedPath = '';
    if (previousIndex >= 0 && previousIndex < previous.imagePaths.length) {
      seedPath = previous.imagePaths[previousIndex].trim();
    }
    if (seedPath.isNotEmpty) {
      final byPath = _indexOfImagePath(updated.imagePaths, seedPath);
      if (byPath >= 0) return byPath;
    }

    // Wishlist often seeds one liked photo — prefer first liked id in updated.
    for (final id in preferredPhotoIds) {
      final i = updated.photoAssetIds.indexWhere((e) => e.trim() == id);
      if (i >= 0) return i;
    }

    return _clampIndex(previousIndex, updated);
  }

  /// After detail load, align feed entries for [updated] with real photo indexes.
  /// Search feeds stay one slot per search hit (never expand to whole collection).
  static ({List<ProductDetailsFeedItem>? feed, int feedIndex}) _resolveGalleryFeed({
    required List<ProductDetailsFeedItem>? feed,
    required int feedIndex,
    required StoreProduct updated,
  }) {
    if (feed == null || feed.isEmpty) {
      return (feed: feed, feedIndex: 0);
    }
    final remapped = [for (final item in feed) _remapFeedItem(item, updated)];
    final safeIndex =
        feedIndex < 0
            ? 0
            : (feedIndex >= remapped.length ? remapped.length - 1 : feedIndex);
    return (feed: remapped, feedIndex: safeIndex);
  }

  static ProductDetailsFeedItem _remapFeedItem(
    ProductDetailsFeedItem item,
    StoreProduct updated,
  ) {
    if (item.product.id != updated.id) return item;
    final path = item.path.trim();
    var index = item.imageIndex;
    if (path.isNotEmpty) {
      final byUrl = _indexOfImagePath(updated.imagePaths, path);
      if (byUrl >= 0) index = byUrl;
    }
    index = _clampIndex(index, updated);
    final resolvedPath =
        path.isNotEmpty
            ? path
            : (updated.imagePaths.isEmpty
                ? item.path
                : updated.imagePaths[index]);
    // Keep destination importStatus from the seed collage / product when
    // collection detail omits parallel import arrays.
    final mergedProduct = updated.copyWith(
      importFlags:
          updated.importFlags.importStatus != null
              ? updated.importFlags
              : item.product.importFlags,
      imageImportStatuses:
          updated.imageImportStatuses.isNotEmpty
              ? updated.imageImportStatuses
              : (item.product.imageImportStatuses.isNotEmpty
                  ? item.product.imageImportStatuses
                  : null),
    );
    return ProductDetailsFeedItem(
      product: mergedProduct,
      imageIndex: index,
      path: resolvedPath,
      storeId: item.storeId,
      storeName: item.storeName,
      storeLink: item.storeLink,
      seedCategory: item.seedCategory,
    );
  }

  static int _indexOfImagePath(List<String> paths, String target) {
    final needle = target.trim();
    if (needle.isEmpty) return -1;
    final exact = paths.indexWhere((p) => p.trim() == needle);
    if (exact >= 0) return exact;
    final needleKey = _imagePathMatchKey(needle);
    if (needleKey.isEmpty) return -1;
    return paths.indexWhere((p) => _imagePathMatchKey(p) == needleKey);
  }

  /// Strip query/fragment and trailing image-format suffixes for loose match.
  static String _imagePathMatchKey(String raw) {
    var s = raw.trim();
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    final h = s.indexOf('#');
    if (h >= 0) s = s.substring(0, h);
    s = s.toLowerCase();
    const suffixes = ['.webp', '.jpg', '.jpeg', '.png'];
    var changed = true;
    while (changed) {
      changed = false;
      for (final suf in suffixes) {
        if (s.endsWith(suf)) {
          s = s.substring(0, s.length - suf.length);
          changed = true;
        }
      }
    }
    return s;
  }

  Future<void> _onLoadPhotos(
    ProductDetailsLoadPhotos event,
    Emitter<ProductDetailsState> emit,
  ) async {
    final storeId = state.storeId;
    if (!_canFetchPhotos(storeId, state.product)) {
      emit(state.copyWith(isLoadingPhotos: false));
      return;
    }

    final requestedListingId = state.product.id;
    emit(state.copyWith(isLoadingPhotos: true));
    try {
      // Jewel product id → GET /products/:id; else legacy collection detail.
      try {
        final catalogProduct = await _collectionRepository.fetchProduct(
          productId: requestedListingId,
        );
        if (emit.isDone) return;
        if (state.product.id != requestedListingId) {
          emit(state.copyWith(isLoadingPhotos: false));
          return;
        }
        if (catalogProduct.id.trim().isNotEmpty) {
          final fromProduct =
              CatalogUiMapper.catalogProductToStoreProduct(catalogProduct);
          final merged = state.product.copyWith(
            title:
                fromProduct.title.trim().isNotEmpty
                    ? fromProduct.title
                    : null,
            imagePaths:
                fromProduct.imagePaths.isNotEmpty
                    ? fromProduct.imagePaths
                    : null,
            photoAssetIds:
                fromProduct.photoAssetIds.isNotEmpty
                    ? fromProduct.photoAssetIds
                    : null,
            imageThumbhashes:
                fromProduct.imageThumbhashes.isNotEmpty
                    ? fromProduct.imageThumbhashes
                    : null,
            isLocked: fromProduct.isLocked,
            stockStatus: fromProduct.stockStatus,
            mtoDays: fromProduct.mtoDays,
            precisionTag:
                fromProduct.precisionTag.isNotEmpty
                    ? fromProduct.precisionTag
                    : null,
            collectionId:
                fromProduct.collectionId.isNotEmpty
                    ? fromProduct.collectionId
                    : null,
            likeCount: fromProduct.likeCount,
            viewCount: fromProduct.viewCount,
            importFlags: fromProduct.importFlags,
            imageImportStatuses:
                fromProduct.imageImportStatuses.isNotEmpty
                    ? fromProduct.imageImportStatuses
                    : null,
            canEdit: state.isOwnStore || state.product.canEdit,
            canDelete: state.isOwnStore || state.product.canDelete,
          );
          final likedIds = Set<String>.from(state.likedPhotoIds);
          if (catalogProduct.liked == true) {
            likedIds.add('product:${merged.id}');
            final primaryAsset = merged.photoAssetIds.isNotEmpty
                ? merged.photoAssetIds.first.trim()
                : '';
            if (primaryAsset.isNotEmpty) likedIds.add(primaryAsset);
          }
          // Prefer server wishlisted; else warm wishlist cache.
          final fromServer = catalogProduct.wishlisted;
          final fromCache =
              fromServer == null
                  ? WishlistPrefetcher.instance.containsTargetId(merged.id)
                  : false;
          final wishlisted =
              fromServer ?? (fromCache || state.isWishlisted);
          if (fromServer != null) {
            BeVerify.ok(
              'details hydrate from product GET',
              detail:
                  '${BeVerify.flag('liked', catalogProduct.liked)} '
                  '${BeVerify.flag('wishlisted', fromServer)} '
                  'like=${catalogProduct.liked == true} '
                  'wishlist=$wishlisted',
            );
          } else {
            BeVerify.fail(
              'wishlisted omitted — using cache fallback',
              detail:
                  'cacheHit=$fromCache wishlist=$wishlisted '
                  '${BeVerify.flag('liked', catalogProduct.liked)}',
            );
          }
          final productSpec = ProductSpec.fromCatalogProductMap(
            catalogProduct.toFlatSpecMap(),
          );
          final wishIds = Set<String>.from(state.wishlistedProductIds);
          if (wishlisted && merged.id.trim().isNotEmpty) {
            wishIds.add(merged.id.trim());
          }
          emit(
            state.copyWith(
              product: merged,
              specifications: productSpec,
              productSpecsById: {
                if (merged.id.trim().isNotEmpty) merged.id.trim(): productSpec,
                for (final id in merged.photoAssetIds)
                  if (id.trim().isNotEmpty) id.trim(): productSpec,
              },
              precisionTag:
                  fromProduct.precisionTag.isNotEmpty
                      ? fromProduct.precisionTag
                      : state.precisionTag,
              likedPhotoIds: likedIds,
              isLoadingPhotos: false,
              canEdit: merged.canEdit,
              canDelete: merged.canDelete,
              usesProductLike: true,
              isWishlisted: wishlisted,
              wishlistedProductIds: wishIds,
              isContentLocked: false,
            ),
          );
          return;
        }
      } on CatalogApiException catch (e) {
        if (e.code == 'LOCKED_PRODUCT') {
          if (emit.isDone) return;
          emit(
            state.copyWith(
              isLoadingPhotos: false,
              isContentLocked: true,
              clearInfoMessage: true,
            ),
          );
          return;
        }
        // Not a product id / endpoint miss — fall through to collection.
        BeVerify.info(
          'product GET → collection fallback',
          detail:
              'listing=${BeVerify.shortId(requestedListingId)} '
              'code=${e.code}',
        );
      } catch (_) {
        // Not a product id / endpoint miss — fall through to collection.
        BeVerify.info(
          'product GET → collection fallback',
          detail: 'listing=${BeVerify.shortId(requestedListingId)} non-api',
        );
      }

      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId!,
        listingId: requestedListingId,
      );
      if (emit.isDone) return;
      // User may have swiped to another product while this request was in flight.
      if (state.product.id != requestedListingId) {
        emit(state.copyWith(isLoadingPhotos: false));
        return;
      }
      // Server detail (incl. products[]-derived lock/stock) wins over a stale
      // store-profile seed — seed only fills gaps the detail omits.
      final fromDetail = CatalogUiMapper.detailToProduct(detail);
      final updated = fromDetail.copyWith(
        isLocked: detail.isLocked || state.product.isLocked,
        stockStatus: detail.stockStatus ?? state.product.stockStatus,
        mtoDays: detail.mtoDays ?? state.product.mtoDays,
        importFlags:
            fromDetail.importFlags.importStatus != null
                ? fromDetail.importFlags
                : state.product.importFlags,
        imageImportStatuses:
            fromDetail.imageImportStatuses.isNotEmpty
                ? fromDetail.imageImportStatuses
                : (state.product.imageImportStatuses.isNotEmpty
                    ? state.product.imageImportStatuses
                    : null),
      );
      final perms = detail.permissions;
      final canEdit = _resolveCanEdit(
        explicit: perms?.edit ?? updated.canEdit,
        isOwnStore: state.isOwnStore,
        kind: detail.kind ?? _kindFromProduct(updated),
      );
      final canDelete =
          (perms?.delete ?? updated.canDelete) || state.isOwnStore;
      final remapped = _resolveGalleryFeed(
        feed: state.galleryFeed,
        feedIndex: state.galleryFeedIndex,
        updated: updated,
      );
      // Prefer the photo the user opened with (wishlist / collage index), not
      // always slot 0 after detail expands from a single seeded image.
      final resolvedImageIndex =
          remapped.feed != null &&
                  remapped.feed!.isNotEmpty &&
                  remapped.feedIndex >= 0 &&
                  remapped.feedIndex < remapped.feed!.length
              ? remapped.feed![remapped.feedIndex].imageIndex
              : _resolvePreferredImageIndex(
                previous: state.product,
                updated: updated,
                previousIndex: state.initialImageIndex,
                preferredPhotoIds: state.likedPhotoIds,
              );
      AppLog.d(
        _tag,
        'Loaded collection detail photos=${updated.imagePaths.length} '
        'feed=${remapped.feed?.length ?? 0} feedIndex=${remapped.feedIndex} '
        'imageIndex=$resolvedImageIndex '
        'edit=${perms?.edit} delete=${perms?.delete}',
      );
      final nullHashes =
          updated.imageThumbhashes.where((h) => h.trim().isEmpty).length;
      BeVerify.step(
        'PD collection detail',
        detail:
            'id=${BeVerify.shortId(updated.id)} '
            'photos=${updated.imagePaths.length} '
            'locked=${updated.isLocked} '
            'stock=${updated.stockStatus?.apiValue} '
            'thumbhashNULL=$nullHashes '
            'embeddedSpecs=${detail.productSpecsById.length}',
      );
      if (nullHashes == 0 && updated.imagePaths.isNotEmpty) {
        BeVerify.ok('collection detail thumbhash', detail: 'NULL=0');
      } else if (nullHashes > 0) {
        BeVerify.fail(
          'collection detail thumbhash',
          detail: 'NULL=$nullHashes GAP_THUMBHASH_NULL',
        );
      }
      CatalogMediaDebug.render(
        'product_details loaded listing=${updated.id} '
        'photos=${updated.imagePaths.length} thumbhashNULL=$nullHashes '
        'feed=${remapped.feed?.length ?? 0} feedIndex=${remapped.feedIndex} '
        'imageIndex=$resolvedImageIndex',
      );
      if (nullHashes > 0) {
        CatalogMediaDebug.gap(
          'product_details detail has empty thumbhash slots=$nullHashes '
          'listing=${updated.id}',
        );
      }
      final likedFromDetail = CatalogUiMapper.likedPhotoIdsFromDetail(detail);
      final likedKeys = <String>{
        ...likedFromDetail,
        for (final id in likedFromDetail)
          if (id.isNotEmpty && !id.startsWith('img_')) 'product:$id',
      };
      final likeCounts = CatalogUiMapper.photoLikeCountsFromDetail(detail);
      final viewCounts = CatalogUiMapper.photoViewCountsFromDetail(detail);
      final fromNested = ProductSpec.fromApiJson(
        detail.specifications?.toJson(),
      );
      final specsById = detail.productSpecsById;
      final groupSpec =
          _chromeableSpec(fromNested) ??
          detail.defaultsSpec ??
          _firstChromeableSpec(specsById.values) ??
          fromNested;
      emit(
        state.copyWith(
          product: updated,
          isLoadingPhotos: false,
          initialImageIndex: _clampIndex(resolvedImageIndex, updated),
          galleryFeed: remapped.feed,
          galleryFeedIndex: remapped.feedIndex,
          revision: detail.revision,
          apiTag: detail.tag,
          specifications: groupSpec,
          productSpecsById: specsById,
          precisionTag: detail.precisionTag,
          subGroups: detail.subGroups,
          canEdit: canEdit,
          canDelete: canDelete,
          likedPhotoIds: {...state.likedPhotoIds, ...likedKeys},
          photoLikeCounts: {...state.photoLikeCounts, ...likeCounts},
          photoViewCounts: {...state.photoViewCounts, ...viewCounts},
        ),
      );
    } catch (e) {
      // Keep cover/local images already on the product; do not block the screen.
      AppLog.e(_tag, 'Collection detail load failed', e);
      if (emit.isDone) return;
      if (state.product.id != requestedListingId) {
        emit(state.copyWith(isLoadingPhotos: false));
        return;
      }
      emit(
        state.copyWith(
          isLoadingPhotos: false,
          canEdit: _resolveCanEdit(
            explicit: state.canEdit,
            isOwnStore: state.isOwnStore,
            kind: _kindFromProduct(state.product),
          ),
          canDelete: state.canDelete || state.isOwnStore,
        ),
      );
    }
  }

  Future<void> _onActivateProduct(
    ProductDetailsActivateProduct event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (event.product.id == state.product.id) return;
    final nextStoreId =
        (event.storeId != null && event.storeId!.trim().isNotEmpty)
            ? event.storeId!.trim()
            : state.storeId;
    emit(
      state.copyWith(
        product: event.product,
        storeId: nextStoreId,
        storeName:
            (event.storeName != null && event.storeName!.trim().isNotEmpty)
                ? event.storeName!.trim()
                : state.storeName,
        storeLink:
            (event.storeLink != null && event.storeLink!.trim().isNotEmpty)
                ? event.storeLink!.trim()
                : state.storeLink,
        isLoadingPhotos: _canFetchPhotos(nextStoreId, event.product),
        apiTag: '',
        clearSpecifications: true,
        precisionTag: '',
        subGroups: const [],
        seedCategory: event.seedCategory?.trim() ?? '',
        canEdit: _resolveCanEdit(
          explicit: event.product.canEdit,
          isOwnStore: state.isOwnStore,
          kind: _kindFromProduct(event.product),
        ),
        canDelete: event.product.canDelete || state.isOwnStore,
        clearShouldOpenEdit: true,
        clearInfoMessage: true,
      ),
    );
    if (_canFetchPhotos(nextStoreId, event.product)) {
      add(const ProductDetailsLoadPhotos());
    }
  }

  Future<void> _onSharePressed(
    ProductDetailsSharePressed event,
    Emitter<ProductDetailsState> emit,
  ) async {
    final path = event.imagePath.trim();
    if (path.isEmpty || !ProductImagePaths.isDisplayable(path)) {
      emit(
        state.copyWith(
          infoMessage: 'Unable to share this photo right now.',
        ),
      );
      return;
    }
    final file = await ProductImagePaths.resolveLocalFile(path);
    if (file == null) {
      emit(
        state.copyWith(
          infoMessage: 'Unable to share this photo right now.',
        ),
      );
      return;
    }
    final ok = await WhatsAppInvite.shareImageFile(file.path);
    if (!ok) {
      emit(
        state.copyWith(
          infoMessage: 'Unable to share this photo right now.',
        ),
      );
    }
  }

  void _onEditPressed(
    ProductDetailsEditPressed event,
    Emitter<ProductDetailsState> emit,
  ) {
    if (!state.canEdit) {
      emit(
        state.copyWith(
          infoMessage: 'You do not have permission to edit this product.',
        ),
      );
      return;
    }
    final storeId = state.storeId;
    if (storeId == null ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      emit(state.copyWith(infoMessage: 'Unable to edit this product right now.'));
      return;
    }
    emit(state.copyWith(shouldOpenEdit: true));
  }

  Future<void> _onDeletePressed(
    ProductDetailsDeletePressed event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state.isDeleting) return;
    if (!state.canEdit) {
      emit(
        state.copyWith(
          infoMessage: 'You do not have permission to remove this photo.',
        ),
      );
      return;
    }
    final storeId = state.storeId;
    if (storeId == null ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      emit(
        state.copyWith(infoMessage: 'Unable to remove this photo right now.'),
      );
      return;
    }

    final paths = state.product.imagePaths;
    if (paths.length <= 1) {
      await _deleteProduct(emit);
      return;
    }

    final index = event.imageIndex;
    if (index < 0 || index >= paths.length) {
      emit(state.copyWith(infoMessage: 'This photo is no longer available.'));
      return;
    }

    var photoId =
        index < state.product.photoAssetIds.length
            ? state.product.photoAssetIds[index].trim()
            : '';
    var revision = state.revision;

    if (photoId.isEmpty) {
      try {
        final detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: state.product.id,
        );
        revision = detail.revision;
        if (index < detail.photos.length) {
          photoId = detail.photos[index].id?.trim() ?? '';
        }
      } catch (e) {
        AppLog.e(_tag, 'Unable to resolve photo id', e);
      }
    }

    if (photoId.isEmpty) {
      emit(
        state.copyWith(
          infoMessage: 'Unable to remove this photo right now.',
        ),
      );
      return;
    }

    emit(state.copyWith(isDeleting: true));
    try {
      final deleted = await _collectionRepository.deletePhotos(
        storeId: storeId,
        listingId: state.product.id,
        photoIds: [photoId],
        revision: revision,
      );
      CollectionDetail detail;
      try {
        detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: state.product.id,
        );
      } catch (_) {
        final nextPaths = List<String>.from(paths)..removeAt(index);
        final nextIds = List<String>.from(state.product.photoAssetIds);
        if (index < nextIds.length) nextIds.removeAt(index);
        emit(
          state.copyWith(
            isDeleting: false,
            product: state.product.copyWith(
              imagePaths: nextPaths,
              photoAssetIds: nextIds,
            ),
            revision: deleted.revision,
            initialImageIndex: _clampIndex(
              index > 0 ? index - 1 : 0,
              state.product.copyWith(imagePaths: nextPaths),
            ),
            infoMessage: 'Photo removed.',
          ),
        );
        return;
      }

      final updated = CatalogUiMapper.detailToProduct(detail);
      AppLog.d(_tag, 'Removed photo $photoId from ${state.product.id}');
      emit(
        state.copyWith(
          isDeleting: false,
          product: updated,
          revision: detail.revision,
          apiTag: detail.tag,
          canEdit: detail.permissions?.edit ?? state.canEdit,
          canDelete: detail.permissions?.delete ?? state.canDelete,
          initialImageIndex: _clampIndex(index > 0 ? index - 1 : 0, updated),
          infoMessage: 'Photo removed.',
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Delete photo failed', e);
      emit(
        state.copyWith(
          isDeleting: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Emitter<ProductDetailsState> emit) async {
    final storeId = state.storeId;
    if (storeId == null ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      emit(
        state.copyWith(infoMessage: 'Unable to delete this product right now.'),
      );
      return;
    }

    emit(state.copyWith(isDeleting: true));
    final productId = state.product.id.trim();
    try {
      // Jewel first-class product delete; fall back to legacy collection delete.
      try {
        await _collectionRepository.deleteProduct(productId: productId);
        AppLog.d(_tag, 'Deleted product $productId');
      } on CatalogApiException catch (e) {
        final missingProduct =
            e.statusCode == 404 ||
            e.code == 'PRODUCT_NOT_FOUND' ||
            e.code == 'NOT_FOUND';
        if (!missingProduct) rethrow;
        await _collectionRepository.deleteCollection(
          storeId: storeId,
          listingId: productId,
        );
        AppLog.d(_tag, 'Deleted collection $productId (product 404 fallback)');
      }
      emit(state.copyWith(isDeleting: false, isDeleted: true));
    } catch (e) {
      AppLog.e(_tag, 'Delete product failed', e);
      final alreadyGone =
          e is CatalogApiException &&
          (e.statusCode == 404 ||
              e.code == 'COLLECTION_NOT_FOUND' ||
              e.code == 'PRODUCT_NOT_FOUND' ||
              e.code == 'NOT_FOUND');
      if (alreadyGone) {
        emit(state.copyWith(isDeleting: false, isDeleted: true));
        return;
      }
      emit(
        state.copyWith(
          isDeleting: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearOpenEdit(
    ProductDetailsClearOpenEdit event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearShouldOpenEdit: true));
  }

  void _onApplyEditedProduct(
    ProductDetailsApplyEditedProduct event,
    Emitter<ProductDetailsState> emit,
  ) {
    final fromNested = event.specifications;
    final specsById = event.productSpecsById;
    final groupSpec =
        _chromeableSpec(fromNested) ??
        (specsById != null ? _firstChromeableSpec(specsById.values) : null) ??
        fromNested ??
        state.specifications;
    emit(
      state.copyWith(
        product: event.product.copyWith(
          canEdit: event.product.canEdit || state.canEdit,
          canDelete: event.product.canDelete || state.canDelete,
        ),
        canEdit: event.product.canEdit || state.canEdit,
        canDelete: event.product.canDelete || state.canDelete,
        revision: event.revision,
        apiTag: event.apiTag,
        specifications: groupSpec,
        productSpecsById: specsById ?? state.productSpecsById,
        precisionTag: event.precisionTag ?? state.precisionTag,
        subGroups: event.subGroups ?? state.subGroups,
        initialImageIndex: _clampIndex(state.initialImageIndex, event.product),
        infoMessage: 'Product updated.',
      ),
    );
  }

  void _onClearDeleted(
    ProductDetailsClearDeleted event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearDeleted: true));
  }

  void _onMorePressed(
    ProductDetailsMorePressed event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'More actions coming soon.'));
  }

  void _onClearMessage(
    ProductDetailsClearMessage event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearInfoMessage: true));
  }

  Future<void> _onLikePressed(
    ProductDetailsLikePressed event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state.isLikeBusy) return;
    final listingId = state.product.id.trim();
    if (listingId.isEmpty) {
      emit(
        state.copyWith(infoMessage: 'Unable to like this item right now.'),
      );
      return;
    }

    // Jewel: like the CatalogProduct for this photo (embedded id), never the
    // collection listing id when products[] are present.
    final targetId = state.catalogProductIdForPhoto(event.imageIndex);
    if (targetId.isNotEmpty &&
        (state.usesProductLike ||
            state.hasEmbeddedProducts ||
            state.product.collectionId.trim().isNotEmpty ||
            state.product.stockStatus != null ||
            !targetId.startsWith('img_'))) {
      await _toggleProductLike(
        emit,
        productId: targetId,
        imageIndex: event.imageIndex,
      );
      return;
    }

    final resolved = await _resolvePhotoIdForLike(
      emit,
      imageIndex: event.imageIndex,
    );
    if (emit.isDone) return;
    final photoId = resolved.photoId;
    if (photoId.isEmpty) {
      await _toggleProductLike(
        emit,
        productId: targetId.isNotEmpty ? targetId : listingId,
        imageIndex: event.imageIndex,
      );
      return;
    }

    final currentlyLiked = state.likedPhotoIds.contains(photoId);
    final storeId = state.storeId;
    emit(state.copyWith(isLikeBusy: true, clearInfoMessage: true));
    try {
      if (currentlyLiked) {
        final result = await _wishlistRepository.unlikePhoto(
          listingId: listingId,
          photoId: photoId,
          storeId: storeId,
        );
        if (emit.isDone) return;
        final removedId =
            result.assetId.trim().isNotEmpty ? result.assetId.trim() : photoId;
        final next = Set<String>.from(state.likedPhotoIds)..remove(removedId);
        final nextCounts = Map<String, int>.from(state.photoLikeCounts);
        final prev = nextCounts[removedId] ?? 1;
        nextCounts[removedId] = prev > 0 ? prev - 1 : 0;
        emit(
          state.copyWith(
            likedPhotoIds: next,
            photoLikeCounts: nextCounts,
            isLikeBusy: false,
            clearWishlistSnack: true,
          ),
        );
      } else {
        final result = await _wishlistRepository.likePhoto(
          listingId: listingId,
          photoId: photoId,
          storeId: storeId,
        );
        if (emit.isDone) return;
        final addedId =
            result.assetId.trim().isNotEmpty ? result.assetId.trim() : photoId;
        final next = Set<String>.from(state.likedPhotoIds)..add(addedId);
        final nextCounts = Map<String, int>.from(state.photoLikeCounts);
        nextCounts[addedId] = (nextCounts[addedId] ?? 0) + 1;
        emit(
          state.copyWith(
            likedPhotoIds: next,
            photoLikeCounts: nextCounts,
            isLikeBusy: false,
            clearWishlistSnack: true,
          ),
        );
      }
    } on CatalogApiException catch (e) {
      AppLog.e(_tag, 'Like toggle failed', e);
      if (emit.isDone) return;
      if (e.code == 'PHOTO_NOT_FOUND') {
        emit(
          state.copyWith(
            isLikeBusy: false,
            infoMessage: CatalogErrorMapper.toUserMessage(e),
          ),
        );
        add(const ProductDetailsLoadPhotos());
        return;
      }
      emit(
        state.copyWith(
          isLikeBusy: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Like toggle failed', e);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isLikeBusy: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _toggleProductLike(
    Emitter<ProductDetailsState> emit, {
    required String productId,
    int? imageIndex,
  }) async {
    final id = productId.trim();
    if (id.isEmpty) return;
    final likeKey = 'product:$id';
    final currentlyLiked =
        state.likedPhotoIds.contains(likeKey) ||
        (imageIndex != null && state.isPhotoLiked(imageIndex));
    BeVerify.step(
      'L like product',
      detail:
          'id=${BeVerify.shortId(id)} '
          'listing=${BeVerify.shortId(state.product.id)} '
          'photo=${imageIndex ?? '-'} '
          '→ ${currentlyLiked ? 'unlike' : 'like'}',
    );
    emit(state.copyWith(isLikeBusy: true, clearInfoMessage: true));
    try {
      final result =
          currentlyLiked
              ? await _wishlistRepository.unlikeProduct(productId: id)
              : await _wishlistRepository.likeProduct(productId: id);
      if (emit.isDone) return;
      final next = Set<String>.from(state.likedPhotoIds);
      if (result.liked) {
        next.add(likeKey);
        final photoId =
            imageIndex != null ? state.photoIdAt(imageIndex) : '';
        if (photoId.isNotEmpty) next.add(photoId);
      } else {
        next.remove(likeKey);
        final photoId =
            imageIndex != null ? state.photoIdAt(imageIndex) : '';
        if (photoId.isNotEmpty) next.remove(photoId);
      }
      final prevCount =
          (imageIndex != null
              ? state.likeCountForPhoto(imageIndex)
              : null) ??
          state.photoLikeCounts[id] ??
          state.product.likeCount ??
          0;
      final nextCount =
          result.likeCount ??
          (result.liked
              ? prevCount + 1
              : (prevCount > 0 ? prevCount - 1 : 0));
      final nextCounts = Map<String, int>.from(state.photoLikeCounts)
        ..[id] = nextCount;
      final photoId = imageIndex != null ? state.photoIdAt(imageIndex) : '';
      if (photoId.isNotEmpty) nextCounts[photoId] = nextCount;

      // Card badge = sum of per-slot product likes (embedded photos) so the
      // store grid can show a count after liking one photo in a collection.
      final listingIsTarget = id == state.product.id.trim();
      final listingLikeCount = _listingLikeCountFromPhotoCounts(
        product: state.product,
        photoLikeCounts: nextCounts,
        fallback: nextCount,
      );
      BeVerify.ok(
        'like toggle',
        detail:
            'id=${BeVerify.shortId(id)} liked=${result.liked} '
            'count=$nextCount listingLike=$listingLikeCount '
            'listingScope=$listingIsTarget',
      );
      emit(
        state.copyWith(
          product: state.product.copyWith(likeCount: listingLikeCount),
          likedPhotoIds: next,
          photoLikeCounts: nextCounts,
          isLikeBusy: false,
          usesProductLike: listingIsTarget || state.usesProductLike,
          clearWishlistSnack: true,
        ),
      );
    } on CatalogApiException catch (e) {
      BeVerify.fail(
        'like toggle',
        detail: 'id=${BeVerify.shortId(id)} code=${e.code} ${e.message}',
      );
      AppLog.e(_tag, 'Product like toggle failed', e);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isLikeBusy: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    } catch (e) {
      BeVerify.fail('like toggle', detail: 'id=${BeVerify.shortId(id)} $e');
      AppLog.e(_tag, 'Product like toggle failed', e);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isLikeBusy: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// Store-card badge: sum like counts for each collage slot (deduped).
  static int _listingLikeCountFromPhotoCounts({
    required StoreProduct product,
    required Map<String, int> photoLikeCounts,
    required int fallback,
  }) {
    final slots = product.photoAssetIds;
    if (slots.isEmpty) return fallback;
    final seen = <String>{};
    var sum = 0;
    var any = false;
    for (final raw in slots) {
      final slot = raw.trim();
      if (slot.isEmpty || !seen.add(slot)) continue;
      final c = photoLikeCounts[slot];
      if (c == null) continue;
      any = true;
      sum += c;
    }
    return any ? sum : fallback;
  }

  Future<void> _onWishlistPressed(
    ProductDetailsWishlistPressed event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state.isWishlistBusy) return;
    final productId = state.catalogProductIdForPhoto(event.imageIndex);
    if (productId.isEmpty) {
      emit(
        state.copyWith(infoMessage: 'Unable to update wishlist right now.'),
      );
      return;
    }
    final currently = state.isPhotoWishlisted(event.imageIndex);
    BeVerify.step(
      'L wishlist product',
      detail:
          'id=${BeVerify.shortId(productId)} '
          'listing=${BeVerify.shortId(state.product.id)} '
          'photo=${event.imageIndex} '
          '→ ${currently ? 'remove' : 'add'}',
    );
    emit(state.copyWith(isWishlistBusy: true, clearInfoMessage: true));
    try {
      final result =
          currently
              ? await _wishlistRepository.removeWishlistProduct(
                productId: productId,
              )
              : await _wishlistRepository.addWishlistProduct(
                productId: productId,
              );
      if (emit.isDone) return;
      final nextWish = Set<String>.from(state.wishlistedProductIds);
      if (result.wishlisted) {
        nextWish.add(productId);
      } else {
        nextWish.remove(productId);
      }
      BeVerify.ok(
        'wishlist toggle',
        detail:
            'id=${BeVerify.shortId(productId)} '
            'wishlisted=${result.wishlisted}',
      );
      emit(
        state.copyWith(
          isWishlisted:
              productId == state.product.id.trim()
                  ? result.wishlisted
                  : state.isWishlisted,
          wishlistedProductIds: nextWish,
          isWishlistBusy: false,
          clearWishlistSnack: true,
        ),
      );
    } on CatalogApiException catch (e) {
      BeVerify.fail(
        'wishlist toggle',
        detail:
            'id=${BeVerify.shortId(productId)} code=${e.code} ${e.message}',
      );
      AppLog.e(_tag, 'Wishlist toggle failed', e);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isWishlistBusy: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    } catch (e) {
      BeVerify.fail(
        'wishlist toggle',
        detail: 'id=${BeVerify.shortId(productId)} $e',
      );
      AppLog.e(_tag, 'Wishlist toggle failed', e);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          isWishlistBusy: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// Ensures [photoAssetIds] are populated from collection detail when missing.
  Future<({String photoId, StoreProduct? product})> _resolvePhotoIdForLike(
    Emitter<ProductDetailsState> emit, {
    required int imageIndex,
  }) async {
    var photoId = state.photoIdAt(imageIndex);
    if (photoId.isNotEmpty) {
      return (photoId: photoId, product: null);
    }

    final storeId = state.storeId;
    if (!_canFetchPhotos(storeId, state.product)) {
      return (photoId: '', product: null);
    }

    emit(state.copyWith(isLikeBusy: true));
    try {
      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId!,
        listingId: state.product.id,
      );
      if (emit.isDone) return (photoId: '', product: null);
      final updated = CatalogUiMapper.detailToProduct(detail);
      photoId = CatalogUiMapper.photoIdAtIndex(
        detail,
        updated,
        imageIndex: imageIndex,
      );
      final likedFromDetail = CatalogUiMapper.likedPhotoIdsFromDetail(detail);
      final likedKeys = <String>{
        ...likedFromDetail,
        for (final id in likedFromDetail)
          if (id.isNotEmpty && !id.startsWith('img_')) 'product:$id',
      };
      final likeCounts = CatalogUiMapper.photoLikeCountsFromDetail(detail);
      final viewCounts = CatalogUiMapper.photoViewCountsFromDetail(detail);
      emit(
        state.copyWith(
          product: updated,
          likedPhotoIds: {...state.likedPhotoIds, ...likedKeys},
          photoLikeCounts: {...state.photoLikeCounts, ...likeCounts},
          photoViewCounts: {...state.photoViewCounts, ...viewCounts},
          revision: detail.revision,
          subGroups: detail.subGroups,
          productSpecsById: detail.productSpecsById,
          isLoadingPhotos: false,
        ),
      );
      return (photoId: photoId, product: updated);
    } catch (e) {
      AppLog.e(_tag, 'Resolve photo id for like failed', e);
      if (!emit.isDone) {
        emit(state.copyWith(isLikeBusy: false));
      }
      return (photoId: '', product: null);
    }
  }

  void _onClearWishlistSnack(
    ProductDetailsClearWishlistSnack event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearWishlistSnack: true));
  }

  /// Spec that can drive details chrome (weight and/or purity/size lines).
  static ProductSpec? _chromeableSpec(ProductSpec? spec) {
    if (spec == null) return null;
    if (spec.primaryWeightDisplay != null) return spec;
    if (spec.weightDetailLines.isNotEmpty) return spec;
    return null;
  }

  static ProductSpec? _firstChromeableSpec(Iterable<ProductSpec> specs) {
    for (final spec in specs) {
      final hit = _chromeableSpec(spec);
      if (hit != null) return hit;
    }
    return null;
  }
}
