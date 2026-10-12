import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class WishlistRequest {
  WishlistRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// PUT `/products/:listingId/photos/:photoId/like`
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

  /// DELETE `/products/:listingId/photos/:photoId/like`
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

  /// GET `/wishlist`
  Future<WishlistPage> fetchWishlist({
    int limit = 20,
    String? cursor,
    String status = 'all',
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'status': status,
    };
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
}
