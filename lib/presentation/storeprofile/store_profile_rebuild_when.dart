import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';

/// Batch 4 — Discover rebuild predicates for [StoreProfileRoute].
///
/// Kept as library functions so header / grid / dock can rebuild independently
/// and unit tests can lock the contracts without pumping widgets.

/// Shell layout only: own-store vs visitor, follow-dock visibility, store id.
bool storeProfileShellBuildWhen(
  StoreProfileState prev,
  StoreProfileState curr,
) {
  return prev.storeId != curr.storeId ||
      prev.isOwnStore != curr.isOwnStore ||
      prev.followStatus != curr.followStatus;
}

/// Telegram header + identity chrome (not the product sliver).
bool storeProfileHeaderBuildWhen(
  StoreProfileState prev,
  StoreProfileState curr,
) {
  return prev.storeId != curr.storeId ||
      prev.storeName != curr.storeName ||
      prev.coverImageUrl != curr.coverImageUrl ||
      prev.storeImages != curr.storeImages ||
      prev.followerCount != curr.followerCount ||
      prev.apiProductCount != curr.apiProductCount ||
      prev.isOwnStore != curr.isOwnStore ||
      prev.canViewContent != curr.canViewContent ||
      prev.privacy != curr.privacy ||
      prev.viewerHasOwnStore != curr.viewerHasOwnStore ||
      prev.avatarColor != curr.avatarColor ||
      prev.overrideStoreLink != curr.overrideStoreLink;
}

/// Product grid, private gate, follow-requests banner (scroll content).
bool storeProfileGridBuildWhen(StoreProfileState prev, StoreProfileState curr) {
  return prev.storeId != curr.storeId ||
      prev.products != curr.products ||
      prev.productsDetailed != curr.productsDetailed ||
      prev.pendingUploads != curr.pendingUploads ||
      prev.isLoadingProducts != curr.isLoadingProducts ||
      prev.productsResolved != curr.productsResolved ||
      prev.isLoadingStoreMeta != curr.isLoadingStoreMeta ||
      prev.isOwnStore != curr.isOwnStore ||
      prev.canViewContent != curr.canViewContent ||
      prev.followStatus != curr.followStatus ||
      prev.storeName != curr.storeName ||
      prev.deletingProductId != curr.deletingProductId ||
      prev.listingAvailability != curr.listingAvailability ||
      prev.showFollowRequestsBanner != curr.showFollowRequestsBanner ||
      prev.pendingFollowRequestCount != curr.pendingFollowRequestCount ||
      prev.followRequestPreviewNames != curr.followRequestPreviewNames ||
      prev.privacy != curr.privacy;
}

/// Visitor photo-selection dock needs product lists + import eligibility.
bool storeProfileVisitorOverlayBuildWhen(
  StoreProfileState prev,
  StoreProfileState curr,
) {
  return prev.products != curr.products ||
      prev.productsDetailed != curr.productsDetailed ||
      prev.viewerHasOwnStore != curr.viewerHasOwnStore ||
      prev.canViewContent != curr.canViewContent ||
      prev.isOwnStore != curr.isOwnStore;
}

/// Bottom Follow / Requested dock label + busy spinner.
bool storeProfileFollowDockBuildWhen(
  StoreProfileState prev,
  StoreProfileState curr,
) {
  return prev.followStatus != curr.followStatus ||
      prev.isFollowBusy != curr.isFollowBusy ||
      prev.isOwnStore != curr.isOwnStore;
}
