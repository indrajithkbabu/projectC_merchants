# Project UI Conventions

This document defines the common implementation standards to follow across all screens in this project.

## Core Principles
- Always use shared helpers from `lib/helper/` for layout, spacing, typography, and common controls.
- Avoid ad-hoc paddings, font families, and one-off navigation transitions.
- Keep UI consistent with the Telegram-style theme already configured.

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
  statusBarIconBrightness: Brightness.dark,
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
- Use colors from `AppColors` (`lib/helper/colors.dart`).
- Do not introduce raw hex values inside feature screens unless adding to palette first.
- Theme source of truth: `lib/helper/app_theme.dart`.

## Navigation and Transitions
- Route setup must go through `lib/navigation/route_initializer.dart`.
- Shared transition style uses `CupertinoPageRoute` for smooth iOS-like push/pop behavior.
- Add new routes centrally in:
  - `lib/navigation/routes.dart`
  - `lib/navigation/route_initializer.dart`
- Current route flow (auth onboarding scope):
  - `onboarding_route` -> `auth_phone_route` -> `auth_otp_route` -> `profile_setup_route` -> `store_setup_route` -> `add_team_route` -> `store_listing_route` (main shell with floating nav) -> Stores / Contacts / Settings / Profile tabs
  - From store profile: `store_gallery_route` (iOS-style product photo gallery)
  - Own store profile: inbox badge → `store_import_requests_route` (accept / reject incoming; outgoing waits on source)
  - From another store profile: `store_import_select_route` -> pending -> approved (catalog import requests)
  - `country_picker_route` is opened from phone screen.

## Floating bottom navigation
- Post-auth home is `MainShellRoute` with Telegram-style floating capsule (`FloatingBottomNavBar`).
- Tab order: Stores, Contacts, Settings, Profile.
- Content must reserve space with `FloatingBottomNavBar.reservedHeight`; shell uses `extendBodyBehindBottom: true`.
- Prefer quiet backend refresh (no blocking loaders) and pull-to-refresh.

## Common Controls
- Reuse these shared widgets from `lib/helper/widgets/`:
  - `PrimaryButton`
  - `KeypadCtaBar`
  - `CustomNumericKeypad`
  - `AppBackButton`
  - `ScreenWrapper`
  - `FloatingBottomNavBar`

Do not duplicate these widgets inside feature folders.

## Current App Defaults
- **Default country:** India (`+91`) from `CountryModel.defaultCountry`.
- **OTP scope:** Indian mobile numbers only (`+91`, 10 digits starting 6–9). Country picker stays available for UX but selecting another country shows a snackbar; API may return `UNSUPPORTED_PHONE_COUNTRY`.
- **OTP behavior:** Catalog API SMS OTP; retain `challengeId`; resend cooldown from API (typically 60s). No hardcoded demo code.
- **API base:** Flavor `baseUrl` includes `/v1/catalog`. Networking lives under `lib/webservice/` + `lib/resources/endpoints.dart`.
- **Collection create:** Multipart `POST /stores/:id/collections` with `photos` file parts (no signed S3 upload / complete / worker).
- **Country picker package:** `country_picker` (English country names, searchable list).
- **Font family:** Inter everywhere via `AppTheme` + `AppTextStyles`.
- **Main horizontal spacing:** 15 via `AppPadding.horizontal`.
- **Back navigation control:** icon-only `AppBackButton`.
- **Screenshot / screen recording:** Blocked app-wide by default via `ScreenshotProtectionService` + `no_screenshot`. Settings → **Allow screenshots** turns capture on. While blocked, detected capture attempts show a snackbar. Preference persists in `AppSettingsStorage` (not cleared on logout).

## Auth Flow Implementation Rules
- `AuthBloc` owns phone input, OTP input, resend timer, and verification state.
- Phone and OTP screens must use:
  - `CustomNumericKeypad` (no system keyboard for number entry)
  - `KeypadCtaBar` for primary action above keypad
  - `MultiBlocListener` for navigation, errors, and success events
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
        statusBarIconBrightness: Brightness.dark,
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

