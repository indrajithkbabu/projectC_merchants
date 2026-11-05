# Bootstrap Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/bootstrap/`.

## Mandatory Update Rule
- If cold-start gate UI, session-restore presentation, or requirements change, update this file in the same PR.
- Keep this file aligned with `AuthBloc` session restore and `app.dart` root navigation.

## UI Rules
- Wrap with `ScreenWrapper` and `AppColors.background` (same shell flags as
  main shell: `resizeToAvoidBottomInset: false`, `extendBodyBehindBottom: true`).
- **Signed-in kill+reopen / restart:** paint the **real** Stores home chrome —
  `ShellTabTitleBar` (“Stores”) + activity bell (when own store) + the same
  search `TextField` look as `StoreListingRoute` + real `FloatingBottomNavBar`
  (Stores selected; no-store vs own-store tab set from session profile). Do
  **not** shimmer/blur the search bar, bell, or bottom nav.
- **Listing body:** paint rows from `StoreHomeCache` via `StoreListingTile` when
  cache has items; otherwise list-only `StoreListingShimmer` (same as home with
  no cache). Interactions are disabled (`IgnorePointer`) until the real shell
  mounts — no premature search/tab/store routes.
- Never show `JewelFlowLogo` when local tokens exist or `AuthBloc` is already
  authenticated.
- **Unsigned / first launch:** after a fast `SessionStorage` token probe finds
  no session, show centered `JewelFlowLogo`. While probing, keep a blank
  background (no logo flash that would also hit signed-in users).

## Logic Ownership
- Bootstrap only paints. Session restore, `/me`, logout, and root replacement
  live in `AuthBloc` + `app.dart` `BlocListener`.
- Token probe is read-only (`CatalogSession` / `SessionStorage`); it must not
  clear or mutate the session.
- Home-first restore (tokens OK and cached onboarding is home-bound) awaits
  `StoreHomeCache.read()` (disk→memory), then leaves bootstrap when `AuthBloc`
  emits `postAuthRoute` → Stores so the shell can seed rows on frame 0. `/me`,
  wishlist/cart hydrate, and avatar warm continue in the background.
- Incomplete onboarding (`nameRequired`) still waits on `/me` before leaving
  bootstrap (may briefly show logo or blank, then profile setup) — do not force
  Stores.

## Route and Navigation Notes
- Registered as the MaterialApp initial route (`bootstrap_route`).
- Root replace after restore is handled only by the app-level `AuthBloc`
  listener (OTP post-auth navigation stays on `OtpRoute`).

## Folder Scope
- `bootstrap_route.dart`: cold-start gate only.
