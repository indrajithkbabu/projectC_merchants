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
  });

  final StoreProduct product;
  final String? replacedListingId;

  @override
  List<Object?> get props => [product, replacedListingId];
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

class StoreProfileProductsReplaced extends StoreProfileEvent {
  const StoreProfileProductsReplaced(this.products);

  final List<StoreProduct> products;

  @override
  List<Object?> get props => [products];
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

/// Quiet probe of GET /import-targets for other-store product badges.
class StoreProfileProbeImportAvailability extends StoreProfileEvent {
  const StoreProfileProbeImportAvailability();
}
