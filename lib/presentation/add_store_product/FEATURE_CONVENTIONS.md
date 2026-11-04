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
  round/square/arrow marks, emoji. After store-profile gallery pick, flow opens
  `add_product_compose_route` (photo overlay details + send) before
  `add_product_group_route` (handoff). Edit remains optional later from the
  photos sheet (current photo or **Edit all**). Cancel keeps the original path.
  Edit form replace clears `assetId` so the edited file is uploaded as a new local
  and the previous photo id is deleted on save.

## Logic Ownership
- This feature handles product **creation** and **edit** presentation.
- Create (title-only): direct R2 pipeline via `ProductUploadCoordinator` —
  compress to **WebP** (EXIF-aware single-pass max edge 1080 / quality 85;
  prepare concurrency 3) + ThumbHash from a native ~100px preview of the
  compressed master (full-master compute fallback) on-device,
  `POST .../uploads/sign` (imageId + url/thumbnailUrl/detailUrl +
  `presignedUrl`, `image/webp`), concurrent R2 PUT of the exact compressed
  bytes (3 at a time; silent retries 2s/4s/8s; renew URL if expired/403),
  then JSON `POST …/products/batch` with `image_id` + thumbhash/specs (falls
  back to legacy `POST /collections` only if sign returns no `imageId`) plus
  `Idempotency-Key` (1–50 photos, each ≤500 MB before compress).
  **Required:** `name`/`title`. **Optional:** `tag`, `description` (API tag ≤40,
  description ≤1000). Debug: filter `CatalogMediaDBG` / `CatalogUploadStory`.
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
- Partial S3 failures (form create path): show `CatalogPartialUploadBar` —
  **Publish N Photos** / **Retry Failed (N)** before Mongo commit. Background
  coordinator create auto-commits successes and snackbars remaining failures.
  Form fields are never cleared on partial failure.
- Use listeners for side effects and post-submit navigation.
- Keep non-product-creation domain logic out of this feature presentation layer.

## Create flow (unified group screen)
- Store profile **Add products**: `ProductGalleryPicker(includeCamera: true,
  confirmAsSend: true)` — green WhatsApp **send** icon + count (not Done text).
  Telegram-style gallery **bottomsheet** (lightweight `PopupRoute`: barrier,
  slide-up, rounded sheet, drag handle, tap-outside dismiss); permission +
  thumbs warm during open; **badge** toggles/deselects; photo **body** selects,
  or opens compose when tapping an already-selected photo (`initialIndex`);
  hold-and-slide multi-selects; **send** continues. Live camera stays on while
  scrolling (stable Texture under Transform); `pausePreview` only when the cell
  scrolls off-screen (controller kept). Thumbs reuse cached
  `AssetEntityImageProvider` instances. Gallery awaits live-camera dispose
  before pop so CameraX close does not race compose. Compose decodes photos at
  display/`cacheWidth` size (not full-res). Then →
  `add_product_compose_route` (**Quick Upload v4**): full-bleed photo; quieter
  right rail (no white rings; metal text Gold/Silver/Rose/Plat; wastage default
  **4%**, ±0.5); top-left **NET WEIGHT** readout (36px fixed; tap → decimal
  keypad; **+ Stone** then **Range** toggle below it (success green when
  on — no Fixed/Range pill); bottom
  **scrolling weight scale** (`ComposeWeightScale`: 0.5g steps, tick centers
  under needle, labels 0.5/5/10/20…, soft edge fade only — no hard panel;
  scroll/tap share the same offset→value mapping; draft commits on settle) +
  optional **stone scale** (0.1g); Range mode: tap inactive ring or net
  min/max readout to switch end; multi **product name** chips (+ / Return /
  comma / backspace; metal/category chips have no x); **crop** icon +
  add/delete; send. Photo has **no** pinch-zoom. Keyboard does **not**
  resize the photo (`resizeToAvoidBottomInset: false`). Payload: same
  fields — `tags[]` may include spaces; no new BE keys. All-scope appends
  inherit current draft. Do not send **edit** (`mode: edit`) through compose.
- Gallery continue → compose → `add_product_group_route` with
  `composeOverlay: true`, `groupSpec`, `tags`, `initialTitle` (derived), plus
  `stockStatus` / `mtoDays` / `isLocked`. Group route skips the old form UI and
  applies the same gates immediately.
- **Specs incomplete / blank:** title-only create on `ProductUploadCoordinator`
  → sign + S3 + `POST …/products/batch` (one product per photo; stock/lock/
  compose defaults). Falls back to legacy `POST …/collections` only if sign
  returns no `imageId`.
- **Specs valid:** `BulkUploadApplyGroupSpec` → preview (unchanged).
- Preview (after more details): photo grid (pinch columns, Precise blue dot). Select →
  **Edit** / **Delete** only. Tap item or **Edit** → `add_product_compose_route`
  with `initialDrafts` (hydrated specs / tags / stock) + `returnResult: true`
  (not the old `add_product_group_details_route`). Send pops drafts back; preview
  applies via `BulkUploadApplyItemSpec` / `BulkUploadApplyMultiSpec` (valid specs
  only → **Precise**). Create **Done** enqueues specs upload on
  `ProductUploadCoordinator` → `POST /uploads/sign` (+ store aliases) + S3 PUT +
  `POST …/products/batch` with `Idempotency-Key` (stock/lock +
  `collectionDefaults`). Leave via
  `leaveCreateProductFlow` → Discover `store_profile_route` (pending shimmer);
  if that route is missing from the stack, push own-store profile (never stop
  at shell home alone). **Ungroup** remains post-publish only (collection
  browse). Edit-mode **Save changes** still waits on the preview button.
- Compose rail lock / All↔This photo: **no snackbars** on the upload path.
  **Import mode** (`importMode`, opened from visitor photo selection) uses
  the same screen. Top bar reads **From {store}**. Add-photo is hidden;
  crop and delete stay. **Stock:** editable when the source photo is unlocked;
  read-only (link badge; tap explains it follows the source) when the source
  is locked. A source lock cannot be cleared. The importer can lock an
  unlocked photo (toast). **This photo** is the default. Turning on **All**
  does not copy the current photo onto the others; later edits apply to every
  photo, except a source lock (and stock when source-locked). Notice above
  the strip for a source lock or out of stock. Send returns a `quickImport`
  payload; `QuickImportFlow` posts `POST …/imports` (not the upload path).

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
- Create args for group title: `selectedItems`, `storeId`, optional
  `initialTitle` (from compose note).
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
- `add_product_group_details_route.dart`: legacy precise form (route kept; preview
  Edit / tap no longer navigates here — use compose refine instead).
- `add_product_group_preview_route.dart`: item grid, select → compose refine,
  publish / edit save. Browse Select→Edit passes `autoOpenEdit` + stock/lock.
- `edit_product_specs_route.dart`: collection-level weight/purity/size edit.
- `add_store_product_widgets/`: widgets scoped to add-product screens.
