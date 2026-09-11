# Product Details Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/product_details/`.

## Mandatory Update Rule
- If product detail layout, metadata rendering, actions, media behavior, or requirements change, update this file in the same PR.

## UI Rules
- Wrap route with `ScreenWrapper`.
- Use `AppPadding` for layout spacing.
- Use `AppTextStyles` and `AppColors`.
- Keep product-detail-specific visual pieces in `product_details_widgets/`.
- On land, show the photo only. Tap the image to toggle the top chrome (store name, link, share / edit / delete) and the bottom panel (tags, description, thumbnails).
- Product title appears under the store header when chrome is visible — not inside the app-bar icon row and not in the bottom panel. System / `PopScope` back still works when chrome is hidden.
- Show **edit** and **remove photo** when `permissions.edit` is true, or on your own store for originals (`kind != imported`). Other stores stay read-only.
- Title, tags, and description are collection-level: one set for every photo. The API has no per-photo captions. Hint copy appears when the owner can edit a multi-photo product.

## Logic Ownership
- Product details presentation should render product state and dispatch user actions only.
- Keep side effects in listeners/handlers outside build-only sections.
- Do not mix unrelated feature domain logic into this folder.
- When `storeId` is provided, load full collection photos via `GET /stores/:storeId/collections/:id` (list API only supplies cover).
- Capture `revision`, `apiTag`, and permission flags from that detail response.
- Route args include `isOwnStore` (from store profile / gallery) so edit stays available if the detail payload omits `permissions.edit`.
- Edit opens `add_product_form_route` in `mode: edit` (metadata PATCH, or photo add/remove when photos change). Changing title/tags/description updates the whole collection, not a single photo.
- Delete icon on a multi-photo product removes **the current photo only** (`POST .../photos/delete`).
- Last photo: confirm that the whole product will be deleted, then `DELETE /stores/:storeId/collections/:listingId` and pop `{deleted: true, productId}` so store profile / gallery can sync.
- After a successful photo remove or edit, pop with `{updated: true, ...product}` so store profile / gallery can sync.
- Whole-product delete also lives on the store profile grid close button.

## Route and Navigation Notes
- Register route through centralized navigation files.
- Keep shared transition style consistent.

## Folder Scope
- `product_details_route.dart`: product details route.
- `product_details_widgets/`: product details specific widgets.
