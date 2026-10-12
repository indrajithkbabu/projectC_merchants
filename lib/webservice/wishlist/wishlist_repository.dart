import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/webservice/wishlist/wishlist_request.dart';

abstract class WishlistRepository {
  Future<PhotoLikeResult> likePhoto({
    required String listingId,
    required String photoId,
    String? storeId,
  });

  Future<PhotoLikeResult> unlikePhoto({
    required String listingId,
    required String photoId,
    String? storeId,
  });

  Future<WishlistPage> fetchWishlist({
    int limit = 20,
    String? cursor,
    String status = 'all',
  });

  Future<WishlistRemoveResult> removeWishlistItem(String wishlistId);
}

class WishlistRepositoryImpl implements WishlistRepository {
  WishlistRepositoryImpl({required WishlistRequest request})
    : _request = request;

  static const _tag = 'WishlistRepository';

  final WishlistRequest _request;

  @override
  Future<PhotoLikeResult> likePhoto({
    required String listingId,
    required String photoId,
    String? storeId,
  }) {
    AppLog.d(_tag, 'likePhoto listing=$listingId photo=$photoId');
    return _request.likePhoto(
      listingId: listingId,
      photoId: photoId,
      storeId: storeId,
    );
  }

  @override
  Future<PhotoLikeResult> unlikePhoto({
    required String listingId,
    required String photoId,
    String? storeId,
  }) {
    AppLog.d(_tag, 'unlikePhoto listing=$listingId photo=$photoId');
    return _request.unlikePhoto(
      listingId: listingId,
      photoId: photoId,
      storeId: storeId,
    );
  }

  @override
  Future<WishlistPage> fetchWishlist({
    int limit = 20,
    String? cursor,
    String status = 'all',
  }) {
    return _request.fetchWishlist(
      limit: limit,
      cursor: cursor,
      status: status,
    );
  }

  @override
  Future<WishlistRemoveResult> removeWishlistItem(String wishlistId) {
    AppLog.d(_tag, 'removeWishlistItem id=$wishlistId');
    return _request.removeWishlistItem(wishlistId);
  }
}
