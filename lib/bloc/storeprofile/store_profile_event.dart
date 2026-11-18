part of 'store_profile_bloc.dart';

sealed class StoreProfileEvent extends Equatable {
  const StoreProfileEvent();

  @override
  List<Object?> get props => [];
}

class StoreProfileLoadCollections extends StoreProfileEvent {
  const StoreProfileLoadCollections();
}

/// Background refresh after a warm/cached paint (no shimmer).
///
/// [force] false → prefetcher may skip when TTL still valid (post-warm open).
/// Mutation-driven refreshes keep default [force] true.
class StoreProfileQuietRefreshCollections extends StoreProfileEvent {
  const StoreProfileQuietRefreshCollections({this.force = true});

  final bool force;

  @override
  List<Object?> get props => [force];
}

class StoreProfileLoadMembers extends StoreProfileEvent {
  const StoreProfileLoadMembers();
}

class StoreProfileLoadImportRequestCount extends StoreProfileEvent {
  const StoreProfileLoadImportRequestCount();
}

/// Load / refresh store header meta (`GET /stores/:id`).
///
/// [force] false (default): skip network when a fetch for this store finished
/// within the quiet TTL or join an in-flight fetch (dedupes open remounts).
/// [force] true: always network (follow / privacy / explicit refresh).
class StoreProfileLoadStoreMeta extends StoreProfileEvent {
  const StoreProfileLoadStoreMeta({this.force = false});

  final bool force;

  @override
  List<Object?> get props => [force];
}

/// Shell Profile tab — start meta/collections/members once (deferred on home).
class StoreProfileEnsureInitialCatalogLoads extends StoreProfileEvent {
  const StoreProfileEnsureInitialCatalogLoads();
}

/// Batch I3 — async disk product hydrate right after the first frame.
///
/// Does not wait for the delayed [StoreProfileEnsureInitialCatalogLoads]
/// (~280–320 ms). Memory hits skip this; empty disk does not mark resolved.
class StoreProfileHydrateDiskCache extends StoreProfileEvent {
  const StoreProfileHydrateDiskCache();
}

class StoreProfileAppendImagesRequested extends StoreProfileEvent {
  const StoreProfileAppendImagesRequested(this.imagePaths);

  final List<String> imagePaths;

  @override
  List<Object?> get props => [imagePaths];
}

class StoreProfileDeleteImageRequested extends StoreProfileEvent {
  const StoreProfileDeleteImageRequested(this.imageId);

  final String imageId;

  @override
  List<Object?> get props => [imageId];
}

class StoreProfileAddProductsPressed extends StoreProfileEvent {
  const StoreProfileAddProductsPressed();
}

class StoreProfileProductPublished extends StoreProfileEvent {
  const StoreProfileProductPublished(this.product);

  final StoreProduct product;

  @override
  List<Object?> get props => [product];
}

class StoreProfileProductUpdated extends StoreProfileEvent {
  const StoreProfileProductUpdated(
    this.product, {
    this.replacedListingId,
    this.silent = false,
  });

  final StoreProduct product;
  final String? replacedListingId;

  /// When true: no "Product updated." snackbar and no quiet collections refresh
  /// (used for wishlist like-count bumps).
  final bool silent;

  @override
  List<Object?> get props => [product, replacedListingId, silent];
}

class StoreProfileProductDeleted extends StoreProfileEvent {
  const StoreProfileProductDeleted(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

/// Deletes multiple collections sequentially (selection mode).
class StoreProfileProductsDeleted extends StoreProfileEvent {
  const StoreProfileProductsDeleted(this.productIds);

  final List<String> productIds;

  @override
  List<Object?> get props => [productIds];
}

/// Deletes selected collage/gallery items (`listingId|imageIndex` keys).
///
/// Resolves nested CatalogProduct ids via `DELETE /products/:id`, legacy
/// `img_*` via `POST …/photos/delete`, and empty listings via collection
/// delete. Used by owner photo multi-select.
class StoreProfileItemsDeleted extends StoreProfileEvent {
  const StoreProfileItemsDeleted(this.photoKeys);

  final List<String> photoKeys;

  @override
  List<Object?> get props => [photoKeys];
}

class StoreProfileProductsReplaced extends StoreProfileEvent {
  const StoreProfileProductsReplaced(this.products, {this.silent = false});

  final List<StoreProduct> products;

  /// When true: no quiet collections refresh (keeps API like counts).
  final bool silent;

  @override
  List<Object?> get props => [products, silent];
}

class StoreProfileProductsImported extends StoreProfileEvent {
  const StoreProfileProductsImported(this.products);

  final List<StoreProduct> products;

  @override
  List<Object?> get props => [products];
}

class StoreProfileImportPressed extends StoreProfileEvent {
  const StoreProfileImportPressed();
}

class StoreProfileSharePressed extends StoreProfileEvent {
  const StoreProfileSharePressed();
}

class StoreProfileMorePressed extends StoreProfileEvent {
  const StoreProfileMorePressed();
}

class StoreProfileQuickAddPressed extends StoreProfileEvent {
  const StoreProfileQuickAddPressed();
}

class StoreProfileClearMessage extends StoreProfileEvent {
  const StoreProfileClearMessage();
}

class StoreProfilePendingUploadStarted extends StoreProfileEvent {
  const StoreProfilePendingUploadStarted(this.pending);

  final PendingProductUpload pending;

  @override
  List<Object?> get props => [pending];
}

class StoreProfilePendingUploadProgress extends StoreProfileEvent {
  const StoreProfilePendingUploadProgress({
    required this.pendingId,
    required this.photos,
    this.isCommitting = false,
  });

  final String pendingId;
  final List<PendingPhotoSlot> photos;
  final bool isCommitting;

  @override
  List<Object?> get props => [pendingId, photos, isCommitting];
}

class StoreProfilePendingUploadSucceeded extends StoreProfileEvent {
  const StoreProfilePendingUploadSucceeded({
    required this.pendingId,
    required this.product,
    this.partialMessage,
  });

  final String pendingId;
  final StoreProduct product;
  final String? partialMessage;

  @override
  List<Object?> get props => [pendingId, product, partialMessage];
}

/// After commit success, pending collage finished its one-by-one tick reveal.
class StoreProfilePendingRevealFinished extends StoreProfileEvent {
  const StoreProfilePendingRevealFinished(this.pendingId);

  final String pendingId;

  @override
  List<Object?> get props => [pendingId];
}

class StoreProfilePendingUploadFailed extends StoreProfileEvent {
  const StoreProfilePendingUploadFailed({
    required this.pendingId,
    required this.message,
  });

  final String pendingId;
  final String message;

  @override
  List<Object?> get props => [pendingId, message];
}

class StoreProfilePendingUploadRetry extends StoreProfileEvent {
  const StoreProfilePendingUploadRetry(this.pendingId);

  final String pendingId;

  @override
  List<Object?> get props => [pendingId];
}

/// Hide mid-upload listing from the grid until append batches finish.
class StoreProfileHideInFlightListing extends StoreProfileEvent {
  const StoreProfileHideInFlightListing({
    required this.pendingId,
    required this.listingId,
  });

  final String pendingId;
  final String listingId;

  @override
  List<Object?> get props => [pendingId, listingId];
}

class StoreProfileLoadFollowRequestPreviews extends StoreProfileEvent {
  const StoreProfileLoadFollowRequestPreviews();
}

/// Fill remaining collage frames when album has more than the BE-2 preview
/// page (`productsLimit=9`). Background queue is deferred + throttled after
/// grid paint; swipe may dispatch this immediately for the visible album.
class StoreProfileExpandAlbumCollage extends StoreProfileEvent {
  const StoreProfileExpandAlbumCollage(this.listingId);

  final String listingId;

  @override
  List<Object?> get props => [listingId];
}

/// Parallel wave of album expands (fast-APK style fan-out after first paint).
class StoreProfileExpandAlbumBatch extends StoreProfileEvent {
  const StoreProfileExpandAlbumBatch(this.listingIds);

  final List<String> listingIds;

  @override
  List<Object?> get props => [listingIds];
}

/// Quiet probe of GET /import-targets for other-store product badges.
class StoreProfileProbeImportAvailability extends StoreProfileEvent {
  const StoreProfileProbeImportAvailability();
}

/// Visitor Follow / cancel request / unfollow.
class StoreProfileFollowPressed extends StoreProfileEvent {
  const StoreProfileFollowPressed();
}

class StoreProfileUnfollowPressed extends StoreProfileEvent {
  const StoreProfileUnfollowPressed();
}

class StoreProfileToggleNotifyUploads extends StoreProfileEvent {
  const StoreProfileToggleNotifyUploads();
}
