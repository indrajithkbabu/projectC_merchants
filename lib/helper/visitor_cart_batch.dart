import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/catalog/cart_models.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/cart_store.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/cart/cart_repository.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Selection → cart candidate resolution for visitor multi-select.
class VisitorCartBatch {
  VisitorCartBatch._();

  /// Classify selected photo keys against [cart] + stock.
  static CartSelectionBreakdown breakdown({
    required Set<String> photoKeys,
    required List<StoreProduct> products,
    required CartStore cart,
  }) {
    final byId = {for (final p in products) p.id: p};
    var addable = 0;
    var inCart = 0;
    var outOfStock = 0;

    for (final key in photoKeys) {
      final sep = key.lastIndexOf('|');
      if (sep <= 0) continue;
      final listingId = key.substring(0, sep);
      final index = int.tryParse(key.substring(sep + 1)) ?? 0;
      final product = byId[listingId];
      if (product == null) continue;

      final productId = _productIdFor(product, index);
      final stock = product.stockStatusAt(index);
      if (cart.contains(productId)) {
        inCart++;
      } else if (stock == CatalogStockStatus.outOfStock) {
        outOfStock++;
      } else {
        addable++;
      }
    }

    return CartSelectionBreakdown(
      addable: addable,
      alreadyInCart: inCart,
      outOfStock: outOfStock,
      selected: photoKeys.length,
    );
  }

  /// Resolve selected photos → product ids and `POST /me/cart`.
  static Future<CartAddResult> addSelected({
    required CartRepository cart,
    required Set<String> photoKeys,
    required List<StoreProduct> products,
    required String storeId,
    required String storeName,
    String storeAvatarUrl = '',
    CollectionRepository? collections,
  }) async {
    final items = await resolveItems(
      photoKeys: photoKeys,
      products: products,
      storeId: storeId,
      storeName: storeName,
      storeAvatarUrl: storeAvatarUrl,
      collections: collections,
    );
    final productIds = [
      for (final i in items)
        if (i.productId.trim().isNotEmpty) i.productId.trim(),
    ];
    BeVerify.step(
      'W multi-select cart',
      detail:
          'keys=${photoKeys.length} resolved=${productIds.length} '
          'ids=${productIds.map(BeVerify.shortId).join(",")}',
    );
    if (productIds.isEmpty) {
      return const CartAddResult(toastMessage: 'Nothing added');
    }
    return cart.addProductIds(productIds);
  }

  static Future<List<CartItem>> resolveItems({
    required Set<String> photoKeys,
    required List<StoreProduct> products,
    required String storeId,
    required String storeName,
    String storeAvatarUrl = '',
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

      if (_assetsAreProductIds(product)) {
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
      } catch (_) {
        resolvedByListing[listingId] = const [];
        return const [];
      }
    }

    final now = DateTime.now();
    final out = <CartItem>[];
    final seen = <String>{};

    for (final key in photoKeys) {
      final sep = key.lastIndexOf('|');
      if (sep <= 0) continue;
      final listingId = key.substring(0, sep).trim();
      final index = int.tryParse(key.substring(sep + 1).trim()) ?? 0;
      final product = byId[listingId];
      if (product == null) continue;

      final collageIds = await idsForListing(product);
      var productId = '';
      if (index >= 0 && index < collageIds.length) {
        productId = collageIds[index].trim();
      }
      if (productId.isEmpty || productId.startsWith('img_')) {
        productId = _productIdFor(product, index);
      }
      if (productId.isEmpty || !seen.add(productId)) continue;

      final stock = product.stockStatusAt(index);
      final imageUrl =
          product.urlForRole(index, CatalogImageRole.grid).trim().isEmpty
              ? (product.primaryImagePath ?? '')
              : product.urlForRole(index, CatalogImageRole.grid);
      final detail = _detailLine(product, stock);

      out.add(
        CartItem(
          productId: productId,
          listingId: listingId,
          imageIndex: index,
          storeId: sid,
          storeName: storeName.trim().isEmpty ? 'Store' : storeName.trim(),
          storeAvatarUrl: storeAvatarUrl.trim(),
          title: product.title.trim().isEmpty ? 'Product' : product.title.trim(),
          imageUrl: imageUrl,
          thumbhash: product.thumbhashAt(index) ?? '',
          detailLine: detail,
          fineWeightGrams: _fineFromPrecision(product.precisionTag),
          stockStatus: stock,
          mtoDays: product.mtoDays,
          addedAt: now,
        ),
      );
    }
    return out;
  }

  static String _productIdFor(StoreProduct product, int index) {
    final id = product.sourceProductIdAt(index).trim();
    if (id.isNotEmpty && !id.startsWith('img_')) return id;
    return product.id.trim();
  }

  static String _detailLine(StoreProduct product, CatalogStockStatus? stock) {
    if (stock == CatalogStockStatus.mto) {
      final days = product.mtoDays;
      if (days != null && days > 0) return 'To order · $days days';
      return 'To order';
    }
    final tag = product.precisionTag.trim();
    if (tag.isNotEmpty) return tag;
    return product.meta;
  }

  /// Best-effort parse of a fine grams value from precision tag text.
  static double? _fineFromPrecision(String raw) {
    final m = RegExp(
      r'(\d+(?:\.\d+)?)\s*g',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '');
  }

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
    if (assets.length > 1) return distinct > 0;
    return true;
  }
}

/// Counts for selection-dock cart CTA label / enabled state.
class CartSelectionBreakdown {
  const CartSelectionBreakdown({
    required this.addable,
    required this.alreadyInCart,
    required this.outOfStock,
    required this.selected,
  });

  final int addable;
  final int alreadyInCart;
  final int outOfStock;
  final int selected;

  bool get allInCart =>
      selected > 0 && addable == 0 && outOfStock == 0 && alreadyInCart > 0;

  bool get allOutOfStock =>
      selected > 0 && addable == 0 && alreadyInCart == 0 && outOfStock > 0;

  bool get isEmpty => selected <= 0;
}

/// Prefer server [CartAddResult.toastMessage]; else build a local fallback.
String cartAddSnackMessage(
  CartAddResult result, {
  int? storeCountAfter,
}) {
  final server = result.toastMessage.trim();
  if (server.isNotEmpty) return server;

  final parts = <String>[];
  if (result.addedCount > 0) {
    parts.add(
      result.addedCount == 1 ? 'Added 1' : 'Added ${result.addedCount}',
    );
  } else if (!result.cartFull) {
    parts.add('Nothing added');
  }
  if (result.alreadyInCartCount > 0) {
    parts.add('${result.alreadyInCartCount} already in cart');
  }
  if (result.outOfStockCount > 0) {
    parts.add('${result.outOfStockCount} out of stock');
  }
  if (result.cartFull) {
    parts.add('Cart is full');
  }
  final stores = storeCountAfter ?? result.storeCount;
  if (stores != null && stores > 1 && result.addedCount > 0) {
    parts.add('from $stores stores');
  }
  return parts.join(' · ');
}
