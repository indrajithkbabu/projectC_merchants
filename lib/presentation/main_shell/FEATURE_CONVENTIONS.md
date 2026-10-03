# Main Shell Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/main_shell/`.

## Mandatory Update Rule
- If floating nav layout, tab set, or shell UX requirements change, update this file in the same PR.

## UI Rules
- Root shell uses `ScreenWrapper` with `extendBodyBehindBottom: true`.
- Floating capsule nav is `FloatingBottomNavBar` from `lib/helper/widgets/`.
- Tabs: **Stores** | **Contacts** | **Settings** | **Profile** (Stores replaces Telegram “Chats”).
- Profile tab avatar on the nav: show the uploaded profile photo when
  `effectiveProfileImageUrl` is set; otherwise keep initials. Use
  `CatalogImageCache` (same as Profile tab picker).
- Tab bodies must leave bottom padding via `FloatingBottomNavBar.reservedHeight`.
- Soft keyboard open → hide floating nav with slide + fade; restore smoothly when IME closes (`resizeToAvoidBottomInset: false` on the shell so the bar is not pushed above the keypad).
- No blocking loaders (no centered `CircularProgressIndicator`). Prefer cached/session data + quiet refresh + pull-to-refresh.
- Use `AppPadding`, `AppTextStyles`, and `AppColors` (including `navBar*` tokens).
- Settings includes **Allow screenshots** toggle (default off). App-wide capture blocking is owned by `ScreenshotProtectionService` (`lib/services/`); do not add per-screen FLAG_SECURE hacks.

## Logic Ownership
- Shell hosts `StoreListingBloc`, `ContactsBloc`, and `AccountProfileBloc`.
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
  (`CatalogSession` first, then quiet refresh). Profile tab avatar
  upload/delete → `POST|DELETE /me/profile-image` → `GET /me` → session
  cache → UI. Own-store Profile tab also hosts **Import requests** →
  `store_import_requests_route` (pending badge via quiet
  `GET .../import-requests`). Delete account → `DELETE /me` then
  `CatalogSession.clear()` (tokens/profile + `StoreProductsCache` /
  `StoreMetaCache` / `CatalogImageCache`); shell then dispatches
  `AuthLoggedOut` and navigates to phone. Logout → `AuthLoggedOut` → same
  session clear path.
- Settings → **View products** (group / single / gallery) persists via
  `ProductViewPreferences` + `AppSettingsStorage` (survives logout) and
  drives store-profile layout.
- Screenshot / screen-recording preference lives in `AppSettingsStorage` (survives logout) and is applied by `ScreenshotProtectionService` at app start.
- Keep tab content in `tabs/`; keep shell chrome in `main_shell_route.dart`.

## Route and Navigation Notes
- Post-onboarding entry remains `store_listing_route`, which now builds `MainShellRoute`.
- Nested pushes (store profile, import flows) stay on the root navigator above the shell.
