# Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/profile/`.

## Mandatory Update Rule
- If profile setup fields, validations, content order, media pickers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full screen routes.
- Use `AppPadding` for horizontal and vertical spacing.
- Use `AppTextStyles` and `AppColors` for all visible text/colors.
- Reuse shared components first; keep profile-only widgets inside `profile_widgets/`.
- `ProfilePhotoPicker` supports local path and network `imageUrl` (via `CatalogImageCache`).
- Onboarding asks for a single **Name** field (no first/last split). Font sizes are
  modest (~20–24). Name field autofocuses so the keyboard opens on land.
  Value is sent as `firstName` to `PATCH /me` (`lastName` omitted).

## Logic Ownership
- Profile screens should handle profile presentation and user input binding only.
- Move side effects to listeners and keep build methods pure.
- Keep cross-feature logic (auth/store/team) out of profile presentation files.
- Onboarding continue uploads optional avatar via multipart `PATCH /me` with names;
  response is written to `CatalogSession` so the main shell paints from cache
  (works with or without an image).
- Profile photo bottomsheet options: **Use camera**, **Choose from gallery**, and
  **Delete photo** (when set). No duplicate “Add photo” entry.
- Profile tab (main shell) edits avatar via `POST /me/profile-image` and
  `DELETE /me/profile-image` through `AccountProfileBloc`, then `GET /me` is
  called, cached, and shown everywhere that reads the session.
- When the user has an own store, Profile tab shows **Import requests** (opens
  `store_import_requests_route`) with a quiet pending-count badge, then
  **Open my store**.

## Route and Navigation Notes
- Register profile routes in centralized navigation setup.
- Keep transition behavior consistent with shared Cupertino route style.
- Onboarding profile continue → `store_listing_route` (main shell). Store
  creation is optional from the Profile tab (`store_setup_route`).

## Folder Scope
- `profile_route.dart`: onboarding profile setup route.
- `profile_widgets/`: profile-only widget building blocks.
