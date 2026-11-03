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
class StoreProfileQuietRefreshCollections extends StoreProfileEvent {
  const StoreProfileQuietRefreshCollections();
}

class StoreProfileLoadMembers extends StoreProfileEvent {
  const StoreProfileLoadMembers();
}

class StoreProfileLoadImportRequestCount extends StoreProfileEvent {
  const StoreProfileLoadImportRequestCount();
}

class StoreProfileLoadStoreMeta extends StoreProfileEvent {
  const StoreProfileLoadStoreMeta();
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
  const StoreProfileProductsReplaced(
    this.products, {
    this.silent = false,
  });

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
