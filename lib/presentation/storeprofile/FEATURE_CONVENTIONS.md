# Store Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/storeprofile/`.

## Mandatory Update Rule
- If store profile sections, product preview behavior, actions, import triggers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full route rendering.
- Use `AppPadding` for consistent spacing.
- Use `AppTextStyles` and `AppColors` for all display text and palette.
- Keep reusable controls shared; keep store-profile-only visuals inside local widget folder.
- Product grid shares one `CustomScrollView` with the profile header. The header
  **starts collapsed** (compact bar + `PRODUCTS · N`) so landing is listing-first.
  Compact identity shows **logo + store name only** (no link subtitle). Tap it to
  expand store details (logo, name, copy link, members, Add products / Import).
  While expanded, the compact identity is hidden; tap the header again or
  **actively drag** the product list upward to collapse. Bounce-back / fling
  after finger lift does not collapse. Expand/collapse uses a curved animation
  (~380ms).
- Toolbar: **search** icon always on the right (opens `store_search_route`).
  While collapsed, a **blue** circular action also shows when applicable: own
  store → **+** (add products); other store (when `canImport`) → **download**
  import icon. When expanded, that blue icon fades away because the actions row
  already has Add products / Import. No gallery or import-requests icons in the
  app bar.
- Other-store **Import products** still appears on the expanded actions row
  **only when the viewer already has their own store** (`viewerHasOwnStore` /
  `canImport`); otherwise expand is view-only. The products row is
  `PRODUCTS · N` then **View all** when products exist → `store_gallery_route`.

## Logic Ownership
- Store profile screens manage store profile presentation and interaction events.
- Use listeners for side effects and navigation (info + error snackbars).
- Keep import/listing/team/auth business logic out of widget build code.
- Own store: load members via `GET /stores/:storeId/members`. Expanded header always shows `N members · M products` (including `0 members`). Below that row, **Add member** → `add_team_route` with `returnToProfile: true`; on Done/Skip/back, pop to store profile and refresh members. Missing catalog names are filled from device contacts by phone via shared `DeviceContactNames` (E.164 / normalizedNumber / last-10; quiet, no loader).
- Other stores: do not call members API (owner-only); show products count only.
- Products + collage images are **cache-first**:
  API responses are written to `StoreProductsCache`, then the UI paints
  only from that cache. Soft-prefetch warms the first listing stores and
  store tap; profile joins that warm so landing paints full collages with
  images already on disk (no shimmer when warm/cached). Cold path (empty
  cache, no prefetch) still shows shimmer once. After publish / update /
  delete / import, the mutation result is committed to cache immediately,
  then a quiet GET refresh rewrites the cache again.
- **Create upload UX:** on Publish/Done, upload runs in
  `ProductUploadCoordinator` while the user returns to store profile immediately.
  Existing products stay painted; only the in-flight listing shows a shimmer
  slot at the **top** of the product grid (before existing tiles), matching
  **Group** / **Single** / **Gallery** view. The server listing created
  mid-upload is **hidden** from the grid (and skipped by prefetch / quiet
  refresh) until all photo batches finish — avoids partial tiles beside the
  shimmer. Success → replace shimmer with the product at index 0 + snackbar
  (`Product published to store.`). Quiet refresh / listCollections stay
  **newest-first** so the new tile does not jump after upload. Pending
  uploads live on the coordinator singleton, so leave/return still shows the
  correct shimmer until the upload finishes.
- Network media uses `CachedNetworkImageProvider` with a **file-based**
  `CacheManager` (`JsonCacheInfoRepository` — no sqflite) + `gaplessPlayback`
  so disk cache works without MissingPluginException and rebuilds do not flicker.
- Other store (when viewer has own store): quiet `GET /import-targets` probe
  marks already-imported / pending listings with a top-right **Added** /
  **Pending** chip (same as import-select). Product cards show **title only**
  (tags / meta under the title are hidden). Refresh probe after returning from
  import flow.
- Own store: import-requests inbox lives on the **Profile tab** (not store
  profile app bar). Store profile no longer shows the inbox badge icon.
- Store header meta is **cache-first** via `StoreMetaCache` (name, link,
  cover, showcase images). Listing seeds cover URLs into that cache so the
  logo does not flash-load; `GET /stores/:id` and image append/delete write
  the cache again, then UI reads from cache.
- Product layout follows Settings → **View products** (`ProductViewPreferences`
  / `AppSettingsStorage`, survives logout): **Group** (2-col cards, default),
  **Single** (one large card per row), **Gallery** (light-theme photo mosaic
  by day, same sectioning as `store_gallery_route`).
- Own-store product delete: long-press a product to enter selection mode
  (single or multi), then Delete on the selection bar. Confirm dialog →
  `StoreProfileProductsDeleted` (sequential `DELETE .../collections/:id`).
  Per-card close/delete icon is removed. Not available on other stores.
- Store showcase images (1–5): loaded via `GET /stores/:id` into `coverImageUrl` /
  `storeImages`. Own-store logo camera opens `store_images_manager_sheet` — same
  carousel bottomsheet pattern as group photo preview (`ProductImageCarousel` +
  Camera/Gallery picker). Append via `POST .../images`, delete via
  `DELETE .../images/:imageId` (max 5).
- Group collage (`ProductImageCollage`): 1–9 keep Telegram layouts; **10+** uses
  horizontal pages of 3×3 (9 per page) so the outer product list keeps vertical
  scroll. Cell taps still report absolute `imagePaths` indexes.
- Product grid tap depends on product view mode:
  - **Group**: opens `collection_browse_route` (gallery-style selection), passing
    product + store meta. Collage cell taps use the same destination (any tile
    opens browse for that listing). Browse may bubble `deleted` / `updated` the
    same way product details does — apply `StoreProfileProductUpdated` /
    `StoreProfileProductDeleted`. Tap a photo in browse → `product_details_route`
    with that photo’s `imageIndex`.
  - **Single** / **Gallery**: opens `product_details_route` for the tapped
    listing. Collage / gallery tiles pass the tapped photo `imageIndex` (mapped
    to the original `imagePaths` index) + a flat `galleryFeed` across store
    photos so details lands on that image, not always the first. Same
    `deleted` / `updated` pop handling as browse.
- Optional route arg `focusProductId` (from search product-details store chevron)
  scrolls to that listing and draws a primary (blue) border around its group
  card. Tap still follows the view-mode rules above.
- Photo-only deletes from details return `updated`; last-photo delete returns `deleted` after the collection is removed. A follow-up `StoreProfileProductDeleted` treats 404 / `COLLECTION_NOT_FOUND` as already gone.
- Whole-product delete on **your store** uses long-press → multi-select → Delete (not a stacked close icon). Confirm dialog, then `DELETE /stores/:storeId/collections/:listingId` (batch via `StoreProfileProductsDeleted`). Not shown on other stores.
- Do not show add-product / team CTAs on other stores. Product details receive `isOwnStore` so own-store originals can edit even when list permissions omit `edit`. Selection delete is gated by `isOwnStore`.
- Import is gated by `viewerHasOwnStore` (session `ownStoreId`): hide Import CTAs and refuse `_openImport` / import probe until the user has created a store (Profile tab **Create store** → `store_setup_route` → team → store listing).
- Opening the gallery also passes `isOwnStore` so details opened from a photo keep the same edit gate.
- **Add products** / app-bar **+** opens shared `showMediaSourceSheet` (handle,
  title, Camera / Gallery rows with chevrons; no Cancel — dismiss via tap
  outside or drag). Camera uses `image_picker`. Gallery opens
  `ProductGalleryPicker` bottomsheet (album dropdown with covers — not a nested
  sheet; multi-select via `drag_select_grid_view`: tap toggle + hold/slide
  range select; numbered badges; max 50), then `add_product_group_route`
  (title page). Crop/draw/text is optional from the photo strip there
  (`ProductImageCropper`), not forced after pick.

## Collection browse
- `collection_browse_route` fetches `GET .../collections/:id` on land.
- Layout mirrors `store_gallery_route`: plain date header (`Sep 17`, no
  Today/Yesterday brackets), section titles (main = collection name; custom
  sub-group names only — auto `{title} precise|standalone {n}` stay under the
  collection title), pinch-to-zoom column count (min 4). Keeps
  `AppColors.background` (not the dark gallery chrome). Top bar shows the store
  name (with Select / Edit / Ungroup when own store).
- Photo order: main group, then each sub-group (no nested browse cards).
  Section keys stay distinct when two custom-named sub-groups share a display
  name. Auto publish names (`{title} precise {n}` / `{title} standalone {n}`)
  merge under the collection title — no separate section header (Precise still
  uses the blue dot). Only **custom** sub-group names get their own section title.
- Photos in a Precise sub-group get a small **blue dot** on the right (not a
  “Precise” text chip); Standalone stays unmarked.
- Tap any tile → `product_details_route` with a flat photo `galleryFeed` in
  browse order (main → sub-groups), so details can swipe through every image
  regardless of section/date/title. Also passes `imageIndex` in the full
  `photos` list.
- Own store only: **Select** → **Edit** / **Ungroup** (or Done).
  - **Edit**: opens refine preview for the selection (auto-opens single/multi
    details). Save uses PATCH collection + create/update sub-groups, then refresh.
  - **Ungroup**: selection must share one source (main or the same sub-group).
    Destinations: Main / Existing sub-group / New sub-group / New collection via
    `POST .../photos/move`, then refresh. New collection requires ≥1 photo left
    in the source collection. Popping browse after a new-collection move returns
    `refreshCollections` / `newCollectionId` so store profile reloads the product grid.
- Browse shows all singles (no collage cap). Loading / error use `AppTextStyles`.

## Route and Navigation Notes
- Keep route registration in centralized navigation files.
- Use shared Cupertino-style page transitions.
- Add members from profile uses `pushNamed(add_team_route, returnToProfile: true)` and returns to the profile (does not clear to listing).
- Own-store **Add products** / blue app-bar **+** opens `showMediaSourceSheet`
  then camera (`image_picker`) or gallery (`ProductGalleryPicker`) then
  `add_product_group_route` (title / tags / description → publish title-only
  **or** expand more details for weight/purity/size → preview). Edit metadata
  still goes through product details → edit sheet → `add_product_form_route`
  with `mode: edit`.
- Refine items opens preview in `isEditMode` (no Published screen).
- App-bar **search** icon → `store_search_route` with `storeId`, `storeName`,
  `productCount`.

## Folder Scope
- `store_profile_route.dart`: store profile route.
- `collection_browse_route.dart`: gallery-style collection photo browse (date /
  section titles / pinch zoom + Select) after tapping a collection.
- `storeprofile_widgets/`: profile-specific visual sections/components, including
  the collapsing header, product grid, and embedded gallery sliver.
