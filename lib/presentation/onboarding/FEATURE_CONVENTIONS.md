# Onboarding Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/onboarding/`.

## Mandatory Update Rule
- If onboarding UI flow, copy, spacing, interactions, or requirements change, update this file in the same PR.
- Treat this file as the current source of truth for onboarding presentation behavior.

## UI Rules
- Wrap full routes with `ScreenWrapper`.
- Use `AppPadding` for horizontal and screen padding.
- Use `AppTextStyles` for all explicit typography.
- Use `AppColors` from shared palette (no ad-hoc hex values in screen code).
- Reuse shared widgets from `lib/helper/widgets/` before creating feature-local UI.

## Logic Ownership
- Onboarding screen rendering and onboarding-only visuals stay in this folder.
- Navigation triggers should come from onboarding state/bloc listeners.
- Keep side effects (navigation/snackbar) in listeners, not in build methods.
- Do not move auth logic into onboarding screens.

## Route and Navigation Notes
- Route registration must be centralized through navigation route setup.
- Transitions should use the shared Cupertino-style route behavior already used in the app.

## Folder Scope
- `onboarding_route.dart`: main onboarding route.
- `onboarding_widgets/`: onboarding-only widgets (not global reusable widgets).
