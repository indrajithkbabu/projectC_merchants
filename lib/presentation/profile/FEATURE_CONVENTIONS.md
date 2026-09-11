# Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/profile/`.

## Mandatory Update Rule
- If profile setup fields, validations, content order, media pickers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full screen routes.
- Use `AppPadding` for horizontal and vertical spacing.
- Use `AppTextStyles` and `AppColors` for all visible text/colors.
- Reuse shared components first; keep profile-only widgets inside `profile_widgets/`.

## Logic Ownership
- Profile screens should handle profile presentation and user input binding only.
- Move side effects to listeners and keep build methods pure.
- Keep cross-feature logic (auth/store/team) out of profile presentation files.

## Route and Navigation Notes
- Register profile routes in centralized navigation setup.
- Keep transition behavior consistent with shared Cupertino route style.

## Folder Scope
- `profile_route.dart`: profile screen route.
- `profile_widgets/`: profile-only widget building blocks.
