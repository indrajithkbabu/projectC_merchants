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

  // Collections (multipart photos on create/update)
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

  // Imports
  static const String importTargets = '/import-targets';
  static const String importRequests = '/import-requests';
  static String storeImportRequests(String storeId) =>
      '/stores/$storeId/import-requests';
  static String importDecision(String requestId) =>
      '/import-requests/$requestId/decision';
}
