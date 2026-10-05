# Add Store Product Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/add_store_product/`.

## Mandatory Update Rule
- If add-product form fields, gallery flow, validations, submission steps, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full routes.
- Use `AppPadding` for spacing.
- Use `AppTextStyles` and `AppColors` for all text and color usage.
- Reuse shared controls before introducing new one-off components.
- `BulkItemTile` / group-route thumbnails use `ProductMediaImage` (local file **or** network URL).
- Product photo editing uses shared `ProductImageCropper` → WhatsApp-style
  `ProductImageEditorPage` (`pro_image_editor`): crop/rotate, text, freehand pencil,
  round/square/arrow marks, emoji. **Not forced after pick** — after camera/gallery
  selection the flow goes straight to the title screen. Edit is optional from the
  photos sheet (current photo or **Edit all**). Cancel keeps the original path.
  Edit form replace clears `assetId` so the edited file is uploaded as a new local
  and the previous photo id is deleted on save.

## Logic Ownership
- This feature handles product **creation** and **edit** presentation.
- Create (title-only): direct S3 pipeline via `ProductUploadCoordinator` —
  compress to JPEG (true max edge 2560 / quality 85) + ThumbHash from RGBA
  on-device, `POST .../uploads/presign` (staging keys), concurrent S3 PUT of the
  exact compressed bytes (3 at a time; silent retries 2s/4s/8s; renew URL if
  expired/403), then JSON `POST /collections` with
  `photos: [{key, thumbhash, width, height, bytes, originalName}]` plus
  `clientRequestId` / `Idempotency-Key` (1–50 photos, each ≤500 MB before compress).
  **Required:** `name`/`title`. **Optional:** `tag`, `description` (API tag ≤40,
  description ≤1000).
- Create (weight/purity/size path): same direct-S3 create with JSON
  `specifications` + `usePrecisionTag` + optional `tag`/`description`, then
  `POST .../subgroups` for Precise/Standalone clusters that share identical specs.
  Group-tagged items stay in `mainGroupPhotos`.
- Specs are all-or-nothing on the API: `weight`, `otherDeduction`, `purity`, `wastage`,
  `size`, `metalType`, `category`. Deduction type matches weight type; deduction must
  be strictly less than weight. Wastage Varied → `0`; Size Varied → `free_size`.
- Edit (`mode: edit` form):
  - Photos unchanged → JSON metadata PATCH.
  - New locals → S3 presign/PUT then `POST .../photos` JSON append (+ metadata PATCH).
  - Removed existing → `POST .../photos/delete` with `photoIds` (after adds so ≥1 remains).
  - Same listing id throughout (no create+delete republish).
  - `name` / `tag` / `description` are collection-level. There is no API to change title, tags, or description for only one photo. Edit-form helper copy states this when more than one photo is present.
- Edit photo UI matches create (add/delete/reorder via carousel + edit / edit-all);
  require at least one photo.
  Server order for kept photos may not change on reorder-only edits.
- Partial S3 / commit failures: keep the collection for successful photos and show a snackbar summary.
- Use listeners for side effects and post-submit navigation.
- Keep non-product-creation domain logic out of this feature presentation layer.

## Create flow (unified group screen)
- After photos are picked (store profile picker **or** gallery continue), create always opens
  `add_product_group_route` first. Do not send **edit** (`mode: edit`) through this screen.
- Gallery continue → `add_product_group_route` (not directly to the form).
- Screen 01 (`add_product_group_route`): first photo thumbnail (+ count badge)
  beside **title** (required), then **tags** (optional — type field + **plus**;
  chips below; suggested tags horizontal scroll), always-visible
  `ProductSpecForm`, then **Add description** at the bottom (tap to expand;
  same clear-on-hide logic). Tap the photo → iOS-style centered preview
  (`showBulkPhotosIosPreview`: blur backdrop, no top chrome; same add /
  delete / edit icons on the image, bottom thumbnail scroller; keep ≥1
  photo). Tap outside to dismiss. Add from that preview uses shared `showMediaSourceSheet` (Camera /
  Gallery); Gallery opens `ProductGalleryPicker` (`drag_select_grid_view`),
  same as store-profile Add products. Multi-photo pick goes straight to this
  screen (no forced crop).
- **Specs incomplete / blank:** CTA **Publish to store** enqueues title-only create on
  `ProductUploadCoordinator` and **immediately** pops to store profile (no button
  loader). Store shows a pending shimmer slot; snackbar on success.
- **Specs valid:** CTA **Continue · N items** → `BulkUploadApplyGroupSpec` →
  preview (same as former expanded more-details path).
- Preview (after more details): photo grid (pinch columns, Precise blue dot). Select →
  **Edit** / **Delete** only. Tap item → precise form (`add_product_group_details_route`
  single). Multi Edit → shared specs batch. Group apply marks **Group**; single/multi
  save marks **Precise**. Create **Done** enqueues specs upload on
  `ProductUploadCoordinator` and pops to store immediately (no progress button /
  Published screen). **Ungroup** remains post-publish only (collection browse).
  Edit-mode **Save changes** still waits on the preview button.

## Edit refine flow (no Published)
- Product details Edit sheet:
  - **Edit title, tags & photos** → existing `add_product_form_route` `mode: edit`.
  - **Refine items & details** → hydrate `BulkUploadBloc.fromCollectionDetail` and open
    `add_product_group_preview_route` with `isEditMode: true`.
- Hydration: `groupTitle` = collection name; `description` / `tags` from collection;
  main photos → Group + collection specs;
  each sub-group photo → Precise (or Standalone if name contains `standalone`) + sub specs;
  `imagePath` may be a network URL.
- In edit mode preview:
  - Never show `_PublishedView`.
  - CTA: **Save changes**.
  - Photo strip / details sheets stay add/delete-locked, but **image edit**
    (crop / draw / text via `ProductImageCropper`) is enabled. Replaced locals
    are uploaded on save (append new photo, delete old id; remaps item ids).
  - Save: sync edited photos → PATCH collection specs + `usePrecisionTag`; then:
  - `POST .../subgroups` for Precise/Standalone items still in `mainGroupPhotos`
  - `PATCH .../subgroups/:id` for Precise/Standalone items already in a sub-group
    (name / specs / `usePrecisionTag`)
  - Pop `{updated: true, ...product}` via `shouldPopWithResult` (no Published UI).
  Photo moves / Ungroup happen on `collection_browse_route` (own store) via
  `POST .../photos/move`.

## Route and Navigation Notes
- Keep all route setup centralized in navigation files.
- Use shared Cupertino-style transitions.
- Create args for group title: `selectedItems`, `storeId`.
- Group details/preview: pass the same `BulkUploadBloc` via `bloc` + optional `scope` /
  `itemId` (`BlocProvider.value`). Do not create a second bloc for those screens.
- Edit specs (collection-level): `edit_product_specs_route` with `storeId`, `listingId`,
  `revision`, optional `title` / `specifications` (`ProductSpec`).
- Edit metadata/photos args: `mode`, `storeId`, `listingId`, `revision`, `title`,
  `description`, `tags`, `imagePaths`, `photoAssetIds`.
- Pop result includes product map plus optional `revision` / `apiTag` for details refresh.

## Folder Scope
- `add_product_form_route.dart`, `add_product_gallery_route.dart`: add-product routes
  (form is **edit** metadata/photos; create uses group route).
- `add_product_group_route.dart`: create — title / tags / always-visible details
  (weight/purity/size) / expandable description at bottom. Title-only publish
  when specs incomplete; **Continue** → preview when specs valid.
- `add_product_group_details_route.dart`: single / multi precise refine from preview
  (group-scope form also still works if navigated).
- `add_product_group_preview_route.dart`: item grid, select actions, publish / edit save.
- `edit_product_specs_route.dart`: collection-level weight/purity/size edit.
- `add_store_product_widgets/`: widgets scoped to add-product screens.
