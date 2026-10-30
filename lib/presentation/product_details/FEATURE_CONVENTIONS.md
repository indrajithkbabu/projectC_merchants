# Product Details Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/product_details/`.

## Mandatory Update Rule
- If product detail layout, metadata rendering, actions, media behavior, or requirements change, update this file in the same PR.

## UI Rules
- Wrap route with `ScreenWrapper`.
- Use `AppPadding` for layout spacing.
- Use `AppTextStyles` and `AppColors`.
- Keep product-detail-specific visual pieces in `product_details_widgets/`.
- On land, show the photo only. Tap the image to toggle the top chrome (**back +
  product title (16 / w600) + thumbs-up (like) + heart (wishlist) + overflow
  `⋮`**) and the bottom weight
  panel. Do **not** show store name, store-group chevron, or category / title
  under the toolbar (owner and visitor). Multi-photo browsing is via horizontal
  PageView swipe (`allowImplicitScrolling`, fast iOS bounce; vertical dismiss
  uses a [Listener] so it does not compete with page drag). At **1×** the photo
  is not wrapped in `InteractiveViewer` (its scale recognizer made swipes
  sticky); double-tap enters zoom, then pinch/pan work; double-tap or pinch-out
  returns to 1×. Optional **Preview all** filmstrip (Telegram media-viewer):
  compact centered thumbs with **free-flow** fling (no snap). Fast flings do
  not jump the main pager (avoids rebuilds that kill momentum); the pager
  updates when the user slows to inspect, and again on scroll-end. Live
  highlight tracks the nearest centered thumb via a local notifier. Tap centers
  that thumb and shows the photo; pager swipes keep the strip 1:1 aligned.
  Photos follow InstantCatalogPhoto: ThumbHash placeholder then CDN master.
  Zoomed pinch (up to 4×) uses the same buffer via
  `InteractiveViewer` (`ProductMediaImage` locked to
  `CatalogImageCache.fullCacheWidth` so warm + paint share one ImageCache key;
  grids keep half-width). Channel/browse tap starts a full-width decode before
  push. API `quality: low` disables deep zoom. At 1× horizontal swipes change
  photos. Page swipe is disabled while zoomed so pan stays smooth.
- Product **title** sits to the right of the back button when chrome is shown.
  System / `PopScope` back still works when chrome is hidden.
- **Lock / stock / pending** (Preview details on): exceptional chrome — lock
  when `is_locked`, `production_quantity_limits` when out of stock, schedule
  when MTO, orange **Pending** pill when `importStatus` is pending (per photo
  via feed / `imageImportStatuses`). Unlocked + in-stock + live shows
  **nothing** (no Unlocked / In stock chrome).
- Title is **photo-aware**: main photos use the collection name; Precise /
  Standalone photos use the sub-group name **only when it is custom** (not the
  auto publish pattern `{title} precise|standalone {n}` — those fall back to the
  collection name; Precise is still marked by the browse blue dot). No photo
  counter next to the title. Swiping updates the title.
- Top actions (Edit / Share / Delete / Preview all / Preview details) open from
  a **popup dropdown** on the three-dot button (not a bottom sheet). Edit and
  Delete only when `canEdit`. **Preview all** (multi-photo only) is a checkbox:
  when checked, a horizontal thumbnail strip appears under the bottom weight
  panel; unchecked hides it. **Preview details** is a checkbox (**on by
  default**): when checked, exceptional lock/stock/pending icons + weight
  chrome show; unchecked hides lock/stock/pending, weight line, arrow, and all
  weight details.
  Description still shows when present. Choices are persisted in
  `ProductDetailsPreferences` / `AppSettingsStorage` (survives logout and every
  re-entry to product details until the user changes them). Available from
  search and browse entry.
- Share shares the **current photo file** (not a link) via the system share
  sheet so WhatsApp can send the image. Network photos are resolved through
  `CatalogImageCache` first.
- Bottom panel (when chrome is visible and **Preview details** is on): one
  **primary weight** line — `Fine` / `Net` / `Gross` title (white) + value in
  muted grey (e.g. `Net 78.35g`). Fine = net × (purity% + wastage%) / 100
  **only when purity, wastage, and net are all > 0**; otherwise fall back to
  Net (when stone deduction makes net ≠ gross) or Gross. A down-arrow expands
  purity / wastage / size details in muted grey. Description still shows when
  present. Collection tags stay hidden here (still editable via Edit).
- Edit title/tags/description remain collection-level (API has no per-photo captions).
- Show **edit** and **remove photo** when `permissions.edit` is true, or on your own store for originals (`kind != imported`). Other stores stay read-only (Share still available).

## Logic Ownership
- Product details presentation should render product state and dispatch user actions only.
- Keep side effects in listeners/handlers outside build-only sections.
- Do not mix unrelated feature domain logic into this folder.
- **Like vs Wishlist:** **thumbs up** is **public product like**
  (`PUT`/`DELETE /products/:productId/like`) for the **CatalogProduct** under
  the current photo — on multi-photo collections that is embedded
  `products[]._id` (photo asset id), **not** the collection listing id (so
  liking one piece does not light thumbs-up on every photo). Single-product
  multi-image (GET `/products/:id`) still likes that one product for all
  images. Does **not** create a wishlist row. Legacy collection cards without
  embeds may use photo-like aliases. Private wishlist (**heart**) uses
  `POST`/`DELETE /wishlist/products/:productId` for the same per-photo
  product id. Hydrate `liked` / `likeCount` / `wishlisted` from
  product/collection detail. Listing `likeCount` on the in-memory card is the
  **sum of per-photo product likes** (so one like in a collage bumps the
  store-grid badge). Chrome shows **like count** beside the thumbs-up (±1 on
  toggle). After like/unlike (or when aggregated counts are already > 0),
  pop includes `{updated: true, silent: true, …product}` so store profile
  refreshes chips without a snackbar. No snackbar on like/unlike; like stays
  interactive (no spinner) while the short API call runs (`isLikeBusy`
  still guards double-submit). Double-tap zoom is unchanged.
- **Photo views:** after ≥1s dwell on the current photo, enqueue
  `photo` (+ `collection` / `subgroup` when applicable) via `ViewBeacon`
  (`POST /views`). Chrome shows **photo `viewCount`** (eye chip) when the
  detail API includes it. Collection-level counts are shown on store profile
  tiles, not here.
- When `storeId` is provided, try `GET /products/:id` first (lock/stock +
  gallery). On miss, load collection photos via
  `GET /stores/:storeId/collections/:id` (list API only supplies cover).
- Capture `revision`, `apiTag`, permission flags, specs, and `subGroups` from
  the collection detail response when that path is used.
- Route args include `isOwnStore` (from store profile / gallery / browse) so edit stays available if the detail payload omits `permissions.edit`.
- **Edit** opens a bottom sheet:
  - **Edit** (single action, no choice sheet) → hydrate `BulkUploadBloc` from
    collection detail, open preview in `isEditMode`, and auto-open compose for
    the currently viewed photo (`returnResult` + filled drafts). Save on preview
    patches specs / creates new subgroups; **never** shows the bulk Published
    (06) screen. Pop applies `{updated: true, ...product}` like form edit.
  - Specs chrome reads flat `products[]` / `defaults` from collection detail
    (not only nested `specifications`).
  - **Availability** PATCHes real CatalogProduct ids (embedded `products[]._id`),
    never the collection listing id. On success, pop `{updated: true, …}` so
    store profile keeps lock/stock. Reopen hydrates lock/stock from collection
    detail with `products[]` preferred when collection-level fields lag.
- Delete icon on a multi-photo product removes **the current photo only** (`POST .../photos/delete`).
- Last photo: confirm that the whole product will be deleted, then `DELETE /stores/:storeId/collections/:listingId` and pop `{deleted: true, productId}` so store profile / gallery / browse can sync.
- After a successful photo remove or edit, pop with `{updated: true, ...product}` so store profile / gallery / browse can sync.
- Whole-product delete also lives on the store profile grid close button.
- Entry is often via `collection_browse_route` with an `imageIndex` into the full photos list.
- From `store_gallery_route` / `collection_browse_route`, pass a flat
  `galleryFeed` of all photos so details can swipe across every image (all
  dates/groups/sections), not only one cluster. Activating another product
  (gallery) loads its detail quietly. PageView uses fast iOS-style bouncing
  physics with adjacent-page preloading.
- From **search** (global / in-store), open with a `galleryFeed` of the **filtered
  result hits** (one slot per hit, seated on the tapped index). Swipe activates
  the next/previous hit and loads that listing’s detail (store meta updates when
  the hit’s store differs). Does not expand into other photos of the same
  collection. Browse / gallery feeds are unchanged.
- From other entries without a feed, swipe stays within that product’s photos.

## Route and Navigation Notes
- Register route through centralized navigation files.
- Keep shared transition style consistent.

## Folder Scope
- `product_details_route.dart`: product details route.
- `product_details_widgets/`: product details specific widgets.
