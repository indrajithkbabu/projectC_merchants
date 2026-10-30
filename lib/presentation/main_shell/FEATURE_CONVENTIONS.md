# Main Shell Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/main_shell/`.

## Mandatory Update Rule
- If floating nav layout, tab set, or shell UX requirements change, update this file in the same PR.

## UI Rules
- Root shell uses `ScreenWrapper` with `extendBodyBehindBottom: true`.
- Floating capsule nav is `FloatingBottomNavBar` from `lib/helper/widgets/`.
- **Tab sets (driven by `AccountProfileBloc` / `CatalogSession.ownStoreId`):**
  - **No own store:** **Stores** | **Contacts** | **Settings** | **Profile**
  - **Own store:** **Stores** | **Contacts** | **Wishlist** (heart) | **My store**
- Own-store Settings is **not** a bottom tab. Open it from My store toolbar gear →
  `settings_route` (`SettingsTab(showBack: true)`), including Account privacy +
  Import requests, Appearance, View products, screenshots, logout / delete.
- Shell home titles (Stores / Contacts / Wishlist) share `ShellTabTitleBar`
  (40px row, 22pt, top = statusBar + 8) so tab switches stay vertically stable.
  Trailing stays right-aligned (`Expanded` title cluster + trailing). Wishlist
  collapses search/filters into title-trailing icons on scroll and supports
  gallery-style pinch column zoom (see privacy FEATURE_CONVENTIONS).
- Wishlist shell tab reuses `WishlistRoute` (`embeddedInShell: true`). No back
  button; pass `FloatingBottomNavBar.reservedHeight` as scroll/empty bottom
  padding only (never outer `Padding` that leaves a blank band under the list).
  Bump `refreshSignal` on tab select so new likes appear without app restart
  (quiet refresh when list already painted).
- My store shell tab reuses `StoreMyStoreTab` with `showBack: false` + hamburger
  → Settings (no day/night icon on this tab). Primary CTAs: **Import requests**
  (pending count from `StoreProfileBloc`) + **Share store**. Wrapped in
  `AppPadding.screen`. Product taps / long-press / follow-requests unchanged.
- Wishlist is warmed by `WishlistPrefetcher` after auth + home (`AuthBloc` /
  shell mount). Shell Wishlist never shows shimmer — paints warm/empty then
  quiet-refreshes.
- Stores header (own store): notification icon → `activity_route`
  (`GET /activity` feed + unread badge).
- Profile tab avatar on the nav (no-store only): uploaded profile photo when
  `effectiveProfileImageUrl` is set; otherwise initials. Use `CatalogImageCache`.
- Own-store My store nav: prefer store cover avatar when available; else
  store-mall icon.
- Tab bodies must leave bottom padding via `FloatingBottomNavBar.reservedHeight`
  **inside** scrollables / empty states so content reaches the floating nav
  (Telegram-style). Do not shrink the whole tab with outer bottom padding.
- Soft keyboard open → hide floating nav with slide + fade; restore smoothly when IME closes (`resizeToAvoidBottomInset: false` on the shell so the bar is not pushed above the keypad).
- No blocking loaders (no centered `CircularProgressIndicator`). Prefer cached/session data + quiet refresh + pull-to-refresh.
- Use `AppPadding`, `AppTextStyles`, and `AppColors` (including `navBar*` tokens).
- Settings includes **Appearance** (Day / Night via `ThemePreferences`) and **Allow screenshots**
  (default off). Switching appearance must refresh open screens immediately
  (`AppearanceScope` + `AppearanceRebuildGate` in `MaterialApp.builder`). App-wide
  capture blocking is owned by `ScreenshotProtectionService` (`lib/services/`);
  do not add per-screen FLAG_SECURE hacks.

## Anti-flicker Rules
- Keep tab bodies in an `IndexedStack` (4 slots). Swap slots 2–3 only when
  own-store presence changes (after store create the shell usually remounts via
  `pushNamedAndRemoveUntil`).
- Own-store: provide one `StoreProfileBloc` keyed by store id above the stack;
  seed from `StoreMetaCache` / `StoreProductsCache` + `StoreProductsPrefetcher`.
- Do **not** remount `WishlistRoute` on every Wishlist tab select (no epoch keys).
- Quiet refresh only when switching to My store (follow-request previews) —
  never wipe a painted product grid for a soft refresh.

## Logic Ownership
- Shell hosts `StoreListingBloc`, `ContactsBloc`, and `AccountProfileBloc`.
- Own-store shell also hosts `StoreProfileBloc` for My store (and shared meta).
- Stores tab → `GET /home` via existing store listing.
- Contacts tab (Telegram-style on `AppColors.scaffold`):
  - Title **Contacts** at 22pt + capsule search.
  - Default (empty search): **Invite Friends** action card →
    `invite_friends_route`, then **Stores** container only (peer stores from
    `StoreListingBloc` `/home`). Do **not** list phone contacts here.
  - While searching: matching **Stores** container first, then matching
    **Invite** phone contacts (name/phone). Row tap invites via WhatsApp.
  - `invite_friends_route`: back + title, search, **Share JewelFlow** card,
    then full device contact list. Reuses shell `ContactsBloc` via
    `BlocProvider.value`. Invite / share use
    `WhatsAppInvite.appInviteMessage`.
  Pull-to-refresh refreshes listing + contacts. Device contacts share
  `DeviceContactNames` (do not call `FlutterContacts.requestPermission` from
  ContactsBloc or TeamBloc). Contact-name matching uses E.164 plus
  Android `normalizedNumber` and unambiguous last-10 national fallback.
- Profile / Settings → cache-first `GET /me` via `AccountProfileBloc`
  (`CatalogSession` seeded into initial state so bottom-nav avatar has the
  URL on first frame; auth awaits `CatalogImageCache.warmAvatars` before
  shell mount; quiet refresh after). Profile tab avatar upload/delete →
  `POST|DELETE /me/profile-image` → `GET /me` → session cache → UI (warm
  before emit). **No-store** Profile tab: Create store CTA. **Own-store**
  privacy + import live under Settings (`settings_route` from My store).
  Delete account → `DELETE /me` then `CatalogSession.clear()` (tokens/profile +
  `StoreProductsCache` / `StoreMetaCache` / `CatalogImageCache`); shell then
  dispatches `AuthLoggedOut` and navigates to phone. Logout → `AuthLoggedOut` →
  same session clear path.
- Settings → **View products** (group / single / gallery) persists via
  `ProductViewPreferences` + `AppSettingsStorage` (survives logout) and
  drives store-profile layout.
- Screenshot / screen-recording preference lives in `AppSettingsStorage` (survives logout) and is applied by `ScreenshotProtectionService` at app start.
- Keep tab content in `tabs/`; keep shell chrome in `main_shell_route.dart`.

## Route and Navigation Notes
- Post-onboarding entry remains `store_listing_route`, which now builds `MainShellRoute`.
- Nested pushes (store profile, import flows, `settings_route`) stay on the root navigator above the shell.
- **System / edge back on the shell** (`PopScope` in `main_shell_route.dart`):
  - Any non-Stores tab → switch to Stores (index 0). My store multi-select
    consumes back first (`MyStoreTabState.consumeSystemBack`) before tab switch.
  - On Stores: first back shows “Press back again to exit”; second within ~2s
    calls `SystemNavigator.pop()`. Nested routes above the shell still pop
    normally (shell `PopScope` only runs when the shell route is current).
- Stores header avatar → Profile tab (no store) or My store tab (own store).
- Opening own store from listing still pushes `store_profile_route` (Discover /
  Activity / Wishlist / My store owner chrome). Shell Wishlist / My store do
  not remove that pushed owner experience.
