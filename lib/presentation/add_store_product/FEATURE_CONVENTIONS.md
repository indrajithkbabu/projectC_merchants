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

## Logic Ownership
- This feature handles product **creation** and **edit** presentation.
- Create (title-only): multipart `POST /collections` with `name`/`tag`/`description` + `photos`
  (1–50 photos, each ≤500 MB; picker downscales to ~1920px / quality 85).
  Multi-photo create uploads the first photo on `POST`, then appends the rest in
  batches of 2 via multipart `PATCH` (on nginx **413**, retries that batch one
  file at a time) to avoid body-size failures.
- Create (weight/purity/size path): same create endpoint with JSON `specifications` +
  `usePrecisionTag`, then `POST .../subgroups` for Precise/Standalone clusters that
  share identical specs. Group-tagged items stay in `mainGroupPhotos`.
- Specs are all-or-nothing on the API: `weight`, `otherDeduction`, `purity`, `wastage`,
  `size`, `metalType`, `category`. Deduction type matches weight type; deduction must
  be strictly less than weight. Wastage Varied → `0`; Size Varied → `free_size`.
- Edit (`mode: edit` form):
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

## Create flow (bulk group title)
- After photos are picked (store profile picker **or** gallery continue), create always opens
  `add_product_group_route` first. Do not send **edit** (`mode: edit`) through this screen.
- Gallery continue → `add_product_group_route` (not directly to the form).
- Screen 01: horizontal photo strip (scrolls when thumbs overflow), group title,
  then two actions. Title is required. Tap a strip photo → bottomsheet carousel
  (add / delete, same pattern as `add_product_form_route`; keep ≥1 photo).
  Edit/refine hydrate is preview-only (read-only sheet).
- Group / multi details photo strips use the same bottomsheet preview.
- **Upload with title only** continues the existing form (`add_product_form_route`)
  with `title` + `selectedItems` + `storeId`. Publish still uses `POST /collections`
  without specifications.
- **Add weight, purity & size** uses `BulkUploadBloc`:
  - Group form (02): weight Fixed/Range, optional stone deduction (`otherDeduction`),
    live net; purity Fixed/Varied; wastage %; size Free/Fixed/Varied;
    metal/gemstone chips; category dropdown.
  - Preview (03/06): photo grid only (no `{groupTitle} {n}` captions, no
    Group / Precise / Standalone text tags). Pinch-to-zoom column count matches
    collection browse (default 5, min 4). **Precise** items show a small blue
    dot on the photo (same pattern as collection browse). Standalone / Group
    have no dot.
  - Tap item → precise form (04). Select → **Edit** or **Delete** only (no Ungroup on preview).
    Single-item details: editable name + photo (change/remove) plus the weight/purity form.
    Multi-select Edit: treat as one batch — photo strip + shared specs only (no per-item
    name fields). Group-scope details allow editing the group title.
  - Group apply marks all **Group**. Single/multi save marks those items **Precise**.
    **Ungroup** is post-publish only (collection browse → Select → Ungroup → `photos/move`).
  - Publish CTA (**Done** / **Save changes**): while uploading, the button shows a
    fill + percentage (photo create/append batches, then subgroup steps) instead of
    a spinner. Create: first photo + batch append + sub-groups for Precise items,
    then show **Published** (06). **Done** / back pops preview → group → `store_profile_route`
    with the product map so the grid updates. Only **add** products use Published.

## Edit refine flow (no Published)
- Product details Edit sheet:
  - **Edit title, tags & photos** → existing `add_product_form_route` `mode: edit`.
  - **Refine items & details** → hydrate `BulkUploadBloc.fromCollectionDetail` and open
    `add_product_group_preview_route` with `isEditMode: true`.
- Hydration: `groupTitle` = collection name; main photos → Group + collection specs;
  each sub-group photo → Precise (or Standalone if name contains `standalone`) + sub specs;
  `imagePath` may be a network URL.
- In edit mode preview:
  - Never show `_PublishedView`.
  - CTA: **Save changes**.
  - Save: PATCH collection specs + `usePrecisionTag`; then:
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
- `add_product_form_route.dart`, `add_product_gallery_route.dart`: add-product routes.
- `add_product_group_route.dart`: group title after photo pick (create only).
- `add_product_group_details_route.dart`: group / single / multi spec form.
- `add_product_group_preview_route.dart`: item grid, select actions, publish / edit save.
- `edit_product_specs_route.dart`: collection-level weight/purity/size edit.
- `add_store_product_widgets/`: widgets scoped to add-product screens.
