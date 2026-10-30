import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/models/store_channel.dart';
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
    return StoreChannel(
      id: store.id,
      name: store.name,
      handle: store.slug,
      avatarColor: avatarColor,
      products: products,
      isOwn: store.isOwn,
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
      final url =
          p.primaryImageUrl.trim().isNotEmpty
              ? p.primaryImageUrl.trim()
              : (p.imageUrls.isNotEmpty ? p.imageUrls.first.trim() : '');
      if (url.isEmpty) continue;
      urls.add(url);
      thumbs.add(
        p.primaryImageThumbnailUrl.trim().isNotEmpty
            ? p.primaryImageThumbnailUrl.trim()
            : (p.imageThumbnailUrls.isNotEmpty
                ? p.imageThumbnailUrls.first.trim()
                : ''),
      );
      details.add(
        p.primaryImageDetailUrl.trim().isNotEmpty
            ? p.primaryImageDetailUrl.trim()
            : (p.imageDetailUrls.isNotEmpty
                ? p.imageDetailUrls.first.trim()
                : ''),
      );
      // Prefer CatalogProduct._id so collage cell → like/wishlist/import hits
      // the product (not img_* / collection listing id).
      final productId = p.id.trim();
      final imageId =
          p.primaryImageId.trim().isNotEmpty
              ? p.primaryImageId.trim()
              : (p.imageIds.isNotEmpty ? p.imageIds.first.trim() : '');
      ids.add(productId.isNotEmpty ? productId : imageId);
      final hash =
          p.primaryImageThumbhash.trim().isNotEmpty
              ? p.primaryImageThumbhash.trim()
              : (p.imageThumbhashes.isNotEmpty
                  ? p.imageThumbhashes.first.trim()
                  : '');
      hashes.add(hash);
      locks.add(p.isLocked);
      stocks.add(p.stockStatus?.apiValue ?? '');
      importStatuses.add(p.importFlags.importStatus?.trim() ?? '');
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
  /// [collectionCardFromProducts]. Empty when the card has fewer than two
  /// seeded product cells (single / cover-only).
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
    for (var i = 0; i < paths.length; i++) {
      final id =
          i < card.photoAssetIds.length ? card.photoAssetIds[i].trim() : '';
      if (id.isEmpty) continue;
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
