import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

/// Parallel private wishlist bookmarks for visitor multi-select.
///
/// Keys are `"listingId|imageIndex"`. Each selected **photo** resolves to a
/// CatalogProduct id. When the in-memory card still has stale `img_*`
/// assets (cache), fetches `GET …/products?collectionId=` to map indices.
class VisitorWishlistBatch {
  VisitorWishlistBatch._();

  /// Bookmarks every selected photo’s product id.
  ///
  /// Returns product ids that are wishlisted after the call. Prefer
  /// [VisitorWishlistOutcome.newlyAddedProductIds] for badge bumps.
  static Future<VisitorWishlistOutcome> wishlistSelected({
    required WishlistRepository wishlist,
    required Set<String> photoKeys,
    required List<StoreProduct> products,
    String storeId = '',
    CollectionRepository? collections,
  }) async {
    final byId = {for (final p in products) p.id: p};
    final repo =
        collections ?? ServiceLocator.get<CollectionRepository>();
    final sid = storeId.trim();

    // listingId → ordered CatalogProduct ids (cover-first collage order).
    final resolvedByListing = <String, List<String>>{};

    Future<List<String>> idsForListing(StoreProduct product) async {
      final listingId = product.id.trim();
      final cached = resolvedByListing[listingId];
      if (cached != null) return cached;

      if (_assetsAreProductIds(product)) {
        final ids =
            product.photoAssetIds.map((e) => e.trim()).toList(growable: false);
        resolvedByListing[listingId] = ids;
        BeVerify.info(
          'multi-select assets ok',
          detail:
              'listing=${BeVerify.shortId(listingId)} n=${ids.length} '
              'from=memory',
        );
        return ids;
      }

      if (sid.isEmpty) {
        BeVerify.fail(
          'multi-select needs storeId to resolve img_ assets',
          detail: 'listing=${BeVerify.shortId(listingId)}',
        );
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
        BeVerify.info(
          'multi-select assets fetched',
          detail:
              'listing=${BeVerify.shortId(listingId)} '
              'apiProducts=${page.items.length} collageIds=${ids.length} '
              'ids=${ids.map(BeVerify.shortId).join(",")}',
        );
        // Refresh cache so next grid open has product ids (not img_*).
        if (ids.isNotEmpty &&
            ids.any((id) => id.isNotEmpty && !id.startsWith('img_'))) {
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
          'multi-select fetch products',
          detail: 'listing=${BeVerify.shortId(listingId)} $e',
        );
        resolvedByListing[listingId] = const [];
        return const [];
      }
    }

    final targets = <String, String>{}; // productId → listingId

    for (final key in photoKeys) {
      final sep = key.lastIndexOf('|');
      if (sep <= 0) continue;
      final listingId = key.substring(0, sep).trim();
      final index = int.tryParse(key.substring(sep + 1).trim()) ?? -1;
      if (listingId.isEmpty) continue;
      final product = byId[listingId];
      if (product == null) continue;

      final collageIds = await idsForListing(product);
      String productId = '';
      var source = 'none';
      if (index >= 0 && index < collageIds.length) {
        productId = collageIds[index].trim();
        source = 'collage[$index]';
      }
      if (productId.isEmpty || productId.startsWith('img_')) {
        productId = listingId;
        source = 'fallback_listing';
      }

      targets[productId] = listingId;
      BeVerify.info(
        'multi-select key',
        detail:
            'key=$key → product=${BeVerify.shortId(productId)} via=$source',
      );
    }

    BeVerify.step(
      'W multi-select wishlist',
      detail:
          'keys=${photoKeys.length} targets=${targets.length} '
          'ids=${targets.keys.map(BeVerify.shortId).join(",")}',
    );

    if (targets.isEmpty) {
      throw StateError('No selectable items.');
    }
    if (targets.length < photoKeys.length) {
      BeVerify.info(
        'multi-select wishlist collapsed some keys',
        detail:
            'selected=${photoKeys.length} uniqueProducts=${targets.length}',
      );
    }

    final productIds = targets.keys.toList(growable: false);

    try {
      final batch = await wishlist.addWishlistProductsBatch(
        productIds: productIds,
      );
      final okIds = <String>{...batch.okProductIds};
      // Server returned counts without per-item rows — treat as all ok.
      if (okIds.isEmpty &&
          batch.failedCount == 0 &&
          (batch.addedCount + batch.alreadyWishlistedCount) > 0) {
        okIds.addAll(productIds);
      }
      if (okIds.isEmpty) {
        BeVerify.fail(
          'multi-select wishlist',
          detail:
              'batch empty ok added=${batch.addedCount} '
              'already=${batch.alreadyWishlistedCount} '
              'failed=${batch.failedCount}',
        );
        throw StateError('Unable to update wishlist right now.');
      }
      final newlyAdded = <String>{
        for (final i in batch.items)
          if (i.wishlisted &&
              !i.alreadyWishlisted &&
              i.productId.isNotEmpty)
            i.productId,
      };
      // Counts-only batch body: treat all ok as newly added for badge bump.
      if (newlyAdded.isEmpty &&
          batch.addedCount > 0 &&
          batch.items.isEmpty) {
        newlyAdded.addAll(okIds);
      }
      BeVerify.ok(
        'multi-select wishlist',
        detail:
            'batch ok=${okIds.length}/${targets.length} '
            'added=${batch.addedCount} already=${batch.alreadyWishlistedCount} '
            'failed=${batch.failedCount}',
      );
      return VisitorWishlistOutcome(
        okProductIds: okIds,
        newlyAddedProductIds: newlyAdded,
      );
    } on CatalogApiException catch (e) {
      BeVerify.info(
        'multi-select wishlist batch miss → parallel',
        detail: 'status=${e.statusCode} ${e.message}',
      );
    }

    final outcomes = await Future.wait([
      for (final entry in targets.entries)
        _wishlistProduct(
          wishlist: wishlist,
          productId: entry.key,
          listingId: entry.value,
        ),
    ]);

    final okIds = <String>{};
    Object? firstError;
    var anyOk = false;
    for (final o in outcomes) {
      if (o.error != null && firstError == null) firstError = o.error;
      if (!o.ok) continue;
      anyOk = true;
      okIds.add(o.productId);
    }
    if (!anyOk && firstError != null) {
      BeVerify.fail('multi-select wishlist', detail: '$firstError');
      throw firstError;
    }
    if (!anyOk) {
      throw StateError('Unable to update wishlist right now.');
    }
    BeVerify.ok(
      'multi-select wishlist',
      detail: 'ok=${okIds.length}/${targets.length} via=parallel',
    );
    // Parallel path has no alreadyWishlisted flag — bump by ok ids.
    return VisitorWishlistOutcome(
      okProductIds: okIds,
      newlyAddedProductIds: okIds,
    );
  }

  /// Bumps viewer-private [StoreProduct.wishlistCount] for listings that
  /// received newly bookmarked product ids (does not double-count already).
  static List<StoreProduct> applyWishlistCounts({
    required List<StoreProduct> products,
    required Set<String> newlyAddedProductIds,
  }) {
    if (newlyAddedProductIds.isEmpty) return products;
    final next = <StoreProduct>[];
    for (final p in products) {
      final assets = <String>{
        for (final id in p.photoAssetIds)
          if (id.trim().isNotEmpty) id.trim(),
        if (p.id.trim().isNotEmpty) p.id.trim(),
      };
      var added = 0;
      for (final id in newlyAddedProductIds) {
        if (assets.contains(id)) added++;
      }
      if (added <= 0) {
        next.add(p);
        continue;
      }
      next.add(p.copyWith(wishlistCount: (p.wishlistCount ?? 0) + added));
    }
    return next;
  }

  /// True when every slot looks like a CatalogProduct id (not img_* / empty).
  static bool _assetsAreProductIds(StoreProduct product) {
    final assets = product.photoAssetIds;
    if (assets.isEmpty) return false;
    final listing = product.id.trim();
    var distinct = 0;
    for (final raw in assets) {
      final a = raw.trim();
      if (a.isEmpty || a.startsWith('img_')) return false;
      if (a != listing) distinct++;
    }
    // Multi-photo collage must have at least one id ≠ listing (embedded products).
    if (assets.length > 1) return distinct > 0;
    return true;
  }

  static Future<({String productId, String listingId, bool ok, Object? error})>
  _wishlistProduct({
    required WishlistRepository wishlist,
    required String productId,
    required String listingId,
  }) async {
    try {
      await wishlist.addWishlistProduct(productId: productId);
      return (
        productId: productId,
        listingId: listingId,
        ok: true,
        error: null,
      );
    } catch (e) {
      BeVerify.fail(
        'multi-select wishlist item',
        detail:
            'product=${BeVerify.shortId(productId)} '
            'listing=${BeVerify.shortId(listingId)} $e',
      );
      return (
        productId: productId,
        listingId: listingId,
        ok: false,
        error: e,
      );
    }
  }
}

/// Result of [VisitorWishlistBatch.wishlistSelected].
class VisitorWishlistOutcome {
  const VisitorWishlistOutcome({
    required this.okProductIds,
    this.newlyAddedProductIds = const {},
  });

  final Set<String> okProductIds;

  /// Product ids that were not already wishlisted (for badge increments).
  final Set<String> newlyAddedProductIds;
}
