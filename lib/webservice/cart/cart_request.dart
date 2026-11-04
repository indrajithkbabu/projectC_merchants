import 'package:project_c/helper/cart_qa.dart';
import 'package:project_c/models/catalog/cart_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

/// Catalog cart HTTP calls (`/me/cart…`). Logs under filter [CartQa.filter].
class CartRequest {
  CartRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// POST `/me/cart` — bulk add. Skips in-cart / out-of-stock server-side.
  Future<CartAddResult> addProducts({required List<String> productIds}) async {
    final ids = [
      for (final raw in productIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    ];
    CartQa.step(
      'API POST /me/cart',
      detail: 'n=${ids.length} ids=${ids.map(CartQa.shortId).join(",")}',
    );
    if (ids.isEmpty) {
      throw CatalogApiException(
        statusCode: 400,
        code: 'VALIDATION_ERROR',
        message: 'productIds is required and must not be empty',
      );
    }
    try {
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.meCart,
        body: {'productIds': ids},
        requiresAuth: true,
      );
      final result = CartAddResult.fromJson(json ?? const {});
      CartQa.ok(
        'POST /me/cart',
        detail:
            'added=${result.addedCount} inCart=${result.alreadyInCartCount} '
            'oos=${result.outOfStockCount} total=${result.totalCount} '
            'stores=${result.storeCount} toast="${result.toastMessage}"',
      );
      return result;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'POST /me/cart',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// POST `/products/:productId/cart` — single-item alias.
  Future<CartAddResult> addProduct({required String productId}) async {
    final id = productId.trim();
    CartQa.step(
      'API POST /products/:id/cart',
      detail: 'id=${CartQa.shortId(id)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.productCart(id),
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      final map = json ?? const <String, dynamic>{};
      final CartAddResult result;
      if (map.containsKey('added') || map.containsKey('skipped')) {
        result = CartAddResult.fromJson(map);
      } else {
        result = CartAddResult(
          added: [id],
          toastMessage:
              (map['toastMessage'] as String?)?.trim() ?? 'Added to cart',
          totalCount: (map['totalCount'] as num?)?.toInt(),
          storeCount: (map['storeCount'] as num?)?.toInt(),
        );
      }
      CartQa.ok(
        'POST /products/:id/cart',
        detail:
            'added=${result.addedCount} toast="${result.toastMessage}" '
            'total=${result.totalCount}',
      );
      return result;
    } on CatalogApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        CartQa.info(
          'product cart alias miss → POST /me/cart',
          detail: '${e.statusCode}',
        );
        return addProducts(productIds: [id]);
      }
      CartQa.fail(
        'POST /products/:id/cart',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// GET `/me/cart` — grouped by store.
  Future<CartPage> fetchCart() async {
    CartQa.step('API GET /me/cart');
    try {
      final json = await _api.sendJson(
        method: HttpMethod.get,
        path: Endpoints.meCart,
        requiresAuth: true,
      );
      final page = CartPage.fromJson(json ?? const {});
      CartQa.ok(
        'GET /me/cart',
        detail:
            'items=${page.totalItems} stores=${page.totalStores} '
            'fine="${page.summary.displayLabel}" '
            'in=${page.summary.inStockCount} '
            'oos=${page.summary.outOfStockCount}',
      );
      return page;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'GET /me/cart',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// GET `/me/cart/count` — badge.
  Future<CartCount> fetchCount() async {
    CartQa.step('API GET /me/cart/count');
    try {
      final json = await _api.sendJson(
        method: HttpMethod.get,
        path: Endpoints.meCartCount,
        requiresAuth: true,
      );
      final count = CartCount.fromJson(json ?? const {});
      CartQa.ok(
        'GET /me/cart/count',
        detail: 'items=${count.totalItems} stores=${count.totalStores}',
      );
      return count;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'GET /me/cart/count',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// DELETE `/me/cart/:productId`
  Future<CartRemoveResult> removeProduct({required String productId}) async {
    final id = productId.trim();
    CartQa.step(
      'API DELETE /me/cart/:id',
      detail: 'id=${CartQa.shortId(id)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.meCartItem(id),
        requiresAuth: true,
      );
      final result = CartRemoveResult.fromJson(json ?? const {});
      CartQa.ok(
        'DELETE /me/cart/:id',
        detail:
            'removed=${CartQa.shortId(result.removedProductId)} '
            'left=${result.remainingItems} stores=${result.remainingStores}',
      );
      return result;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'DELETE /me/cart/:id',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// DELETE `/me/cart/batch`
  Future<CartRemoveResult> removeProducts({
    required List<String> productIds,
  }) async {
    final ids = [
      for (final raw in productIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    ];
    CartQa.step(
      'API DELETE /me/cart/batch',
      detail: 'n=${ids.length} ids=${ids.map(CartQa.shortId).join(",")}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.meCartBatch,
        body: {'productIds': ids},
        requiresAuth: true,
      );
      final map = json ?? const <String, dynamic>{};
      final result = CartRemoveResult(
        success: map['success'] != false,
        remainingItems: (map['remainingItems'] as num?)?.toInt() ?? 0,
      );
      CartQa.ok(
        'DELETE /me/cart/batch',
        detail:
            'removedCount=${map['removedCount']} left=${result.remainingItems}',
      );
      return result;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'DELETE /me/cart/batch',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// POST `/me/cart/:productId/wishlist` — move to wishlist.
  Future<CartMoveToWishlistResult> moveToWishlist({
    required String productId,
  }) async {
    final id = productId.trim();
    CartQa.step(
      'API POST /me/cart/:id/wishlist',
      detail: 'id=${CartQa.shortId(id)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.meCartItemWishlist(id),
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      final result = CartMoveToWishlistResult.fromJson(json ?? const {});
      CartQa.ok(
        'POST /me/cart/:id/wishlist',
        detail:
            'moved=${CartQa.shortId(result.movedProductId)} '
            'left=${result.remainingItems}',
      );
      return result;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'POST /me/cart/:id/wishlist',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// DELETE `/me/cart/:productId/wishlist` — undo move to wishlist.
  Future<CartUndoWishlistResult> undoMoveToWishlist({
    required String productId,
  }) async {
    final id = productId.trim();
    CartQa.step(
      'API DELETE /me/cart/:id/wishlist',
      detail: 'id=${CartQa.shortId(id)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.meCartItemWishlist(id),
        requiresAuth: true,
      );
      final result = CartUndoWishlistResult.fromJson(json ?? const {});
      CartQa.ok(
        'DELETE /me/cart/:id/wishlist',
        detail: 'restored=${CartQa.shortId(result.restoredProductId)}',
      );
      return result;
    } on CatalogApiException catch (e) {
      CartQa.fail(
        'DELETE /me/cart/:id/wishlist',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }
}
