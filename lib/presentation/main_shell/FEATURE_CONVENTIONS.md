# Main Shell Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/main_shell/`.

## Mandatory Update Rule
- If floating nav layout, tab set, or shell UX requirements change, update this file in the same PR.

## UI Rules
- Root shell uses `ScreenWrapper` with `extendBodyBehindBottom: true`.
- Floating capsule nav is `FloatingBottomNavBar` from `lib/helper/widgets/`.
- Tabs: **Stores** | **Contacts** | **Settings** | **Profile** (Stores replaces Telegram “Chats”).
- Tab bodies must leave bottom padding via `FloatingBottomNavBar.reservedHeight`.
- Soft keyboard open → hide floating nav with slide + fade; restore smoothly when IME closes (`resizeToAvoidBottomInset: false` on the shell so the bar is not pushed above the keypad).
- No blocking loaders (no centered `CircularProgressIndicator`). Prefer cached/session data + quiet refresh + pull-to-refresh.
- Use `AppPadding`, `AppTextStyles`, and `AppColors` (including `navBar*` tokens).
- Settings includes **Allow screenshots** toggle (default off). App-wide capture blocking is owned by `ScreenshotProtectionService` (`lib/services/`); do not add per-screen FLAG_SECURE hacks.

## Logic Ownership
- Shell hosts `StoreListingBloc`, `ContactsBloc`, and `AccountProfileBloc`.
- Stores tab → `GET /home` via existing store listing.
- Contacts tab → `GET /stores/:id/members` for the user’s own store. When catalog `firstName`/`lastName` are null, quietly resolve the device contact name by phone (no loader).
- Profile / Settings → `GET /me`; Profile tab can upload/replace/delete avatar
  (`POST|DELETE /me/profile-image`); delete account → `DELETE /me`; logout → `AuthLoggedOut`.
- Screenshot / screen-recording preference lives in `AppSettingsStorage` (survives logout) and is applied by `ScreenshotProtectionService` at app start.
- Keep tab content in `tabs/`; keep shell chrome in `main_shell_route.dart`.

## Route and Navigation Notes
- Post-onboarding entry remains `store_listing_route`, which now builds `MainShellRoute`.
- Nested pushes (store profile, import flows) stay on the root navigator above the shell.
