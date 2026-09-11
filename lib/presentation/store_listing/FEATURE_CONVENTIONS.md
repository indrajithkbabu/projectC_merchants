# Store Listing Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/store_listing/`.

## Mandatory Update Rule
- If listing layout, filtering/sorting behavior, selection flow, or requirements change, update this file in the same PR.

## UI Rules
- Standalone mode wraps with `ScreenWrapper`; shell mode uses `embeddedInShell: true` (no nested scaffold).
- Use `AppPadding` for spacing.
- Use `AppTextStyles` for text and `AppColors` for color choices.
- Reuse shared widgets from helper layer before adding local duplicates.
- Header shows brand + “Stores” title (account delete lives on Settings tab).
- When embedded, pad list bottoms with `FloatingBottomNavBar.reservedHeight`.

## Logic Ownership
- Store listing presentation should map state to UI and dispatch user actions.
- Side effects must stay in listeners.
- Keep non-listing domain logic outside this presentation folder.
- Home list uses `GET /home` with cursor pagination: pull-to-refresh (`RefreshIndicator` → `StoreListingRefreshed`) resets the first page; near-end scroll dispatches `StoreListingLoadMore`.
- Never show a full-screen spinner. Keep previous rows visible while refreshing; empty first paint may show soft “Loading stores…” text only.
- Account delete remains available on the Settings tab via `AccountProfileBloc` (`DELETE /me`).

## Route and Navigation Notes
- Route definitions must stay centralized.
- `store_listing_route` mounts the main shell (`MainShellRoute`) with this tab embedded.
- Use shared Cupertino-style transitions.

## Folder Scope
- `store_listing_route.dart`: listing route / Stores tab body.
- `store_listing_widgets/`: listing-only visual widgets.
