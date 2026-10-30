/// Catalog API paths relative to flavor [baseUrl] (`…/v1/catalog`).
class Endpoints {
  Endpoints._();

  // Ops
  static const String ready = '/ready';

  // Auth
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Profile / onboarding
  static const String me = '/me';
  static const String profileImage = '/me/profile-image';
  static const String skipStore = '/me/onboarding/skip-store';

  // Stores / home
  static const String home = '/home';
  static const String stores = '/stores';
  static String storeById(String storeId) => '/stores/$storeId';
  static String storeBySlug(String slug) => '/stores/by-slug/$slug';
  static String slugAvailability(String slug) =>
      '/store-slugs/$slug/availability';
  static String storeImages(String storeId) => '/stores/$storeId/images';
  static String storeImage(String storeId, String imageId) =>
      '/stores/$storeId/images/$imageId';
  static String storeContacts(String storeId) => '/stores/$storeId/contacts';
  static String storeMembers(String storeId) => '/stores/$storeId/members';
  static String storeMember(String storeId, String userId) =>
      '/stores/$storeId/members/$userId';
  static String storeLeave(String storeId) => '/stores/$storeId/leave';
  static String storePrivacy(String storeId) => '/stores/$storeId/privacy';
  static String storeWastageMarkup(String storeId) =>
      '/stores/$storeId/wastage-markup';
  static String storeFollow(String storeId) => '/stores/$storeId/follow';
  static String storeFollowRequests(String storeId) =>
      '/stores/$storeId/follow-requests';
  static String storeFollowRequestAccept(
    String storeId,
    String followerUserId,
  ) => '/stores/$storeId/follow-requests/$followerUserId/accept';
  static String storeFollowRequestReject(
    String storeId,
    String followerUserId,
  ) => '/stores/$storeId/follow-requests/$followerUserId/reject';
  static String storeFollowers(String storeId) => '/stores/$storeId/followers';
  static String storeFollowing(String storeId) => '/stores/$storeId/following';
  static String storeFollower(String storeId, String followerUserId) =>
      '/stores/$storeId/followers/$followerUserId';

  // Photo upload signing (jewel flow) + store-scoped aliases
  static const String uploadsSign = '/uploads/sign';
  static String storeUploadsSign(String storeId) =>
      '/stores/$storeId/uploads/sign';
  static String storeUploadsPresign(String storeId) =>
      '/stores/$storeId/uploads/presign';

  // Products (batch create, store feed / list, single product)
  static String storeProducts(String storeId) => '/stores/$storeId/products';
  static String storeProductsBatch(String storeId) =>
      '/stores/$storeId/products/batch';
  static String storeFeed(String storeId) => '/stores/$storeId/feed';
  static String productById(String productId) => '/products/$productId';
  static String productPatch(String productId) => '/products/$productId';

  // Collections (direct S3 presign + JSON commit; multipart kept for legacy)
  static String storeCollections(String storeId) =>
      '/stores/$storeId/collections';
  static String storeCollection(String storeId, String listingId) =>
      '/stores/$storeId/collections/$listingId';
  static String storeCollectionPhotos(String storeId, String listingId) =>
      '/stores/$storeId/collections/$listingId/photos';
  static String storeCollectionPhoto(
    String storeId,
    String listingId,
    String photoId,
  ) => '/stores/$storeId/collections/$listingId/photos/$photoId';
  static String storeCollectionPhotosDelete(String storeId, String listingId) =>
      '/stores/$storeId/collections/$listingId/photos/delete';
  static String storeCollectionPhotosMove(String storeId, String listingId) =>
      '/stores/$storeId/collections/$listingId/photos/move';
  static String storeCollectionSubGroups(String storeId, String listingId) =>
      '/stores/$storeId/collections/$listingId/subgroups';
  static String storeCollectionSubGroup(
    String storeId,
    String listingId,
    String subGroupId,
  ) => '/stores/$storeId/collections/$listingId/subgroups/$subGroupId';

  // Search & filter
  static const String searchMeta = '/search/meta';
  static const String searchSuggest = '/search/suggest';
  static const String search = '/search';
  static String storeFacets(String storeId) => '/stores/$storeId/facets';
  static String storeSearch(String storeId) => '/stores/$storeId/search';

  // Public like (increments likeCount; in-app notify — not wishlist)
  static String productLike(String productId) => '/products/$productId/like';
  static String collectionLike(String collectionId) =>
      '/collections/$collectionId/like';

  /// Legacy photo like aliases (still supported by backend).
  static String productPhotoLike(String listingId, String photoId) =>
      '/products/$listingId/photos/$photoId/like';
  static String storeCollectionPhotoLike(
    String storeId,
    String listingId,
    String photoId,
  ) => '/stores/$storeId/collections/$listingId/photos/$photoId/like';

  /// Store-scoped collection like (optional subgroup path).
  static String storeCollectionLike(String storeId, String listingId) =>
      '/stores/$storeId/collections/$listingId/like';

  static String storeCollectionSubGroupLike(
    String storeId,
    String listingId,
    String subGroupId,
  ) =>
      '/stores/$storeId/collections/$listingId/subgroups/$subGroupId/like';

  /// Alias kept for older call sites → product-level like.
  static String productListingLike(String listingId) => productLike(listingId);

  // Private wishlist (no notifications / no public counters)
  static const String wishlist = '/wishlist';
  /// Bulk add/remove — `POST` / `DELETE` with `{ productIds: [...] }`.
  static const String wishlistBatch = '/wishlist/batch';
  static String wishlistItem(String wishlistId) => '/wishlist/$wishlistId';
  static String wishlistProduct(String productId) =>
      '/wishlist/products/$productId';
  static String wishlistCollection(String collectionId) =>
      '/wishlist/collections/$collectionId';
  static String productWishlist(String productId) =>
      '/products/$productId/wishlist';
  static String collectionWishlist(String collectionId) =>
      '/collections/$collectionId/wishlist';

  // View counting (batch beacon)
  static const String views = '/views';

  // Push device tokens (FCM)
  static const String devicesToken = '/devices/token';

  // Activity feed (in-app)
  static const String activity = '/activity';
  static const String activityUnreadCount = '/activity/unread-count';
  static const String activityRead = '/activity/read';

  // Imports (legacy select path still used by store_import_select_route)
  static const String importTargets = '/import-targets';
  static const String importRequests = '/import-requests';
  static String storeImportRequests(String storeId) =>
      '/stores/$storeId/import-requests';
  static String importDecision(String requestId) =>
      '/import-requests/$requestId/decision';

  /// Quick import batch — `POST /stores/:storeId/imports` (quick-import-api.md).
  static String storeImports(String storeId) => '/stores/$storeId/imports';

  /// Store-scoped decision — `POST …/import-requests/:id/decision`.
  static String storeImportRequestDecision(String storeId, String requestId) =>
      '/stores/$storeId/import-requests/$requestId/decision';

  /// Cancel pending Sent request — `DELETE …/import-requests/:id`.
  static String storeImportRequest(String storeId, String requestId) =>
      '/stores/$storeId/import-requests/$requestId';

  /// Cancel pending Sent request — `POST …/import-requests/:id/cancel`.
  static String storeImportRequestCancel(String storeId, String requestId) =>
      '/stores/$storeId/import-requests/$requestId/cancel';

  static String storeProductInsights(String storeId, String productId) =>
      '/stores/$storeId/products/$productId/insights';
}
