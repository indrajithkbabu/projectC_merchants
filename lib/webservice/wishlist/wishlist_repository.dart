import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/webservice/wishlist/wishlist_request.dart';

abstract class WishlistRepository {
  /// Public product like (`PUT/DELETE /products/:id/like`).
  Future<ProductLikeResult> likeProduct({required String productId});

  Future<ProductLikeResult> unlikeProduct({required String productId});

  /// Private wishlist bookmark for a product.
  Future<WishlistToggleResult> addWishlistProduct({required String productId});

  /// Bulk private wishlist add (`POST /wishlist/batch`).
  Future<WishlistBatchAddResult> addWishlistProductsBatch({
    required List<String> productIds,
  });

  Future<WishlistToggleResult> removeWishlistProduct({
    required String productId,
  });

  /// Bulk private wishlist remove (`DELETE /wishlist/batch`).
  Future<WishlistBatchRemoveResult> removeWishlistProductsBatch({
    required List<String> productIds,
  });

  /// Private wishlist bookmark for a collection.
  Future<WishlistToggleResult> addWishlistCollection({
    required String collectionId,
  });

  Future<WishlistToggleResult> removeWishlistCollection({
    required String collectionId,
  });

  /// Legacy photo like aliases.
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

  /// Public collection like (optional [subGroupId] scope).
  Future<CollectionLikeResult> likeCollection({
    required String listingId,
    String? storeId,
    String? subGroupId,
  });

  Future<CollectionLikeResult> unlikeCollection({
    required String listingId,
    String? storeId,
    String? subGroupId,
  });

  Future<WishlistPage> fetchWishlist({
    int limit = 20,
    String? cursor,
  });

  Future<WishlistRemoveResult> removeWishlistItem(String wishlistId);
}

class WishlistRepositoryImpl implements WishlistRepository {
  WishlistRepositoryImpl({required WishlistRequest request})
    : _request = request;

  static const _tag = 'WishlistRepository';

  final WishlistRequest _request;

  @override
  Future<ProductLikeResult> likeProduct({required String productId}) {
    AppLog.d(_tag, 'likeProduct id=$productId');
    return _request.likeProduct(productId: productId);
  }

  @override
  Future<ProductLikeResult> unlikeProduct({required String productId}) {
    AppLog.d(_tag, 'unlikeProduct id=$productId');
    return _request.unlikeProduct(productId: productId);
  }

  @override
  Future<WishlistToggleResult> addWishlistProduct({
    required String productId,
  }) {
    AppLog.d(_tag, 'addWishlistProduct id=$productId');
    return _request.addWishlistProduct(productId: productId);
  }

  @override
  Future<WishlistBatchAddResult> addWishlistProductsBatch({
    required List<String> productIds,
  }) {
    AppLog.d(_tag, 'addWishlistProductsBatch count=${productIds.length}');
    return _request.addWishlistProductsBatch(productIds: productIds);
  }

  @override
  Future<WishlistToggleResult> removeWishlistProduct({
    required String productId,
  }) {
    AppLog.d(_tag, 'removeWishlistProduct id=$productId');
    return _request.removeWishlistProduct(productId: productId);
  }

  @override
  Future<WishlistBatchRemoveResult> removeWishlistProductsBatch({
    required List<String> productIds,
  }) {
    AppLog.d(_tag, 'removeWishlistProductsBatch count=${productIds.length}');
    return _request.removeWishlistProductsBatch(productIds: productIds);
  }

  @override
  Future<WishlistToggleResult> addWishlistCollection({
    required String collectionId,
  }) {
    AppLog.d(_tag, 'addWishlistCollection id=$collectionId');
    return _request.addWishlistCollection(collectionId: collectionId);
  }

  @override
  Future<WishlistToggleResult> removeWishlistCollection({
    required String collectionId,
  }) {
    AppLog.d(_tag, 'removeWishlistCollection id=$collectionId');
    return _request.removeWishlistCollection(collectionId: collectionId);
  }

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
  Future<CollectionLikeResult> likeCollection({
    required String listingId,
    String? storeId,
    String? subGroupId,
  }) {
    AppLog.d(
      _tag,
      'likeCollection listing=$listingId store=$storeId sub=$subGroupId',
    );
    return _request.likeCollection(
      listingId: listingId,
      storeId: storeId,
      subGroupId: subGroupId,
    );
  }

  @override
  Future<CollectionLikeResult> unlikeCollection({
    required String listingId,
    String? storeId,
    String? subGroupId,
  }) {
    AppLog.d(
      _tag,
      'unlikeCollection listing=$listingId store=$storeId sub=$subGroupId',
    );
    return _request.unlikeCollection(
      listingId: listingId,
      storeId: storeId,
      subGroupId: subGroupId,
    );
  }

  @override
  Future<WishlistPage> fetchWishlist({
    int limit = 20,
    String? cursor,
  }) {
    return _request.fetchWishlist(
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<WishlistRemoveResult> removeWishlistItem(String wishlistId) {
    AppLog.d(_tag, 'removeWishlistItem id=$wishlistId');
    return _request.removeWishlistItem(wishlistId);
  }
}
