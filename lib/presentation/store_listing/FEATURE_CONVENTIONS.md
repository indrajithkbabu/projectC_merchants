# Store Listing Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/store_listing/`.

## Mandatory Update Rule
- If listing layout, filtering/sorting behavior, selection flow, or requirements change, update this file in the same PR.

## UI Rules
- Standalone mode wraps with `ScreenWrapper`; shell mode uses `embeddedInShell: true` (no nested scaffold).
- Use `AppPadding` for spacing.
- Use `AppTextStyles` for text and `AppColors` for color choices.
- Reuse shared widgets from helper layer before adding local duplicates.
- Header uses shared `ShellTabTitleBar` (“Stores”, 40px / 22pt, statusBar+8) so
  it aligns with Contacts / Wishlist on shell tab switches. Trailing: (own store)
  notification icon → `activity_route` (live `GET /activity` feed + unread
  badge from `/activity/unread-count`) + overflow `⋮` (**Create group** →
  snackbar “coming soon”). No brand logo or subtitle under the title.
- Home search field uses a pill radius (`BorderRadius.circular(32)`) matching
  the floating bottom nav capsule. It is an entry to `global_search_route`
  (product/tag/store Discover). It is read-only on this screen; store-list
  text filtering is not driven from this field.
- When embedded, pad list bottoms with `FloatingBottomNavBar.reservedHeight`.
- Account delete lives on Settings tab.
- Row subtitle: **no store link**. Show API `phone` when present; if that number
  matches a device contact (E.164 or unambiguous last-10 digits, including
  Android `normalizedNumber`), show the contact name instead.
- Leading avatar uses store cover / first showcase image from `/home` when
  available; otherwise colored initials (unchanged). Avatars use shared
  `CatalogNetworkAvatar` + `CatalogImageCache.warmAvatars` (stable decode
  width, disk probe on reopen) so kill+reopen does not flash initials/color.
  New/updated cover URLs still warm after `/home` refresh. Tap avatar (when
  images exist) → centered blurred preview (`store_listing_image_preview`);
  swipe left/right when multiple images; single image is non-scrollable.
  Preview uses a light iOS-style blur; dismiss by tapping outside (no close
  icon). Row tap still opens the store profile.

## Logic Ownership
- Store listing presentation should map state to UI and dispatch user actions.
- Side effects must stay in listeners.
- Keep non-listing domain logic outside this presentation folder.
- Home list uses `GET /home` with cursor pagination: pull-to-refresh (`RefreshIndicator` → `StoreListingRefreshed`) resets the first page; near-end scroll dispatches `StoreListingLoadMore`.
- `CatalogStore` parses `phone` / `phoneNumber` / `phonenumber`, string or object
  `coverImage` / `storeImage`, plus `images` / `imageUrls`. Mapping via
  `CatalogUiMapper.storeToChannel`. Contact subtitles use shared
  `DeviceContactNames` (one permission request app-wide — do not call
  `FlutterContacts.requestPermission` from feature blocs; TeamBloc / Contacts
  also use this shared index).
- Cold start / post-OTP: `StoreHomePrefetcher` + `DeviceContactNames.prefetch`
  start as soon as auth tokens are ready. Successful `/home` pages (and
  resolved contact names) are written to `StoreHomeCache` (disk). **Kill+reopen**
  paints that cache immediately (including contact names) — no shimmer wait —
  then soft-refreshes `/home` in the background. First-ever open (no cache)
  still shows list-row shimmer until `/home` returns: if the contact index is
  already warm/in-flight, names are included on first emit; otherwise cached
  names / empty subtitle first, then enrich (never block shimmer on the
  permission dialog). Later refreshes force a new `/home` fetch (contact map
  stays session-cached). After **store create**, the repository invalidates +
  re-prefetches home so the new own store appears when the listing shell
  remounts (no manual pull-to-refresh required). Logout / delete account clears
  `StoreHomeCache` with the other store caches.
- Never show a full-screen spinner. Keep previous rows visible while refreshing;
  empty first paint shows list-row shimmer (`store_listing_shimmer`) **only when
  there is no home cache**, not “Loading stores…” text. True empty state shows
  “No stores found”.
- Account delete remains available on the Settings tab via `AccountProfileBloc` (`DELETE /me`).
- Global product search lives under `lib/presentation/search/` and calls catalog search APIs via `SearchRepository`.

## Route and Navigation Notes
- Route definitions must stay centralized.
- `store_listing_route` mounts the main shell (`MainShellRoute`) with this tab embedded.
- Tapping the home search field → `global_search_route`.
- Use shared Cupertino-style transitions.

## Folder Scope
- `store_listing_route.dart`: listing route / Stores tab body.
- `store_listing_widgets/`: listing-only visual widgets (tile, image preview,
  header profile avatar, list shimmer).
