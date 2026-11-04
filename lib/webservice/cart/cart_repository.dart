import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/cart_qa.dart';
import 'package:project_c/models/catalog/cart_models.dart';
import 'package:project_c/services/cart_store.dart';
import 'package:project_c/webservice/cart/cart_request.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

/// Cart API surface — BE `/me/cart` + in-memory [CartStore] for badges.
abstract class CartRepository {
  CartStore get store;

  /// Hydrate badge count (and optionally full cart).
  Future<void> hydrate({bool loadItems = false});

  /// Refresh full grouped cart (cart screen).
  Future<CartPage> refreshCart();

  /// Refresh badge count only.
  Future<CartCount> refreshCount();

  Future<CartAddResult> addProductIds(List<String> productIds);

  Future<CartAddResult> addProductId(String productId);

  Future<CartRemoveResult> removeProduct(String productId);

  Future<CartRemoveResult> removeProducts(List<String> productIds);

  Future<CartMoveToWishlistResult> moveToWishlist(String productId);

  Future<CartUndoWishlistResult> undoMoveToWishlist(String productId);

  /// Undo a delete by re-adding the product id.
  Future<CartAddResult> restoreProductId(String productId);

  bool contains(String productId);

  int get count;

  int get storeCount;

  List<CartStoreGroup> groupedByStore();

  CartSummary get summary;
}

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl({
    required CartRequest request,
    required CartStore store,
  }) : _request = request,
       _store = store;

  static const _tag = 'CartRepository';

  final CartRequest _request;
  final CartStore _store;

  @override
  CartStore get store => _store;

  @override
  bool contains(String productId) => _store.contains(productId);

  @override
  int get count => _store.count;

  @override
  int get storeCount => _store.storeCount;

  @override
  List<CartStoreGroup> groupedByStore() => _store.groups;

  @override
  CartSummary get summary => _store.summary;

  @override
  Future<void> hydrate({bool loadItems = false}) async {
    CartQa.caseStart('TC-00', 'Hydrate cart cache (badge + in-cart ids)');
    try {
      await refreshCart();
      CartQa.caseEnd(
        'TC-00',
        pass: true,
        detail: 'items=${_store.count} stores=${_store.storeCount}',
      );
    } catch (e) {
      AppLog.e(_tag, 'hydrate cart failed — trying count', e);
      try {
        await refreshCount();
        CartQa.caseEnd(
          'TC-00',
          pass: true,
          detail:
              'count-only items=${_store.count} stores=${_store.storeCount}',
        );
      } catch (e2) {
        AppLog.e(_tag, 'hydrate count failed', e2);
        CartQa.caseEnd('TC-00', pass: false, detail: '$e2');
      }
    }
  }

  @override
  Future<CartPage> refreshCart() async {
    final page = await _request.fetchCart();
    _store.applyPage(page);
    return page;
  }

  @override
  Future<CartCount> refreshCount() async {
    try {
      final count = await _request.fetchCount();
      _store.applyCount(count);
      return count;
    } on CatalogApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        CartQa.info('GET /me/cart/count miss → GET /me/cart', detail: '${e.statusCode}');
        final page = await refreshCart();
        return CartCount(
          totalItems: page.totalItems,
          totalStores: page.totalStores,
        );
      }
      rethrow;
    }
  }

  @override
  Future<CartAddResult> addProductIds(List<String> productIds) async {
    CartQa.caseStart(
      'TC-01',
      'Bulk add POST /me/cart n=${productIds.length}',
    );
    try {
      final result = await _request.addProducts(productIds: productIds);
      _store.applyAddResult(result);
      if (result.added.isNotEmpty && result.totalCount == null) {
        // ignore: discarded_futures
        refreshCount().catchError((_) => const CartCount());
      }
      CartQa.caseEnd(
        'TC-01',
        pass: true,
        detail:
            'added=${result.addedCount} skipInCart=${result.alreadyInCartCount} '
            'skipOos=${result.outOfStockCount}',
      );
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-01', pass: false, detail: '$e');
      rethrow;
    }
  }

  @override
  Future<CartAddResult> addProductId(String productId) async {
    CartQa.caseStart(
      'TC-05',
      'Photo/single add id=${CartQa.shortId(productId)}',
    );
    try {
      final result = await _request.addProduct(productId: productId);
      _store.applyAddResult(result);
      if (result.added.isNotEmpty && result.totalCount == null) {
        // ignore: discarded_futures
        refreshCount().catchError((_) => const CartCount());
      }
      CartQa.caseEnd(
        'TC-05',
        pass: true,
        detail: 'added=${result.addedCount} toast="${result.toastMessage}"',
      );
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-05', pass: false, detail: '$e');
      rethrow;
    }
  }

  @override
  Future<CartRemoveResult> removeProduct(String productId) async {
    CartQa.caseStart(
      'TC-07',
      'Remove DELETE /me/cart/:id id=${CartQa.shortId(productId)}',
    );
    try {
      final result = await _request.removeProduct(productId: productId);
      _store.applyRemove(
        productId: productId,
        remainingItems: result.remainingItems,
        remainingStores: result.remainingStores,
      );
      CartQa.caseEnd(
        'TC-07',
        pass: true,
        detail: 'left=${result.remainingItems}',
      );
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-07', pass: false, detail: '$e');
      rethrow;
    }
  }

  @override
  Future<CartRemoveResult> removeProducts(List<String> productIds) async {
    CartQa.caseStart('TC-07b', 'Batch remove n=${productIds.length}');
    try {
      final result = await _request.removeProducts(productIds: productIds);
      for (final id in productIds) {
        _store.applyRemove(
          productId: id,
          remainingItems: result.remainingItems,
        );
      }
      CartQa.caseEnd(
        'TC-07b',
        pass: true,
        detail: 'left=${result.remainingItems}',
      );
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-07b', pass: false, detail: '$e');
      rethrow;
    }
  }

  @override
  Future<CartMoveToWishlistResult> moveToWishlist(String productId) async {
    CartQa.caseStart(
      'TC-08',
      'Move to wishlist id=${CartQa.shortId(productId)}',
    );
    try {
      final result = await _request.moveToWishlist(productId: productId);
      _store.applyRemove(
        productId: productId,
        remainingItems: result.remainingItems,
      );
      CartQa.caseEnd(
        'TC-08',
        pass: true,
        detail: 'left=${result.remainingItems}',
      );
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-08', pass: false, detail: '$e');
      rethrow;
    }
  }

  @override
  Future<CartUndoWishlistResult> undoMoveToWishlist(String productId) async {
    CartQa.caseStart(
      'TC-08u',
      'Undo wishlist→cart id=${CartQa.shortId(productId)}',
    );
    try {
      final result = await _request.undoMoveToWishlist(productId: productId);
      try {
        await refreshCart();
      } catch (_) {
        await refreshCount();
      }
      CartQa.caseEnd('TC-08u', pass: true);
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-08u', pass: false, detail: '$e');
      rethrow;
    }
  }

  @override
  Future<CartAddResult> restoreProductId(String productId) async {
    CartQa.caseStart(
      'TC-07u',
      'Undo remove → re-add id=${CartQa.shortId(productId)}',
    );
    try {
      final result = await addProductId(productId);
      try {
        await refreshCart();
      } catch (_) {}
      CartQa.caseEnd('TC-07u', pass: true);
      return result;
    } catch (e) {
      CartQa.caseEnd('TC-07u', pass: false, detail: '$e');
      rethrow;
    }
  }
}
