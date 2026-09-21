# Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/profile/`.

## Mandatory Update Rule
- If profile setup fields, validations, content order, media pickers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full screen routes.
- Use `AppPadding` for horizontal and vertical spacing.
- Use `AppTextStyles` and `AppColors` for all visible text/colors.
- Reuse shared components first; keep profile-only widgets inside `profile_widgets/`.
- `ProfilePhotoPicker` supports local path and network `imageUrl`.

## Logic Ownership
- Profile screens should handle profile presentation and user input binding only.
- Move side effects to listeners and keep build methods pure.
- Keep cross-feature logic (auth/store/team) out of profile presentation files.
- Onboarding continue uploads optional avatar via multipart `PATCH /me` with names.
- Profile photo bottomsheet options: **Use camera**, **Choose from gallery**, and
  **Delete photo** (when set). No duplicate “Add photo” entry.
- Profile tab (main shell) edits avatar via `POST /me/profile-image` and
  `DELETE /me/profile-image` through `AccountProfileBloc`.

## Route and Navigation Notes
- Register profile routes in centralized navigation setup.
- Keep transition behavior consistent with shared Cupertino route style.

## Folder Scope
- `profile_route.dart`: onboarding profile setup route.
- `profile_widgets/`: profile-only widget building blocks.
