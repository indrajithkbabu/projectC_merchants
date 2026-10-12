# Privacy Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/privacy/`.

## Mandatory Update Rule
- If Account privacy UI, confirm sheets, visibility matrix copy, follow-request
  flows, Followers/Following lists, Wishlist, Activity feed, or requirements
  change, update this file in the same PR.

## Scope

### Account privacy (pages 01–02)
- **Account privacy** route: Public / Private radios + "What a non-follower sees"
  matrix. Entered from **My store → Settings** (`settings_route`) when the user
  has an own store (individuals have no privacy setting).
- Switching always opens a confirm sheet with consequences + pending-request
  count before applying. Toast confirms the new state.
- **Backend:** `PATCH /stores/:storeId/privacy` via `StoreRepository.patchStorePrivacy`.
  Local cache in `StorePrivacyPreferences` + `AppSettingsStorage` (default Public).
  Opening the screen hydrates from `GET /stores/:id` (`privacy`,
  `pendingRequestsCount`). Do not move product data on switch — visibility is
  evaluated at read time from `store.privacy` + follow relationship.
  Visitor gating on store profile uses `canViewContent` / Follow CTAs (see
  storeprofile FEATURE_CONVENTIONS).

### Follow requests (pages 03–06)
- **Banner** (`privacy_widgets/follow_requests_banner.dart`): overlapping
  initials (up to 2), title, subtitle (`Name` or `Name + N others`), blue count
  badge. Shown from own-store chrome / Activity when `pendingCount > 0`.
- **Inbox** (`follow_requests_route.dart`): load via
  `StoreRepository.fetchFollowRequests`. Local filter All | Stores | Individuals.
  Confirm → `acceptFollowRequest` (row shows Approved). Delete →
  `rejectFollowRequest` (row shows Request deleted). Tap name → requester
  profile. Errors via `CatalogErrorMapper`.
- **Requester profile** (`follow_requester_profile_route.dart`): pinned decision
  card + individual (circular avatar, lock note) or store (square logo, optional
  minimal `fetchStore` for privacy/counts/`canViewContent`). Pass `readOnly: true`
  when opened from Followers list (hides Confirm/Delete). No product grid
  required in this slice.
- **Models:** `FollowRequestItem` / `FollowRequestPage` /
  `FollowRequestUiStatus` in `lib/models/catalog/follow_api_models.dart`.
- **No** `SocialGraphService` mock — use `StoreRepository` via `ServiceLocator`.

### Followers & Following lists (page 07)
- **Route** (`followers_following_route.dart`): owner-only. Tabs
  `{count} Followers` / `{count} Following`, search field, row list.
- **Followers tab:** Store (rounded-square + blue Store pill) or Individual
  (circle + grey Individual pill). Trailing **Remove** →
  `StoreRepository.removeFollower` (silent; no notify). Tap store → store
  profile; tap individual → requester profile with `readOnly: true`.
- **Following tab:** stores this store follows. Trailing **Following** or
  **Requested** → `unfollowStore` (unfollow / cancel request). Tap → store
  profile.
- **API:** `GET .../followers`, `GET .../following`, `DELETE .../followers/:userId`.
- **Entry:** own-store header Products/Followers/Following counts — Followers
  and Following are tappable; visitors see counts only (no list access).
- Popping the list refreshes store meta counts on the profile.

### Wishlist (page 12) + photo like
- **API** (`WishlistRepository` / `lib/webservice/wishlist/`):
  - `PUT|DELETE /products/:listingId/photos/:photoId/like` (store/collections
    alias when `storeId` known)
  - `GET /wishlist?limit&cursor&status=all|active|locked`
  - `DELETE /wishlist/:wishlistId`
- **Models:** `lib/models/catalog/wishlist_api_models.dart`
  (`WishlistItem` active + locked stubs, `PhotoLikeResult`).
- **Wishlist tab** (`wishlist_route.dart`): 2-column **square** grid; photo with
  heart top-right; title / meta / store overlaid at bottom. Store filter chips;
  pull-to-refresh. Active tile → product details with `galleryFeed` of visible
  active wishlist photos (swipe across items); `likedPhotoId(s)` keep hearts
  filled. Locked stub: lock UI, Follow/Requested, trash. Remove active via
  heart → unlike API when ids exist. Privacy footer unchanged.
- **Product details heart:** like/unlike current photo (see product_details
  FEATURE_CONVENTIONS). Snack “Saved to Wishlist” + **View** pops to shell and
  selects the Wishlist tab (`ShellNav`), which quiet-refreshes the list.
- **Activity** opens from Stores home notification icon → `activity_route`
  (not store-profile bottom nav). Main shell (own store) hosts Wishlist + My
  store as bottom tabs (`WishlistRoute` / `StoreMyStoreTab`; IndexedStack
  keep-alive + refreshSignal on Wishlist select). No-store shell remains
  Stores / Contacts / Settings / Profile.

### Activity feed (page 13)
- **Activity** (`activity_route.dart`): Stores home notification icon →
  `activity_route`. Loads `GET /activity` via `ActivityRepository`. Pinned
  `FollowRequestsBanner` when `pendingFollowRequestsCount > 0`. Rows grouped
  New / Earlier (unread/read). Clean list rows (avatar + copy + time below,
  soft unread tint, hairline dividers); empty state with bell icon; shimmer
  skeleton while loading. Pull-to-refresh + cursor pagination. Opening marks
  all read (`POST /activity/read` `{ all: true }`). Home bell shows unread
  badge from `GET /activity/unread-count`.
- **Row tap:** `follow_request` → follow requests; `request_approved` /
  `new_follower` → store profile; `new_upload` / `product_liked` → store
  profile (+ `focusProductId` = `entityId` when present).
- **FCM push:** device token sync + deep links in `PushNotificationService`.
  Same type → route matrix as API. `product_liked` is in-app only (no push).

### Visitor 14 — Search privacy (global Discover)
- Private stores remain in suggest + results **Stores** strip with lock +
  Follow / Requested (`SearchStorePrivacyRow` via `StoreRepository`).
- Private-store products are client-filtered when `canViewContent` / privacy
  fields say the viewer cannot see them. Count line + store facets prefer
  visible hits. In-store search is not re-gated here.
- Owned by `lib/presentation/search/` (see search FEATURE_CONVENTIONS).

## UI Rules
- Use `ScreenWrapper`, `AppBackButton`, `AppPadding`, `AppTextStyles`, `AppColors`
  on full pushed screens (Account privacy, Follow requests, Requester profile,
  Followers/Following).
- Reuse `PrimaryButton` for primary CTAs.
- Status colors: `AppColors.success` (Visible / Instant / Approved) and
  `AppColors.error` (Hidden / Needs approval). Secondary delete actions use
  grey (`AppColors.textSecondary` / surface), not error red, on follow-request
  rows and Followers **Remove** chips.
- ASCII-safe user-facing strings only.

## Logic Ownership
- Persistence + privacy API live in `StorePrivacyPreferences` (not in widgets).
- Pending follow-request count comes from GET store `pendingRequestsCount`
  (not a fake demo number). Going public clears pending locally after a
  successful PATCH (server bulk-approves).
- On PATCH failure, preview reverts and `CatalogErrorMapper` snackbar is shown.
- Follow accept/reject/remove/list live in the privacy routes above via
  `StoreRepository`.

## Route and Navigation Notes
- `Routes.accountPrivacyRoute` via `route_initializer` (Cupertino push).
- `Routes.followRequestsRoute` — args: `storeId`, `storeName`.
- `Routes.followRequesterProfileRoute` — args: `request` (serialized
  `FollowRequestItem` fields), `ownerStoreId`, `ownerStoreName`, optional
  `readOnly`.
- `Routes.followersFollowingRoute` — args: `storeId`, `storeName`,
  `initialTab` (`followers`|`following`), `followerCount`, `followingCount`.
- Entry from owner store profile counts / Activity banner (parent wires nav).
- Do not remap main-shell tabs for this feature.
