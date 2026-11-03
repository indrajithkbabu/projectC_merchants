import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Owner multi-select delete helpers.
///
/// Photo keys are `"listingId|imageIndex"` (same as visitor selection). Each
/// key resolves to a CatalogProduct id when collage assets are nested jewels,
/// or to a legacy `img_*` photo id.
class OwnerItemDelete {
  OwnerItemDelete._();

  /// Unique CatalogProduct / photo targets for [photoKeys].
  ///
  /// Returns `productId → listingId`. Legacy `img_*` ids are included so the
  /// caller can branch to [CollectionRepository.deletePhotos].
  static Future<Map<String, String>> resolveTargets({
    required Set<String> photoKeys,
    required List<StoreProduct> products,
    String storeId = '',
    CollectionRepository? collections,
  }) async {
    final byId = {for (final p in products) p.id: p};
    final repo =
        collections ?? ServiceLocator.get<CollectionRepository>();
    final sid = storeId.trim();
    final resolvedByListing = <String, List<String>>{};

    Future<List<String>> idsForListing(StoreProduct product) async {
      final listingId = product.id.trim();
      final cached = resolvedByListing[listingId];
      if (cached != null) return cached;

      if (_assetsAreProductOrPhotoIds(product)) {
        final ids =
            product.photoAssetIds.map((e) => e.trim()).toList(growable: false);
        resolvedByListing[listingId] = ids;
        return ids;
      }

      if (sid.isEmpty) {
        resolvedByListing[listingId] = const [];
        return const [];
      }

      try {
        final page = await repo.listStoreProducts(
          storeId: sid,
          collectionId: listingId,
          limit: 50,
        );
        final coverUrl = product.primaryImagePath?.trim() ?? '';
        final ids = CatalogUiMapper.orderedCollageProductIds(
          products: page.items,
          coverUrl: coverUrl,
        );
        resolvedByListing[listingId] = ids;
        if (ids.isNotEmpty) {
          final updated = product.copyWith(photoAssetIds: ids);
          final next = [
            for (final p in products)
              if (p.id == listingId) updated else p,
          ];
          await StoreProductsCache.instance.write(sid, next);
        }
        return ids;
      } catch (e) {
        BeVerify.fail(
          'owner-delete resolve products',
          detail: 'listing=${BeVerify.shortId(listingId)} $e',
        );
        resolvedByListing[listingId] = const [];
        return const [];
      }
    }

    final targets = <String, String>{};
    for (final key in photoKeys) {
      final sep = key.lastIndexOf('|');
      if (sep <= 0) continue;
      final listingId = key.substring(0, sep).trim();
      final index = int.tryParse(key.substring(sep + 1).trim()) ?? -1;
      if (listingId.isEmpty) continue;
      final product = byId[listingId];
      if (product == null) continue;

      final collageIds = await idsForListing(product);
      var targetId = '';
      if (index >= 0 && index < collageIds.length) {
        targetId = collageIds[index].trim();
      }
      if (targetId.isEmpty) {
        targetId = listingId;
      }
      targets[targetId] = listingId;
      BeVerify.info(
        'owner-delete key',
        detail:
            'key=$key → id=${BeVerify.shortId(targetId)} '
            'listing=${BeVerify.shortId(listingId)}',
      );
    }
    return targets;
  }

  /// Removes frames matching [deletedIds] from collage cards.
  ///
  /// Listings that lose every frame are dropped. Cards unchanged when none of
  /// their asset / listing ids match.
  static List<StoreProduct> stripDeletedIds({
    required List<StoreProduct> products,
    required Set<String> deletedIds,
  }) {
    if (deletedIds.isEmpty) return products;
    final next = <StoreProduct>[];
    for (final card in products) {
      final listingId = card.id.trim();
      if (deletedIds.contains(listingId)) {
        // Whole listing deleted.
        continue;
      }
      if (isListingEmptied(card, deletedIds)) {
        continue;
      }
      if (card.photoAssetIds.isEmpty) {
        // Cover-only / unresolved — keep unless listing id was deleted above.
        next.add(card);
        continue;
      }
      final keepIndexes = <int>[];
      for (var i = 0; i < card.imagePaths.length; i++) {
        final asset =
            i < card.photoAssetIds.length ? card.photoAssetIds[i].trim() : '';
        if (asset.isNotEmpty && deletedIds.contains(asset)) continue;
        keepIndexes.add(i);
      }
      if (keepIndexes.length == card.imagePaths.length) {
        next.add(card);
        continue;
      }
      if (keepIndexes.isEmpty) continue;
      next.add(_sliceCard(card, keepIndexes));
    }
    return next;
  }

  /// True when every nested asset on [card] is in [deletedIds] (listing empty).
  static bool isListingEmptied(StoreProduct card, Set<String> deletedIds) {
    if (deletedIds.contains(card.id.trim())) return true;
    final assets = <String>{
      for (final raw in card.photoAssetIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    };
    if (assets.isEmpty) return false;
    return assets.every(deletedIds.contains);
  }

  /// True when [id] looks like a legacy collection photo key.
  static bool isLegacyPhotoId(String id) {
    final t = id.trim();
    return t.startsWith('img_');
  }

  static bool _assetsAreProductOrPhotoIds(StoreProduct product) {
    final assets = product.photoAssetIds;
    if (assets.isEmpty) return false;
    for (final raw in assets) {
      if (raw.trim().isEmpty) return false;
    }
    return true;
  }

  static StoreProduct _sliceCard(StoreProduct card, List<int> indexes) {
    String pick(List<String> list, int i) =>
        i < list.length ? list[i] : '';
    bool pickBool(List<bool> list, int i, bool fallback) =>
        i < list.length ? list[i] : fallback;
    return card.copyWith(
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
          pickBool(card.imageIsLocked, i, card.isLocked),
      ],
      imageStockStatuses: [
        for (final i in indexes) pick(card.imageStockStatuses, i),
      ],
      imageImportStatuses: [
        for (final i in indexes) pick(card.imageImportStatuses, i),
      ],
    );
  }
}
