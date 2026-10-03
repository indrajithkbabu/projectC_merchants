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
    );
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
    );
  }
}
