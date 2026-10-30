import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

class WishlistRequest {
  WishlistRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// PUT `/products/:productId/like` — public like (not wishlist).
  /// Falls back to POST alias if PUT is rejected.
  Future<ProductLikeResult> likeProduct({required String productId}) async {
    BeVerify.step(
      'L PUT /products/:id/like',
      detail: 'id=${BeVerify.shortId(productId)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.put,
        path: Endpoints.productLike(productId),
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      final result = ProductLikeResult.fromJson(json ?? const {});
      BeVerify.ok(
        'product like',
        detail:
            'liked=${result.liked} count=${result.likeCount} '
            'already=${result.alreadyLiked}',
      );
      return result;
    } on CatalogApiException catch (e) {
      if (e.statusCode != 404 &&
          e.statusCode != 405 &&
          e.code != 'NOT_FOUND') {
        BeVerify.fail(
          'product like',
          detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
        );
        rethrow;
      }
      BeVerify.info('product like PUT miss → POST', detail: '${e.statusCode}');
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.productLike(productId),
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      final result = ProductLikeResult.fromJson(json ?? const {});
      BeVerify.ok(
        'product like POST',
        detail: 'liked=${result.liked} count=${result.likeCount}',
      );
      return result;
    }
  }

  /// DELETE `/products/:productId/like`
  Future<ProductLikeResult> unlikeProduct({required String productId}) async {
    BeVerify.step(
      'L DELETE /products/:id/like',
      detail: 'id=${BeVerify.shortId(productId)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.productLike(productId),
        requiresAuth: true,
      );
      final result = ProductLikeResult.fromJson(json ?? const {});
      BeVerify.ok(
        'product unlike',
        detail: 'liked=${result.liked} count=${result.likeCount}',
      );
      return result;
    } on CatalogApiException catch (e) {
      BeVerify.fail(
        'product unlike',
        detail: 'status=${e.statusCode} code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// POST `/wishlist/products/:productId` — private bookmark.
  ///
  /// Aliases (docs): PUT same path, POST `/photos/:id/wishlist`,
  /// POST `/wishlist` with `{ "productId" }`.
  Future<WishlistToggleResult> addWishlistProduct({
    required String productId,
  }) async {
    final id = productId.trim();
    BeVerify.step(
      '5 POST /wishlist/products/:id',
      detail: 'id=${BeVerify.shortId(id)}',
    );
    try {
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.wishlistProduct(id),
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      final result = WishlistToggleResult.fromJson(json ?? const {});
      BeVerify.ok(
        'wishlist path POST',
        detail:
            'wishlisted=${result.wishlisted} '
            'already=${result.alreadyWishlisted} '
            'productId=${BeVerify.shortId(result.productId)}',
      );
      return result;
    } on CatalogApiException catch (e) {
      final nullProduct =
          e.message.toLowerCase().contains('product: null') ||
          e.message.toLowerCase().contains('product:null');
      if (nullProduct) {
        BeVerify.fail(
          'wishlist product:null still present',
          detail: 'status=${e.statusCode} ${e.message}',
        );
      } else {
        BeVerify.info(
          'wishlist path miss → alias',
          detail: 'status=${e.statusCode} code=${e.code}',
        );
      }
      // Body alias — also used when path insert fails with product:null / 409.
      if (e.statusCode == 409 ||
          e.statusCode == 404 ||
          e.code == 'NOT_FOUND' ||
          e.code == 'CONFLICT') {
        try {
          final json = await _api.sendJson(
            method: HttpMethod.post,
            path: Endpoints.wishlist,
            body: <String, dynamic>{'productId': id},
            requiresAuth: true,
          );
          final result = WishlistToggleResult.fromJson(json ?? const {});
          BeVerify.ok(
            'wishlist body alias',
            detail:
                'wishlisted=${result.wishlisted} '
                'already=${result.alreadyWishlisted}',
          );
          return result;
        } on CatalogApiException catch (bodyErr) {
          if (bodyErr.statusCode == 404 || bodyErr.code == 'NOT_FOUND') {
            final json = await _api.sendJson(
              method: HttpMethod.post,
              path: Endpoints.productWishlist(id),
              body: const <String, dynamic>{},
              requiresAuth: true,
            );
            final result = WishlistToggleResult.fromJson(json ?? const {});
            BeVerify.ok(
              'wishlist photos alias',
              detail: 'wishlisted=${result.wishlisted}',
            );
            return result;
          }
          // Idempotent duplicate after a good write — treat as already bookmarked.
          if (_isWishlistDuplicateConflict(bodyErr)) {
            BeVerify.ok(
              'wishlist idempotent 409',
              detail: 'alreadyWishlisted via body alias',
            );
            return WishlistToggleResult(
              wishlisted: true,
              productId: id,
              alreadyWishlisted: true,
            );
          }
          BeVerify.fail(
            'wishlist aliases exhausted',
            detail: 'status=${bodyErr.statusCode} ${bodyErr.message}',
          );
          rethrow;
        }
      }
      if (_isWishlistDuplicateConflict(e)) {
        BeVerify.ok(
          'wishlist idempotent 409',
          detail: 'alreadyWishlisted via path',
        );
        return WishlistToggleResult(
          wishlisted: true,
          productId: id,
          alreadyWishlisted: true,
        );
      }
      rethrow;
    }
  }

  bool _isWishlistDuplicateConflict(CatalogApiException e) {
    if (e.statusCode != 409 && e.code != 'CONFLICT') return false;
    final msg = e.message.toLowerCase();
    // Real idempotent dup on a valid product — OK to treat as already wishlisted.
    // Still surface product:null dupes (BE bug) unless body alias already tried.
    if (msg.contains('product: null') || msg.contains('product:null')) {
      return false;
    }
    return msg.contains('duplicate') ||
        msg.contains('e11000') ||
        msg.contains('already');
  }

  static const int _wishlistBatchMax = 100;

  /// POST `/wishlist/batch` — multi-select add (`productIds`, max 100).
  /// Falls back to `POST /wishlist` with the same array body if `/batch` 404s.
  Future<WishlistBatchAddResult> addWishlistProductsBatch({
    required List<String> productIds,
  }) async {
    final ids = <String>[
      for (final raw in productIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    ];
    if (ids.isEmpty) {
      return const WishlistBatchAddResult();
    }

    WishlistBatchAddResult? merged;
    for (var i = 0; i < ids.length; i += _wishlistBatchMax) {
      final end =
          i + _wishlistBatchMax > ids.length
              ? ids.length
              : i + _wishlistBatchMax;
      final chunk = ids.sublist(i, end);
      BeVerify.step(
        'W POST /wishlist/batch',
        detail: 'count=${chunk.length} ids=${chunk.map(BeVerify.shortId).join(",")}',
      );
      final part = await _postWishlistBatchChunk(chunk);
      merged = merged == null ? part : _mergeBatchAdd(merged, part);
    }
    final result = merged ?? const WishlistBatchAddResult();
    BeVerify.ok(
      'wishlist batch add',
      detail:
          'added=${result.addedCount} already=${result.alreadyWishlistedCount} '
          'failed=${result.failedCount}',
    );
    return result;
  }

  Future<WishlistBatchAddResult> _postWishlistBatchChunk(
    List<String> chunk,
  ) async {
    final body = <String, dynamic>{'productIds': chunk};
    try {
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.wishlistBatch,
        body: body,
        requiresAuth: true,
      );
      return WishlistBatchAddResult.fromJson(json ?? const {});
    } on CatalogApiException catch (e) {
      if (e.statusCode == 404 || e.code == 'NOT_FOUND') {
        BeVerify.info(
          'wishlist batch miss → POST /wishlist array',
          detail: 'status=${e.statusCode}',
        );
        final json = await _api.sendJson(
          method: HttpMethod.post,
          path: Endpoints.wishlist,
          body: body,
          requiresAuth: true,
        );
        return WishlistBatchAddResult.fromJson(json ?? const {});
      }
      rethrow;
    }
  }

  WishlistBatchAddResult _mergeBatchAdd(
    WishlistBatchAddResult a,
    WishlistBatchAddResult b,
  ) {
    return WishlistBatchAddResult(
      success: a.success && b.success,
      totalRequested: a.totalRequested + b.totalRequested,
      addedCount: a.addedCount + b.addedCount,
      alreadyWishlistedCount:
          a.alreadyWishlistedCount + b.alreadyWishlistedCount,
      failedCount: a.failedCount + b.failedCount,
      items: [...a.items, ...b.items],
    );
  }

  /// DELETE `/wishlist/batch` — multi-select remove by product ids (max 100).
  Future<WishlistBatchRemoveResult> removeWishlistProductsBatch({
    required List<String> productIds,
  }) async {
    final ids = <String>[
      for (final raw in productIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    ];
    if (ids.isEmpty) {
      return const WishlistBatchRemoveResult();
    }

    WishlistBatchRemoveResult? merged;
    for (var i = 0; i < ids.length; i += _wishlistBatchMax) {
      final end =
          i + _wishlistBatchMax > ids.length
              ? ids.length
              : i + _wishlistBatchMax;
      final chunk = ids.sublist(i, end);
      BeVerify.step(
        'W DELETE /wishlist/batch',
        detail: 'count=${chunk.length}',
      );
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.wishlistBatch,
        body: <String, dynamic>{'productIds': chunk},
        requiresAuth: true,
      );
      final part = WishlistBatchRemoveResult.fromJson(json ?? const {});
      merged =
          merged == null
              ? part
              : WishlistBatchRemoveResult(
                success: merged.success && part.success,
                removedCount: merged.removedCount + part.removedCount,
                productIds: [...merged.productIds, ...part.productIds],
              );
    }
    return merged ?? const WishlistBatchRemoveResult();
  }

  /// DELETE `/wishlist/products/:productId`
  Future<WishlistToggleResult> removeWishlistProduct({
    required String productId,
  }) async {
    try {
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.wishlistProduct(productId),
        requiresAuth: true,
      );
      return WishlistToggleResult.fromJson(json ?? const {});
    } on CatalogApiException catch (e) {
      if (e.statusCode != 404 && e.code != 'NOT_FOUND') rethrow;
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.productWishlist(productId),
        requiresAuth: true,
      );
      return WishlistToggleResult.fromJson(json ?? const {});
    }
  }

  /// Legacy PUT `/products/:listingId/photos/:photoId/like`
  Future<PhotoLikeResult> likePhoto({
    required String listingId,
    required String photoId,
    String? storeId,
  }) async {
    final path =
        (storeId != null && storeId.trim().isNotEmpty)
            ? Endpoints.storeCollectionPhotoLike(
              storeId.trim(),
              listingId,
              photoId,
            )
            : Endpoints.productPhotoLike(listingId, photoId);
    final json = await _api.sendJson(
      method: HttpMethod.put,
      path: path,
      body: const <String, dynamic>{},
      requiresAuth: true,
    );
    return PhotoLikeResult.fromJson(json ?? const {});
  }

  /// Legacy DELETE `/products/:listingId/photos/:photoId/like`
  Future<PhotoLikeResult> unlikePhoto({
    required String listingId,
    required String photoId,
    String? storeId,
  }) async {
    final path =
        (storeId != null && storeId.trim().isNotEmpty)
            ? Endpoints.storeCollectionPhotoLike(
              storeId.trim(),
              listingId,
              photoId,
            )
            : Endpoints.productPhotoLike(listingId, photoId);
    final json = await _api.sendJson(
      method: HttpMethod.delete,
      path: path,
      requiresAuth: true,
    );
    return PhotoLikeResult.fromJson(json ?? const {});
  }

  /// PUT `/collections/:id/like` (POST alias) — public collection like.
  Future<CollectionLikeResult> likeCollection({
    required String listingId,
    String? storeId,
    String? subGroupId,
  }) async {
    final sub = subGroupId?.trim();
    final store = storeId?.trim();
    late final String path;
    Map<String, String>? query;
    if (store != null && store.isNotEmpty) {
      if (sub != null && sub.isNotEmpty) {
        path = Endpoints.storeCollectionSubGroupLike(store, listingId, sub);
      } else {
        path = Endpoints.storeCollectionLike(store, listingId);
      }
    } else {
      path = Endpoints.collectionLike(listingId);
      if (sub != null && sub.isNotEmpty) {
        query = {'subGroupId': sub};
      }
    }
    try {
      final json = await _api.sendJson(
        method: HttpMethod.put,
        path: path,
        query: query,
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      return CollectionLikeResult.fromJson(json ?? const {});
    } on CatalogApiException catch (e) {
      if (e.statusCode != 404 &&
          e.statusCode != 405 &&
          e.code != 'NOT_FOUND') {
        rethrow;
      }
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: path,
        query: query,
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      return CollectionLikeResult.fromJson(json ?? const {});
    }
  }

  /// DELETE collection like.
  Future<CollectionLikeResult> unlikeCollection({
    required String listingId,
    String? storeId,
    String? subGroupId,
  }) async {
    final sub = subGroupId?.trim();
    final store = storeId?.trim();
    late final String path;
    Map<String, String>? query;
    if (store != null && store.isNotEmpty) {
      if (sub != null && sub.isNotEmpty) {
        path = Endpoints.storeCollectionSubGroupLike(store, listingId, sub);
      } else {
        path = Endpoints.storeCollectionLike(store, listingId);
      }
    } else {
      path = Endpoints.collectionLike(listingId);
      if (sub != null && sub.isNotEmpty) {
        query = {'subGroupId': sub};
      }
    }
    final json = await _api.sendJson(
      method: HttpMethod.delete,
      path: path,
      query: query,
      requiresAuth: true,
    );
    return CollectionLikeResult.fromJson(json ?? const {});
  }

  /// GET `/wishlist` — docs: `limit` / `cursor` only.
  Future<WishlistPage> fetchWishlist({
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.wishlist,
      query: query,
      requiresAuth: true,
    );
    return WishlistPage.fromJson(json ?? const {});
  }

  /// DELETE `/wishlist/:wishlistId`
  Future<WishlistRemoveResult> removeWishlistItem(String wishlistId) async {
    final json = await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.wishlistItem(wishlistId),
      requiresAuth: true,
    );
    return WishlistRemoveResult.fromJson(json ?? const {});
  }

  /// POST `/wishlist/collections/:collectionId` (+ collection / body aliases).
  Future<WishlistToggleResult> addWishlistCollection({
    required String collectionId,
  }) async {
    final id = collectionId.trim();
    try {
      final json = await _api.sendJson(
        method: HttpMethod.post,
        path: Endpoints.wishlistCollection(id),
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      return WishlistToggleResult.fromJson(json ?? const {});
    } on CatalogApiException catch (e) {
      if (e.statusCode == 409 ||
          e.statusCode == 404 ||
          e.code == 'NOT_FOUND' ||
          e.code == 'CONFLICT') {
        try {
          final json = await _api.sendJson(
            method: HttpMethod.post,
            path: Endpoints.wishlist,
            body: <String, dynamic>{'collectionId': id},
            requiresAuth: true,
          );
          return WishlistToggleResult.fromJson(json ?? const {});
        } on CatalogApiException catch (bodyErr) {
          if (bodyErr.statusCode == 404 || bodyErr.code == 'NOT_FOUND') {
            final json = await _api.sendJson(
              method: HttpMethod.post,
              path: Endpoints.collectionWishlist(id),
              body: const <String, dynamic>{},
              requiresAuth: true,
            );
            return WishlistToggleResult.fromJson(json ?? const {});
          }
          if (_isWishlistDuplicateConflict(bodyErr)) {
            return WishlistToggleResult(
              wishlisted: true,
              collectionId: id,
              alreadyWishlisted: true,
            );
          }
          rethrow;
        }
      }
      if (_isWishlistDuplicateConflict(e)) {
        return WishlistToggleResult(
          wishlisted: true,
          collectionId: id,
          alreadyWishlisted: true,
        );
      }
      rethrow;
    }
  }

  /// DELETE `/wishlist/collections/:collectionId` (+ collection alias).
  Future<WishlistToggleResult> removeWishlistCollection({
    required String collectionId,
  }) async {
    try {
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.wishlistCollection(collectionId),
        requiresAuth: true,
      );
      return WishlistToggleResult.fromJson(json ?? const {});
    } on CatalogApiException catch (e) {
      if (e.statusCode != 404 && e.code != 'NOT_FOUND') rethrow;
      final json = await _api.sendJson(
        method: HttpMethod.delete,
        path: Endpoints.collectionWishlist(collectionId),
        requiresAuth: true,
      );
      return WishlistToggleResult.fromJson(json ?? const {});
    }
  }
}
