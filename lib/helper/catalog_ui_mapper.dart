import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';
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
    return StoreProduct(
      id: summary.id,
      title: summary.name,
      description: summary.description,
      tags: [
        if (summary.tag.isNotEmpty) summary.tag,
        if (summary.kind != null) summary.kind!,
        '${summary.photoCount} photos',
      ],
      imagePaths:
          summary.cover.url.isEmpty ? const [] : [summary.cover.url],
      photoAssetIds: coverId.isEmpty ? const [] : [coverId],
      imageThumbhashes: coverHash.isEmpty ? const [] : [coverHash],
      canEdit: summary.permissions?.edit ?? false,
      canDelete: summary.permissions?.delete ?? false,
      toneIndex: summary.id.hashCode.abs() % 4,
      viewCount: summary.viewCount,
    );
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
        '${detail.photoCount} photos',
      ],
      imagePaths: photos.map((p) => p.url).toList(),
      photoAssetIds: photos.map((p) => p.id?.trim() ?? '').toList(),
      imageThumbhashes: photos.map((p) => p.thumbhash?.trim() ?? '').toList(),
      canEdit: detail.permissions?.edit ?? false,
      canDelete: detail.permissions?.delete ?? false,
      toneIndex: detail.id.hashCode.abs() % 4,
      viewCount: detail.viewCount,
    );
  }
}
