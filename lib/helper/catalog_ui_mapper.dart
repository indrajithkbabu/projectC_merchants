import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/models/store_product.dart';

/// Maps catalog DTOs into existing UI models without rewriting every screen.
class CatalogUiMapper {
  CatalogUiMapper._();

  static StoreChannel storeToChannel(
    CatalogStore store, {
    List<StoreProduct> products = const [],
    int avatarColor = 0xFF2AABEE,
  }) {
    final urls = store.showcaseImageUrls;
    final follow = storeFollowStatusFromString(store.followStatusRaw);
    // Owner/member rows use followStatus "self" — keep that even if raw omitted.
    final resolvedFollow =
        store.relationship == StoreRelationship.owner ||
                store.relationship == StoreRelationship.member
            ? (follow == StoreFollowStatus.none
                ? StoreFollowStatus.self
                : follow)
            : follow;
    return StoreChannel(
      id: store.id,
      name: store.name,
      handle: store.slug,
      avatarColor: avatarColor,
      products: products,
      isOwn: store.isOwn,
      relationship: store.relationship,
      followStatus: resolvedFollow,
      coverImageUrl: store.coverImageUrl,
      imageUrls: urls,
      phone: store.phone,
    );
  }

  static StoreProduct summaryToProduct(CollectionSummary summary) {
    final coverId = summary.cover.id?.trim() ?? '';
    final coverHash = summary.cover.thumbhash?.trim() ?? '';
    final coverQuality = summary.cover.quality?.trim() ?? '';
    final coverThumb = summary.cover.thumbnailUrl.trim();
    final coverDetail = summary.cover.detailUrl.trim();
    return StoreProduct(
      id: summary.id,
      title: summary.name,
      description: summary.description,
      tags: [
        if (summary.tag.isNotEmpty) summary.tag,
        if (summary.kind != null) summary.kind!,
        if (summary.photoCount > 0) '${summary.photoCount} pieces',
      ],
      imagePaths:
          summary.cover.url.isEmpty ? const [] : [summary.cover.url],
      photoAssetIds: coverId.isEmpty ? const [] : [coverId],
      imageThumbhashes: coverHash.isEmpty ? const [] : [coverHash],
      imageThumbnailUrls: coverThumb.isEmpty ? const [] : [coverThumb],
      imageDetailUrls: coverDetail.isEmpty ? const [] : [coverDetail],
      imageQualities: coverQuality.isEmpty ? const [] : [coverQuality],
      canEdit: summary.permissions?.edit ?? false,
      canDelete: summary.permissions?.delete ?? false,
      toneIndex: summary.id.hashCode.abs() % 4,
      viewCount: summary.viewCount,
      likeCount: summary.likeCount ?? summary.cover.likeCount,
      isLocked: summary.isLocked,
      stockStatus: summary.stockStatus,
      mtoDays: summary.mtoDays,
      precisionTag: summary.precisionTag,
      importFlags: summary.importFlags,
      // Prefer listing `createdAt` (IST/UTC); else cover upload time; else ObjectId.
      createdAt: resolveCollectionCreatedAt(
        createdAt: summary.createdAt,
        fallbackCreatedAt: summary.cover.createdAt,
        id: summary.id,
      ),
    );
  }

  /// Maps jewel-flow product DTO → store grid / details card.
  static StoreProduct catalogProductToStoreProduct(CatalogProduct product) {
    final urls =
        product.imageUrls.isNotEmpty
            ? product.imageUrls
            : (product.primaryImageUrl.isEmpty
                ? const <String>[]
                : [product.primaryImageUrl]);
    final thumbs =
        product.imageThumbnailUrls.isNotEmpty
            ? product.imageThumbnailUrls
            : (product.primaryImageThumbnailUrl.isEmpty
                ? List<String>.filled(urls.length, '')
                : [product.primaryImageThumbnailUrl]);
    final details =
        product.imageDetailUrls.isNotEmpty
            ? product.imageDetailUrls
            : (product.primaryImageDetailUrl.isEmpty
                ? List<String>.filled(urls.length, '')
                : [product.primaryImageDetailUrl]);
    final ids =
        product.imageIds.isNotEmpty
            ? product.imageIds
            : (product.primaryImageId.isEmpty
                ? const <String>[]
                : [product.primaryImageId]);
    final hashes =
        product.imageThumbhashes.isNotEmpty
            ? product.imageThumbhashes
            : (product.primaryImageThumbhash.isEmpty
                ? const <String>[]
                : [product.primaryImageThumbhash]);
    // Pad parallel lists so indexes stay aligned with masters.
    final thumbAligned = [
      for (var i = 0; i < urls.length; i++)
        i < thumbs.length ? thumbs[i] : '',
    ];
    final detailAligned = [
      for (var i = 0; i < urls.length; i++)
        i < details.length ? details[i] : '',
    ];
    return StoreProduct(
      id: product.id,
      title: product.title.isNotEmpty ? product.title : 'Item',
      description: '',
      tags: [
        ...product.tags,
        if (product.category.isNotEmpty) product.category,
        if (product.metal.isNotEmpty) product.metal,
      ],
      imagePaths: urls,
      photoAssetIds: ids,
      imageThumbhashes: hashes,
      imageThumbnailUrls: thumbAligned,
      imageDetailUrls: detailAligned,
      canEdit: true,
      canDelete: true,
      toneIndex: product.id.hashCode.abs() % 4,
      viewCount: product.viewCount,
      likeCount: product.likeCount,
      wishlistCount: product.wishlisted == true ? 1 : null,
      isLocked: product.isLocked,
      stockStatus: product.stockStatus,
      mtoDays: product.mtoDays,
      precisionTag: product.precisionTag,
      collectionId: product.collectionId,
      importFlags: product.importFlags,
      createdAt: resolveCollectionCreatedAt(
        createdAt: product.createdAt,
        id: product.id,
      ),
    );
  }

  /// Browse tile photo from a jewel-flow product (id = product id for details).
  static CatalogPhoto catalogProductToPhoto(CatalogProduct product) {
    return CatalogPhoto(
      id: product.id,
      width: 0,
      height: 0,
      url: product.primaryImageUrl,
      thumbnailUrl: product.primaryImageThumbnailUrl,
      detailUrl: product.primaryImageDetailUrl,
      thumbhash:
          product.primaryImageThumbhash.isNotEmpty
              ? product.primaryImageThumbhash
              : (product.imageThumbhashes.isNotEmpty
                  ? product.imageThumbhashes.first
                  : null),
      liked: product.liked,
      likeCount: product.likeCount,
      viewCount: product.viewCount,
      createdAt: product.createdAt,
    );
  }

  /// Ordered CatalogProduct ids for collage cells (cover-first, same as card).
  ///
  /// Prefers each product’s `_id` so like/wishlist can target pieces, not
  /// `img_*` / collection listing ids.
  static List<String> orderedCollageProductIds({
    required List<CatalogProduct> products,
    String coverUrl = '',
  }) {
    final urls = <String>[];
    final ids = <String>[];
    for (final p in products) {
      final url =
          p.primaryImageUrl.trim().isNotEmpty
              ? p.primaryImageUrl.trim()
              : (p.imageUrls.isNotEmpty ? p.imageUrls.first.trim() : '');
      if (url.isEmpty) continue;
      urls.add(url);
      final productId = p.id.trim();
      final imageId =
          p.primaryImageId.trim().isNotEmpty
              ? p.primaryImageId.trim()
              : (p.imageIds.isNotEmpty ? p.imageIds.first.trim() : '');
      ids.add(productId.isNotEmpty ? productId : imageId);
    }
    if (urls.isEmpty) return const [];
    final cover = coverUrl.trim();
    if (cover.isEmpty) return ids;
    final coverIndex = urls.indexWhere((u) => u == cover);
    if (coverIndex <= 0) return ids;
    return [
      ids[coverIndex],
      ...ids.sublist(0, coverIndex),
      ...ids.sublist(coverIndex + 1),
    ];
  }

  /// Collection card collage from products inside a collection (keeps listing id).
  static StoreProduct collectionCardFromProducts({
    required CollectionSummary summary,
    required List<CatalogProduct> products,
  }) {
    final cover = summaryToProduct(summary);
    if (products.isEmpty) return cover;
    final urls = <String>[];
    final thumbs = <String>[];
    final details = <String>[];
    final ids = <String>[];
    final hashes = <String>[];
    final locks = <bool>[];
    final stocks = <String>[];
    final importStatuses = <String>[];
    for (final p in products) {
      // Flatten every album frame (not only primary) so My store / Gallery /
      // Group collage can show the full set from the same enrich payload.
      final albumUrls = <String>[
        for (final u in p.imageUrls)
          if (u.trim().isNotEmpty) u.trim(),
      ];
      if (albumUrls.isEmpty) {
        final primary = p.primaryImageUrl.trim();
        if (primary.isNotEmpty) albumUrls.add(primary);
      }
      final productId = p.id.trim();
      final lock = p.isLocked;
      final stock = p.stockStatus?.apiValue ?? '';
      final importStatus = p.importFlags.importStatus?.trim() ?? '';
      for (var i = 0; i < albumUrls.length; i++) {
        final url = albumUrls[i];
        urls.add(url);
        thumbs.add(
          i < p.imageThumbnailUrls.length &&
                  p.imageThumbnailUrls[i].trim().isNotEmpty
              ? p.imageThumbnailUrls[i].trim()
              : (i == 0 && p.primaryImageThumbnailUrl.trim().isNotEmpty
                  ? p.primaryImageThumbnailUrl.trim()
                  : ''),
        );
        details.add(
          i < p.imageDetailUrls.length &&
                  p.imageDetailUrls[i].trim().isNotEmpty
              ? p.imageDetailUrls[i].trim()
              : (i == 0 && p.primaryImageDetailUrl.trim().isNotEmpty
                  ? p.primaryImageDetailUrl.trim()
                  : ''),
        );
        final imageId =
            i < p.imageIds.length && p.imageIds[i].trim().isNotEmpty
                ? p.imageIds[i].trim()
                : (i == 0 && p.primaryImageId.trim().isNotEmpty
                    ? p.primaryImageId.trim()
                    : '');
        // Prefer CatalogProduct._id so cell → like/wishlist/import hits the
        // product (not img_* / collection listing id).
        ids.add(productId.isNotEmpty ? productId : imageId);
        hashes.add(
          i < p.imageThumbhashes.length &&
                  p.imageThumbhashes[i].trim().isNotEmpty
              ? p.imageThumbhashes[i].trim()
              : (i == 0 && p.primaryImageThumbhash.trim().isNotEmpty
                  ? p.primaryImageThumbhash.trim()
                  : ''),
        );
        locks.add(lock);
        stocks.add(stock);
        importStatuses.add(importStatus);
      }
    }
    if (urls.isEmpty) return cover;
    final coverUrl = cover.primaryImagePath?.trim() ?? '';
    var orderedUrls = urls;
    var orderedThumbs = thumbs;
    var orderedDetails = details;
    var orderedIds = ids;
    var orderedHashes = hashes;
    var orderedLocks = locks;
    var orderedStocks = stocks;
    var orderedImportStatuses = importStatuses;
    if (coverUrl.isNotEmpty) {
      final coverIndex = urls.indexWhere((u) => u == coverUrl);
      if (coverIndex > 0) {
        List<T> coverFirst<T>(List<T> list) => [
          list[coverIndex],
          ...list.sublist(0, coverIndex),
          ...list.sublist(coverIndex + 1),
        ];
        orderedUrls = coverFirst(urls);
        orderedThumbs = coverFirst(thumbs);
        orderedDetails = coverFirst(details);
        orderedIds = coverFirst(ids);
        orderedHashes = coverFirst(hashes);
        orderedLocks = coverFirst(locks);
        orderedStocks = coverFirst(stocks);
        orderedImportStatuses = coverFirst(importStatuses);
      }
    }
    // Collection list often keeps likeCount=0 while products[] already have
    // likes — badge uses the larger of listing vs sum of embedded products.
    final fromProducts = _sumCatalogProductCounts(products);
    final wishlistFromProducts = _wishlistCountFromProducts(products);
    return cover.copyWith(
      imagePaths: orderedUrls,
      photoAssetIds: orderedIds,
      imageThumbhashes: orderedHashes,
      imageThumbnailUrls: orderedThumbs,
      imageDetailUrls: orderedDetails,
      imageIsLocked: orderedLocks,
      imageStockStatuses: orderedStocks,
      imageImportStatuses: orderedImportStatuses,
      tags: [
        if (summary.tag.isNotEmpty) summary.tag,
        if (summary.kind != null) summary.kind!,
        if (orderedUrls.isNotEmpty) '${orderedUrls.length} pieces',
      ],
      likeCount: _preferCount(cover.likeCount, fromProducts.likes),
      viewCount: _preferCount(cover.viewCount, fromProducts.views),
      wishlistCount: _preferCount(cover.wishlistCount, wishlistFromProducts),
    );
  }

  /// Instant browse tiles from a Group collage card (no network).
  ///
  /// Uses parallel [StoreProduct] media arrays written by
  /// [collectionCardFromProducts]. One tile per CatalogProduct id (album may
  /// expand to many paths — browse stays jewel one-tile-per-product). Empty
  /// when fewer than two distinct product cells.
  static List<CatalogProduct> seedProductsFromCollectionCard(
    StoreProduct card, {
    required String storeId,
  }) {
    final paths = [
      for (final p in card.imagePaths)
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (paths.length < 2) return const [];
    final collectionId = card.id.trim();
    final out = <CatalogProduct>[];
    final seenProductIds = <String>{};
    for (var i = 0; i < paths.length; i++) {
      final id =
          i < card.photoAssetIds.length ? card.photoAssetIds[i].trim() : '';
      if (id.isEmpty) continue;
      // Full albums repeat product id per frame — seed once (cover-first).
      if (!seenProductIds.add(id)) continue;
      final thumb =
          i < card.imageThumbnailUrls.length
              ? card.imageThumbnailUrls[i].trim()
              : '';
      final detail =
          i < card.imageDetailUrls.length
              ? card.imageDetailUrls[i].trim()
              : '';
      final hash =
          i < card.imageThumbhashes.length
              ? card.imageThumbhashes[i].trim()
              : '';
      out.add(
        CatalogProduct(
          id: id,
          storeId: storeId,
          collectionId: collectionId,
          title: card.title,
          kind: CatalogProductKind.single,
          primaryImageUrl: paths[i],
          primaryImageThumbnailUrl: thumb,
          primaryImageDetailUrl: detail,
          primaryImageThumbhash: hash,
          imageUrls: [paths[i]],
          imageThumbnailUrls: thumb.isEmpty ? const [] : [thumb],
          imageDetailUrls: detail.isEmpty ? const [] : [detail],
          imageThumbhashes: hash.isEmpty ? const [] : [hash],
          isLocked: card.isLockedAt(i),
          stockStatus: card.stockStatusAt(i),
          importFlags: ProductImportFlags(
            importStatus: () {
              final raw =
                  i < card.imageImportStatuses.length
                      ? card.imageImportStatuses[i].trim()
                      : (card.importFlags.importStatus ?? '').trim();
              return raw.isEmpty ? null : raw;
            }(),
          ),
          likeCount: null,
          viewCount: null,
          createdAt: card.createdAt,
        ),
      );
    }
    return out.length >= 2 ? out : const [];
  }

  /// True when [card.photoAssetIds] holds nested CatalogProduct ids (not the
  /// listing id / `img_*` photo keys). Album expand stores product ids per frame.
  static bool collageHasNestedProducts(StoreProduct card) {
    final listingId = card.id.trim();
    if (listingId.isEmpty || card.photoAssetIds.isEmpty) return false;
    for (final raw in card.photoAssetIds) {
      final id = raw.trim();
      if (id.isEmpty || id == listingId) continue;
      if (id.startsWith('img_')) continue;
      return true;
    }
    return false;
  }

  /// Split an enriched collection collage into one [StoreProduct] per nested
  /// jewel (full album frames). Legacy listing cards (no nested product ids)
  /// return `[card]` unchanged.
  static List<StoreProduct> expandCollageToProducts(StoreProduct card) {
    if (!collageHasNestedProducts(card)) return [card];
    final order = <String>[];
    final indexesById = <String, List<int>>{};
    for (var i = 0; i < card.imagePaths.length; i++) {
      final id =
          i < card.photoAssetIds.length ? card.photoAssetIds[i].trim() : '';
      if (id.isEmpty || id == card.id || id.startsWith('img_')) continue;
      final list = indexesById.putIfAbsent(id, () {
        order.add(id);
        return <int>[];
      });
      list.add(i);
    }
    if (order.isEmpty) return [card];
    return [
      for (final id in order) _sliceCollageProduct(card, id, indexesById[id]!),
    ];
  }

  /// Map a collage / gallery tap on [card] to the nested jewel + local album
  /// index (so product-details opens the tapped piece, not another listing).
  static ({StoreProduct product, int imageIndex}) resolveCollageTap(
    StoreProduct card,
    int imageIndex,
  ) {
    final last =
        card.imagePaths.isEmpty ? 0 : card.imagePaths.length - 1;
    final safe =
        imageIndex < 0 ? 0 : (imageIndex > last ? last : imageIndex);
    if (!collageHasNestedProducts(card) || card.imagePaths.isEmpty) {
      return (product: card, imageIndex: safe);
    }
    final assetId =
        safe < card.photoAssetIds.length
            ? card.photoAssetIds[safe].trim()
            : '';
    if (assetId.isEmpty ||
        assetId == card.id ||
        assetId.startsWith('img_')) {
      return (product: card, imageIndex: safe);
    }
    for (final piece in expandCollageToProducts(card)) {
      if (piece.id != assetId) continue;
      var local = 0;
      for (var i = 0; i < safe; i++) {
        final id =
            i < card.photoAssetIds.length
                ? card.photoAssetIds[i].trim()
                : '';
        if (id == assetId) local++;
      }
      return (product: piece, imageIndex: local);
    }
    return (product: card, imageIndex: safe);
  }

  static StoreProduct _sliceCollageProduct(
    StoreProduct card,
    String productId,
    List<int> indexes,
  ) {
    String pick(List<String> list, int i) =>
        i < list.length ? list[i] : '';
    return StoreProduct(
      id: productId,
      title: card.title,
      description: card.description,
      tags: card.tags,
      imagePaths: [for (final i in indexes) card.imagePaths[i]],
      photoAssetIds: [for (final i in indexes) pick(card.photoAssetIds, i)],
      imageThumbhashes: [
        for (final i in indexes) pick(card.imageThumbhashes, i),
      ],
      imageThumbnailUrls: [
        for (final i in indexes) pick(card.imageThumbnailUrls, i),
      ],
      imageDetailUrls: [
        for (final i in indexes) pick(card.imageDetailUrls, i),
      ],
      imageQualities: [
        for (final i in indexes) pick(card.imageQualities, i),
      ],
      imageIsLocked: [
        for (final i in indexes)
          i < card.imageIsLocked.length
              ? card.imageIsLocked[i]
              : card.isLocked,
      ],
      imageStockStatuses: [
        for (final i in indexes) pick(card.imageStockStatuses, i),
      ],
      imageImportStatuses: [
        for (final i in indexes) pick(card.imageImportStatuses, i),
      ],
      canEdit: card.canEdit,
      canDelete: card.canDelete,
      toneIndex: productId.hashCode.abs() % 4,
      viewCount: null,
      likeCount: null,
      wishlistCount: null,
      isLocked: indexes.isNotEmpty ? card.isLockedAt(indexes.first) : card.isLocked,
      stockStatus:
          indexes.isNotEmpty
              ? card.stockStatusAt(indexes.first)
              : card.stockStatus,
      mtoDays: card.mtoDays,
      precisionTag: card.precisionTag,
      collectionId: card.id,
      importFlags: card.importFlags,
      createdAt: card.createdAt,
    );
  }

  /// Viewer-private: count of embedded products with `wishlisted == true`.
  static int? _wishlistCountFromProducts(List<CatalogProduct> products) {
    var n = 0;
    for (final p in products) {
      if (p.wishlisted == true) n++;
    }
    return n > 0 ? n : null;
  }

  /// Prefer the larger non-null count (listing rollup vs product sum).
  static int? _preferCount(int? listing, int? fromChildren) {
    if (listing == null) return fromChildren;
    if (fromChildren == null) return listing;
    return listing >= fromChildren ? listing : fromChildren;
  }

  static ({int? likes, int? views}) _sumCatalogProductCounts(
    List<CatalogProduct> products,
  ) {
    var likeSum = 0;
    var viewSum = 0;
    var anyLike = false;
    var anyView = false;
    for (final p in products) {
      final like = p.likeCount;
      if (like != null) {
        anyLike = true;
        likeSum += like;
      }
      final views = p.viewCount;
      if (views != null) {
        anyView = true;
        viewSum += views;
      }
    }
    return (
      likes: anyLike ? likeSum : null,
      views: anyView ? viewSum : null,
    );
  }

  /// Sum of photo `likeCount` values when present (collection card badge).
  /// Dedupes by photo id — detail often repeats the same assets in
  /// `photos` and `mainGroupPhotos`. Prefer max(listing, sum) so a stale
  /// collection `likeCount: 0` does not hide product-level likes.
  static int? likeCountFromDetail(CollectionDetail detail) {
    final summed = _sumPhotoMetric(
      detail,
      (p) => p.likeCount,
    );
    return _preferCount(detail.likeCount, summed);
  }

  /// Same as [likeCountFromDetail] for views.
  static int? viewCountFromDetail(CollectionDetail detail) {
    final summed = _sumPhotoMetric(
      detail,
      (p) => p.viewCount,
    );
    return _preferCount(detail.viewCount, summed);
  }

  static int? _sumPhotoMetric(
    CollectionDetail detail,
    int? Function(CatalogPhoto p) read,
  ) {
    final seen = <String>{};
    var sum = 0;
    var any = false;
    for (final p in allDetailPhotos(detail)) {
      final id = p.id?.trim() ?? '';
      if (id.isNotEmpty && !seen.add(id)) continue;
      final c = read(p);
      if (c == null) continue;
      any = true;
      sum += c;
    }
    return any ? sum : null;
  }

  static Map<String, int> photoLikeCountsFromDetail(CollectionDetail detail) {
    return {
      for (final p in allDetailPhotos(detail))
        if ((p.id?.trim().isNotEmpty ?? false) && p.likeCount != null)
          p.id!.trim(): p.likeCount!,
    };
  }

  static Map<String, int> photoViewCountsFromDetail(CollectionDetail detail) {
    return {
      for (final p in allDetailPhotos(detail))
        if ((p.id?.trim().isNotEmpty ?? false) && p.viewCount != null)
          p.id!.trim(): p.viewCount!,
    };
  }

  /// Every photo surface on collection detail (for ids / liked flags).
  static List<CatalogPhoto> allDetailPhotos(CollectionDetail detail) {
    return [
      ...detail.photos,
      ...detail.mainGroupPhotos,
      for (final sub in detail.subGroups) ...sub.photos,
    ].where((p) => p.url.trim().isNotEmpty).toList(growable: false);
  }

  static Set<String> likedPhotoIdsFromDetail(CollectionDetail detail) {
    return {
      for (final p in allDetailPhotos(detail))
        if (p.liked == true && (p.id?.trim().isNotEmpty ?? false)) p.id!.trim(),
    };
  }

  /// Resolve stable photo id for [imageIndex], optionally matching [imagePath].
  static String photoIdAtIndex(
    CollectionDetail detail,
    StoreProduct mapped, {
    required int imageIndex,
    String imagePath = '',
  }) {
    if (imageIndex >= 0 && imageIndex < mapped.photoAssetIds.length) {
      final id = mapped.photoAssetIds[imageIndex].trim();
      if (id.isNotEmpty) return id;
    }
    final path = imagePath.trim();
    if (path.isEmpty &&
        imageIndex >= 0 &&
        imageIndex < mapped.imagePaths.length) {
      final fromProduct = mapped.imagePaths[imageIndex].trim();
      if (fromProduct.isNotEmpty) {
        return photoIdAtIndex(
          detail,
          mapped,
          imageIndex: -1,
          imagePath: fromProduct,
        );
      }
    }
    if (path.isEmpty) return '';
    for (final p in allDetailPhotos(detail)) {
      if (p.url.trim() == path) return p.id?.trim() ?? '';
    }
    return '';
  }

  static StoreProduct detailToProduct(CollectionDetail detail) {
    final photos =
        detail.photos.where((p) => p.url.trim().isNotEmpty).toList();
    return StoreProduct(
      id: detail.id,
      title: detail.name,
      description: detail.description,
      tags: [
        if (detail.tag.isNotEmpty) detail.tag,
        if (detail.kind != null) detail.kind!,
        if (detail.photoCount > 0) '${detail.photoCount} pieces',
      ],
      imagePaths: photos.map((p) => p.url).toList(),
      photoAssetIds: photos.map((p) => p.id?.trim() ?? '').toList(),
      imageThumbhashes: photos.map((p) => p.thumbhash?.trim() ?? '').toList(),
      imageThumbnailUrls: photos.map((p) => p.thumbnailUrl.trim()).toList(),
      imageDetailUrls: photos.map((p) => p.detailUrl.trim()).toList(),
      imageQualities: photos.map((p) => p.quality?.trim() ?? '').toList(),
      canEdit: detail.permissions?.edit ?? false,
      canDelete: detail.permissions?.delete ?? false,
      toneIndex: detail.id.hashCode.abs() % 4,
      viewCount: viewCountFromDetail(detail),
      likeCount: likeCountFromDetail(detail),
      isLocked: detail.isLocked,
      stockStatus: detail.stockStatus,
      mtoDays: detail.mtoDays,
      precisionTag: detail.precisionTag,
      createdAt: resolveCollectionCreatedAt(
        createdAt: detail.createdAt,
        fallbackCreatedAt:
            detail.photos.isNotEmpty
                ? detail.photos.first.createdAt
                : (detail.mainGroupPhotos.isNotEmpty
                    ? detail.mainGroupPhotos.first.createdAt
                    : null),
        id: detail.id,
      ),
    );
  }
}
