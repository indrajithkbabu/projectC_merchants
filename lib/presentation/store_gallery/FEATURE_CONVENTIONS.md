# Store Gallery Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/store_gallery/`.

## Mandatory Update Rule
- If gallery navigation, image interaction, zoom behavior, transitions, or requirements change, update this file in the same PR.

## UI Rules
- Wrap full screen with `ScreenWrapper`.
- Use `AppPadding` for all standard spacing.
- Use `AppTextStyles` and `AppColors` for consistent style.
- Keep gallery-specific components in `store_gallery_widgets/`.
- Day headers use a plain date stamp (`Sep 17`) — no `(Today)` / `(Yesterday)`
  brackets. Product titles under a multi-product day stay unchanged.

## Logic Ownership
- Gallery presentation should only handle image display and user interaction mapping.
- Keep side effects and navigation actions in listeners or route-level handlers.
- Avoid embedding unrelated domain logic in gallery widgets.
- Carry `isOwnStore` from store profile into gallery state and product-details args.
- Opening product details passes a flat `galleryFeed` (day → product → photos order) so details can swipe across all gallery items, not one group.
- When product details returns updated/deleted, update `StoreGalleryBloc` locally.
- Pop gallery with `{products: ...}` so store profile can sync the snapshot.

## Route and Navigation Notes
- Route registration stays centralized in navigation setup.
- Preserve shared Cupertino-like transitions for consistency.

## Folder Scope
- `store_gallery_route.dart`: gallery route entry.
- `store_gallery_widgets/`: gallery-specific visual components.
