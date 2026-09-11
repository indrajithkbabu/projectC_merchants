# Auth Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/auth/`.

## Mandatory Update Rule
- If phone, OTP, country picker UI, behavior, validation flow, or requirements change, update this file in the same PR.
- Keep this file aligned with current auth presentation and interaction rules.

## UI Rules
- Wrap full routes with `ScreenWrapper`.
- Use `AppPadding` for all standard spacing and layout padding.
- Use `AppBackButton` for back navigation (icon-only).
- Use `AppTextStyles` for explicit text styling.
- Use `AppColors`; avoid one-off hardcoded colors.
- Use shared controls such as `CustomNumericKeypad` and `KeypadCtaBar`.

## Logic Ownership
- Auth presentation screens should only consume auth state and dispatch auth actions.
- Side effects (navigation, error/success snackbars) belong in `MultiBlocListener`.
- Do not put unrelated onboarding/store logic into auth routes/widgets.
- Keep OTP/phone input behavior consistent with `AuthBloc` ownership.
- `AuthBloc` calls `AuthRepository` (OTP request/verify, session restore, logout).
- After verify, navigate using `postAuthRoute` from `profile.onboarding`.
- OTP is India-only: reject non-`IN` country changes; require 10-digit mobile starting 6–9 before request.
- Phone country field tap shows a snackbar instead of opening the picker for other countries.

## Route and Navigation Notes
- Register routes centrally in shared navigation files.
- Use shared Cupertino-style transition behavior.

## Folder Scope
- `phone_route.dart`, `otp_route.dart`, `country_picker_route.dart`: auth routes.
- `auth_widgets/`: auth-specific widgets only.
