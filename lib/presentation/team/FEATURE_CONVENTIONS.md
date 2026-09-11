# Team Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/team/`.

## Mandatory Update Rule
- If add-team flow, member listing behavior, invites, search behavior, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for routes.
- Use `AppPadding` for consistent spacing.
- Use `AppTextStyles` and `AppColors` for typography and color.
- Keep shared controls reused from helper widgets when possible.

## Logic Ownership
- Team screens should handle only team-related presentation and user actions.
- Keep side effects in listeners and not in widget build methods (including API error snackbars).
- Avoid coupling team presentation files with unrelated feature logic.
- Contact list comes from the **device** (`flutter_contacts`), not demo data.
- Selected phones are submitted with `POST /stores/:storeId/contacts` in batches of ≤30 (Catalog API). Empty selection / Skip does not call the API.
- Contact API failure must not block navigation to store listing (store already created).

## Route and Navigation Notes
- Add and maintain routes through centralized route files.
- Keep shared transition style consistent.
- Continue / Skip → `store_listing_route` via `pushNamedAndRemoveUntil`.

## Folder Scope
- `add_team_route.dart`: team route entry.
- `team_widgets/`: team-specific widgets only.
