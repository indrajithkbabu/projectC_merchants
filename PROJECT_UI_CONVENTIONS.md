# Project UI Conventions

This document defines the common implementation standards to follow across all screens in this project.

## Core Principles
- Always use shared helpers from `lib/helper/` for layout, spacing, typography, and common controls.
- Avoid ad-hoc paddings, font families, and one-off navigation transitions.
- Keep UI consistent with the active appearance (Day / Night) via `AppColors` + `AppTheme`.

## Mandatory Building Blocks

### 1) Screen Wrapper
- Every full screen should be wrapped with `ScreenWrapper` from `lib/helper/widgets/screen_wrapper.dart`.
- This ensures:
  - status bar is handled consistently
  - correct safe area behavior
  - unified scaffold background and system overlay style

Example:
```dart
return ScreenWrapper(
  backgroundColor: AppColors.background,
  // statusBarIconBrightness defaults from AppColors (Day=dark icons, Night=light)
  child: ...,
);
```

### 2) Horizontal Padding
- Use shared horizontal spacing from `AppPadding` in `lib/helper/app_padding.dart`.
- Standard horizontal spacing is `15`.

Use:
- `AppPadding.screenHorizontal`
- `AppPadding.screen(top: ..., bottom: ...)`

Do not hardcode random horizontal values unless there is a very strong, screen-specific reason.

### 3) Back Button
- Use `AppBackButton` from `lib/helper/widgets/app_back_button.dart`.
- Do not add text labels like "Back".
- Keep it left-aligned with screen content.

Example:
```dart
AppBackButton(
  onPressed: () => Navigator.of(context).maybePop(),
)
```

### 4) Typography (Inter)
- Use `AppTextStyles` from `lib/helper/text_styles.dart`.
- Font family is Inter globally via `AppTheme`, but all explicit text styles should use `AppTextStyles`.
- You may override size/weight/color as needed using available style methods.

Common picks:
- Large heading: `AppTextStyles.title()`
- Body text: `AppTextStyles.body()` / `AppTextStyles.bodySecondary()`
- CTA text: `AppTextStyles.button()`
- Caption/helper text: `AppTextStyles.caption()`

### 5) Theme and Colors
- Use colors from `AppColors` (`lib/helper/colors.dart`). Do not hardcode palette hex in features.
- Appearance is **Day** (Telegram light) or **Night** (Graphite dark). Source of truth:
  - Palettes: `AppColorPalette.day` / `AppColorPalette.night` in `colors.dart`
  - ThemeData: `AppTheme.light` / `AppTheme.dark` in `app_theme.dart`
  - Preference: `ThemePreferences` (`lib/services/theme_preferences.dart`), persisted in
    `AppSettingsStorage` (survives logout). Settings → Appearance radios write it.
- `AppColors.bind(appearance)` keeps static getters in sync; `MaterialApp` uses
  `theme` + `darkTheme` + `themeMode`. Default is Day.
- Instant Day/Night refresh: `AppearanceScope` + `AppearanceRebuildGate` in
  `MaterialApp.builder` (`lib/helper/widgets/appearance_scope.dart`) mark the
  navigator subtree dirty so every open screen repaints without remounting routes.
- Prefer omitting `statusBarIconBrightness` on `ScreenWrapper` so Day/Night chrome stays correct.
  Override only for immersive dark photo surfaces (always light icons).
- Night follows Graphite: grey ramp only; functional hues for status/links; no pure `#FFFFFF`.

## Navigation and Transitions
- Route setup must go through `lib/navigation/route_initializer.dart`.
- Shared transition style uses `CupertinoPageRoute` for smooth iOS-like push/pop behavior.
- Immersive photo open from store profile Single/Gallery (and channel Gallery)
  uses `TelegramPhotoPageRoute` when args include `photoSourceRect` + `photoPath`.
  Flyer uses a photo-aspect flight rect (cover over the cell → contain on
  screen) with a clip that expands from the cell — works for any photo size.
  Scrim dims the grid; close is the reverse. Other entry points keep
  `CupertinoPageRoute`.
- Store profile Discover header uses Telegram floating capsules
  (`StoreProfileTelegramHeader`): frosted back / identity / actions pills
  (`AppColors.appBar` translucent), DP + name + followers, add|import + search
  (owner/visitor gated) — not a solid full-width app bar.
- Catalog image lists (Discover / channel / gallery / collection browse) are
  edge-to-edge (no decorative list top/bottom pad); content scrolls under the
  status bar and home indicator. Soft cool edge washes use shared
  `CatalogImageEdgeFades` from `lib/helper/widgets/`.
- Discover header → `store_channel_route` uses `StoreChannelRevealRoute`
  (fade + soft upward expand from the header). Do not use Cupertino sideways
  push for this handoff. Channel pinned bar is transparent frosted glass when
  collapsed (content visible through); count row is Products / Followers /
  Following; store-link card has copy + WhatsApp share.
- Add new routes centrally in:
  - `lib/navigation/routes.dart`
  - `lib/navigation/route_initializer.dart`
- Current route flow (auth onboarding scope):
  - `onboarding_route` -> `auth_phone_route` -> `auth_otp_route` -> `profile_setup_route` -> `store_listing_route` (main shell with floating nav)
  - Shell tabs depend on own-store: **no store** → Stores / Contacts / Settings / Profile; **own store** → Stores / Contacts / Wishlist / My store (Settings via My store gear → `settings_route`)
  - Store creation is deferred: Profile tab (or Contacts empty CTA) -> `store_setup_route` -> `add_team_route` -> `store_listing_route`
  - Contacts tab: Invite Friends → `invite_friends_route` (Share + phone contacts); default list shows peer stores only; search shows matching stores then invite contacts
  - Contacts invite / Share JewelFlow uses WhatsApp copy `Hey, I'm using JewelFlow… Download it here: https://…`
  - After store create, home `/home` warm cache is invalidated so the new store appears on Stores without a manual refresh
  - From store profile Discover/visitor compact header: `store_channel_route` (Telegram-style store info + Media/Group/Gallery); `store_gallery_route` still used for dedicated gallery edits; app-bar search icon → `store_search_route`
  - Stores home search field → `global_search_route` (Discover / suggestions / results / filters via catalog search APIs); Sort & Filter → `search_filters_route`
  - Own store profile: inbox badge → `store_import_requests_route` (accept / reject incoming; outgoing waits on source)
  - Own-store shell: My store gear → `settings_route` (Appearance, View products, screenshots, logout/delete, **Account privacy**, **Import requests**). Profile tab (no-store only) still hosts Create store.
  - Stores home (own store): notification icon → `activity_route`. Store profile (pushed) is Discover-only for owner and visitor (no owner bottom nav). Shell Wishlist + My store tabs; product-details like snack **View** → shell Wishlist via `ShellNav` (quiet refresh).
  - From another store profile (only if viewer has own store): long-press photos → Import opens Quick upload prefilled (`quick_import_flow`, local session until the import API is wired). Toolbar download still uses `store_import_select_route` -> pending -> approved.
  - `country_picker_route` is opened from phone screen.

## Floating bottom navigation
- Post-auth home is `MainShellRoute` with Telegram-style floating capsule (`FloatingBottomNavBar`).
- Tab order:
  - **No own store:** Stores · Contacts · Settings · Profile
  - **Own store:** Stores · Contacts · Wishlist (heart) · My store — Settings moves under My store toolbar gear (`settings_route`). Wishlist + My store reuse the same widgets/logic as store-profile owner tabs.
- Own-store shell hosts a long-lived `StoreProfileBloc` (cache-first + prefetch) so My store does not cold-shimmer on every visit.
- Content must reserve space with `FloatingBottomNavBar.reservedHeight` inside
  scrollables/empty states (not outer tab padding that leaves a blank band);
  shell uses `extendBodyBehindBottom: true`.
- Shell system back: non-Stores tab → Stores; two backs on Stores exits the app
  (see `main_shell/FEATURE_CONVENTIONS.md`). Nested routes above the shell pop first.
- Prefer quiet backend refresh (no blocking loaders) and pull-to-refresh. Do not remount Wishlist on tab re-select (keeps grid state; pull-to-refresh still available).
- Shell home titles (Stores / Contacts / Wishlist) use shared `ShellTabTitleBar`
  (40px row, 22pt, `statusBar + 8` top) so IndexedStack tab switches keep the
  title locked in place with no vertical jump. Trailing actions (bell / ⋮ /
  collapsed wishlist search) stay right-aligned.
- Own-store Wishlist is prefetched (`WishlistPrefetcher`) after auth `/me` +
  home warm — shell Wishlist tab must not shimmer on first open.

## Common Controls
- Reuse these shared widgets from `lib/helper/widgets/`:
  - `PrimaryButton`
  - `KeypadCtaBar`
  - `CustomNumericKeypad`
  - `AppBackButton`
  - `ScreenWrapper`
  - `ShellTabTitleBar` (home shell tab titles)
  - `FloatingBottomNavBar`
  - `NetworkStatusGate` (app-wide; do not re-wrap per screen)
  - `showMediaSourceSheet` / `MediaPickSource` (camera vs gallery chooser; no
    Cancel — keep for any remaining chooser surfaces; add-product add-more
    uses `ProductGalleryPicker(includeCamera: true)` instead)
- Add-product gallery multi-select: `ProductGalleryPicker` in
  `lib/helper/product_gallery_picker.dart` (Telegram attach-media bottomsheet:
  lightweight [PopupRoute] with dimmed barrier, slide-up, rounded sheet, drag
  handle, tap-outside dismiss — same look as [showModalBottomSheet]; permission
  + first page warm during open; progressive JPEG thumbs; live camera stays on
  while scrolling (stable Texture child under Transform via AnimatedBuilder —
  grid does not rebuild on scroll); camera cell uses a clipped ImageFilter
  frosted blur placeholder until live preview binds; DPR-sized JPEG thumbs
  with stable asset keys;
  selection order map + count ValueNotifier; cacheExtent ~240; count badge
  toggles/deselects; photo body selects, or opens compose on an already-
  selected photo via `initialIndex`; hold-and-slide via path-patched
  `packages/drag_select_grid_view`; albums dropdown meta loads on open;
  optional `includeCamera` → live Camera preview cell (`camera` package, 2×3)
  beside a 2×3 gallery block; tap Camera closes sheet then in-app full-screen
  capture. Store-profile Add products uses `confirmAsSend: true` (green send +
  count) then `add_product_compose_route` before `add_product_group_route`.
  Add-more from group preview keeps Done confirm.)

Do not duplicate these widgets inside feature folders.

## Network status banner (PhonePe-style)
- Package: `connectivity_plus` (Wi‑Fi / mobile / ethernet transport; not a DNS probe).
- Cubit: `NetworkStatusCubit` in `lib/bloc/network_status/` — started once from `App`.
- Layout: `NetworkStatusGate` via `MaterialApp.builder` so **every** route is covered. Banner sits in a **Column** and **pushes** the navigator down (never overlays / covers content). While visible it owns the status-bar inset (`MediaQuery` top padding cleared for descendants so `ScreenWrapper` does not double-pad).
- Offline: red top strip (`AppColors.error`) + copy **"No internet connection"**; content is wrapped in `AbsorbPointer(absorbing: true)` so taps are blocked.
- Restored: green top strip (`AppColors.success`) + **"Back online"** for ~2s, then auto-hides (no green flash on cold start when already online).
- Do not add per-screen offline banners; do not bypass `MaterialApp.builder` for this.

## Current App Defaults
- **Default country:** India (`+91`) from `CountryModel.defaultCountry`.
- **OTP scope:** Indian mobile numbers only (`+91`, 10 digits starting 6–9). Country picker stays available for UX but selecting another country shows a snackbar; API may return `UNSUPPORTED_PHONE_COUNTRY`.
- **OTP behavior:** Catalog API SMS OTP; retain `challengeId`; resend cooldown from API (typically 60s). No hardcoded demo code. Android auto-reads via SMS User Consent (`otp_autofill` / `OtpSmsAutofill`) then auto-verifies; manual entry still available.
- **API base:** Flavor `baseUrl` includes `/v1/catalog`. Networking lives under `lib/webservice/` + `lib/resources/endpoints.dart`.
- **Collection / product create:** Direct-to-R2 two-phase upload — on-device
  WebP compress (JPEG prefix SOF+EXIF probe, EXIF-aware max edge 1080,
  quality 85, prepare×3, `compressWithFile`) + ThumbHash from a native
  ~100px preview of the compressed master (full-master `compute` fallback),
  `POST /uploads/sign`
  (store aliases), PUT compressed bytes to Cloudflare R2 `presignedUrl`, then
  JSON `POST …/products/batch` with `image_id` + metadata (+ Idempotency-Key).
  Legacy multipart / collections create remains a fallback only.
- **Responsive image render:** `CatalogResponsiveImage` / `StoreProduct.urlForRole`
  — Group mosaics → `thumbnailUrl`; Single → `detailUrl`; Media + Gallery
  (profile / channel / `store_gallery`) pinch 2…9 cols: 6–9 → `thumbnailUrl`,
  2–5 → `detailUrl`; tap / product-details pinch → master `url`.
  Prod media host is `…/v1/catalog/media/…` (with `cdn-cgi/image/…` variants).
  ThumbHash is the instant placeholder. Debug: `CatalogMediaDBG`.
- **Country picker package:** `country_picker` (English country names, searchable list).
- **Font family:** Inter everywhere via `AppTheme` + `AppTextStyles`.
- **Main horizontal spacing:** 15 via `AppPadding.horizontal`.
- **Back navigation control:** icon-only `AppBackButton`.
- **Screenshot / screen recording:** Blocked app-wide by default via `ScreenshotProtectionService` + `no_screenshot`. Settings → **Allow screenshots** turns capture on. While blocked, detected capture attempts show a snackbar. Preference persists in `AppSettingsStorage` (not cleared on logout).
- **Appearance:** Settings → **Day mode** / **Night mode** (`ThemePreferences`). Day = Telegram light; Night = Graphite dark. Persists in `AppSettingsStorage` (not cleared on logout). Default Day.
- **Network banner:** App-wide via `NetworkStatusCubit` + `NetworkStatusGate` (`connectivity_plus`). Red offline / brief green restored; pushes layout down (no overlay); `AbsorbPointer` while offline.
- **Push notifications (FCM):** `firebase_core` + `firebase_messaging` + `flutter_local_notifications`. Init in `defaultMain` via `PushNotificationService`. After sign-in / session restore: `POST /devices/token`; before logout: `DELETE /devices/token`. Foreground shows a local notification. Tap / cold-open deep-links by `data.type` → `follow_request` → `follow_requests_route`; `request_approved` / `new_follower` → `store_profile_route`; `new_upload` → `store_profile_route` (+ `focusProductId` when `listingId` present). Defers open until signed in; never replaces auth/shell roots. Upload bell: `PATCH /stores/:id/follow` `{ notifyUploads }` via store profile (enable on active follow). **In-app Activity:** Stores home bell → `activity_route` (`GET /activity`, unread badge, mark-all-read). Config: FlutterFire (`lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`). Project: `project-c-jewelflow`.

## Auth Flow Implementation Rules
- `AuthBloc` owns phone input, OTP input, resend timer, verification state, and OTP auto-fill (`AuthOtpAutoFilled`).
- Phone and OTP screens must use:
  - `CustomNumericKeypad` (no system keyboard for number entry)
  - `KeypadCtaBar` for primary action above keypad
  - `MultiBlocListener` for navigation, errors, and success events
- OTP screen starts Android SMS User Consent listening on enter / resend (`otp_autofill`); auto-verify must go through `AuthBloc` (same as Continue).
- Keep side-effects (navigation/snackbar) in listeners, not in widget build methods.
- Validate Indian mobile locally before `OTP request`; map `UNSUPPORTED_PHONE_COUNTRY` via `CatalogErrorMapper`.

## Bloc and Feature Ownership
- Onboarding-only logic stays in onboarding feature.
- Auth-related logic (phone, OTP, country selection behavior) stays in auth feature/bloc.
- Keep presentation widgets separated by feature folders under `lib/presentation/`.

### Folder Responsibility (Current)
- `lib/presentation/onboarding/`: onboarding intro/welcome UI only.
- `lib/presentation/auth/`: phone, OTP, country picker, and auth widgets.
- `lib/helper/widgets/`: reusable cross-feature UI components only.
- `lib/bloc/onboarding/`: onboarding navigation trigger state.
- `lib/bloc/auth/`: auth phone/otp state machine + timer + verification status.

## MultiBlocListener Pattern
- Prefer `MultiBlocListener` on each screen that needs listeners (errors, navigation triggers, success states).
- Avoid long monolithic listeners in unrelated screens.

## New Screen Checklist
Before marking a new screen complete, verify:
- [ ] Wrapped with `ScreenWrapper`
- [ ] Uses `AppPadding` for horizontal spacing
- [ ] Uses `AppBackButton` if back navigation is needed
- [ ] Uses `AppTextStyles` for text
- [ ] Uses `AppColors` (no random hardcoded palette)
- [ ] Route added in `routes.dart` + `route_initializer.dart`
- [ ] Navigation transition uses shared route builder (do not bypass it)
- [ ] Shared controls reused from `lib/helper/widgets/`
- [ ] Uses `MultiBlocListener` where listener logic is needed
- [ ] Uses existing helper widgets before creating new duplicates
- [ ] Keeps feature ownership boundaries (onboarding vs auth vs helper)

## Implementation Notes
- If you add a new common pattern, update this file in the same PR.
- Keep examples in this doc aligned with actual code in `lib/helper/` and `lib/navigation/`.
- Every top-level folder under `lib/presentation/` must contain a `FEATURE_CONVENTIONS.md`.
- When any feature UI or requirement changes, update that feature's `FEATURE_CONVENTIONS.md` in the same PR.

## Suggested Screen Skeleton
```dart
class ExampleRoute extends StatelessWidget {
  const ExampleRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: const [],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        child: SingleChildScrollView(
          padding: AppPadding.screen(
            top: ScreenWrapper.statusBarTop(context),
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(),
              const SizedBox(height: 12),
              Text('Title', style: AppTextStyles.title()),
              const SizedBox(height: 8),
              Text('Body', style: AppTextStyles.bodySecondary()),
            ],
          ),
        ),
      ),
    );
  }
}
```

