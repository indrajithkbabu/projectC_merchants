# Add Store Product Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/add_store_product/`.

## Mandatory Update Rule
- If add-product form fields, gallery flow, validations, submission steps, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full routes.
- Use `AppPadding` for spacing.
- Use `AppTextStyles` and `AppColors` for all text and color usage.
- Reuse shared controls before introducing new one-off components.

## Logic Ownership
- This feature handles product **creation** and **edit** presentation.
- Create: multipart `POST /collections` with `name`/`tag`/`description` + `photos`
  (1–25 photos, each ≤25 MB; picker downscales to ~1920px / quality 85).
- Edit (`mode: edit`):
  - Photos unchanged → JSON metadata PATCH.
  - New locals → multipart PATCH append photos (+ metadata).
  - Removed existing → `POST .../photos/delete` with `photoIds` (after adds so ≥1 remains).
  - Same listing id throughout (no create+delete republish).
  - `name` / `tag` / `description` are collection-level. There is no API to change title, tags, or description for only one photo. Edit-form helper copy states this when more than one photo is present.
- Edit photo UI matches create (add/delete/reorder via carousel); require at least one photo.
  Server order for kept photos may not change on reorder-only edits.
- Partial `failedPhotos` on 201/200: keep the collection and show a snackbar summary.
- Use listeners for side effects and post-submit navigation.
- Keep non-product-creation domain logic out of this feature presentation layer.

## Route and Navigation Notes
- Keep all route setup centralized in navigation files.
- Use shared Cupertino-style transitions.
- Edit args: `mode`, `storeId`, `listingId`, `revision`, `title`, `description`,
  `tags`, `imagePaths`, `photoAssetIds`.
- Pop result includes product map plus optional `revision` / `apiTag` for details refresh.

## Folder Scope
- `add_product_form_route.dart`, `add_product_gallery_route.dart`: add-product routes.
- `add_store_product_widgets/`: widgets scoped to add-product screens.
