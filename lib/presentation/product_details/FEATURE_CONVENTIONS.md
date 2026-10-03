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
  product title (16 / w600) + overflow `⋮`**, store name, category) and the
  bottom weight panel. Multi-photo browsing is via horizontal PageView swipe;
  optional **Preview all** thumbnail strip (see overflow menu). Pinch to zoom
  (1×–4×) and pan while zoomed; at 1× horizontal swipes change photos.
  Double-tap toggles ~2.2× zoom. Page swipe is disabled while zoomed so pan
  stays smooth.
- Product **title** sits to the right of the back button when chrome is shown.
  **Store name** sits under that toolbar row. From **search**, a `>` chevron
  appears beside the store name — tap opens `store_profile_route` for that
  store with this listing’s group card highlighted (primary border) and scrolled
  into view. Tapping the group opens `collection_browse_route` (all items in
  the group) as usual. System / `PopScope` back still works when chrome is
  hidden.
- **Category** shows as a search-style pill under the store name **only when
  Preview details is on** (same gate as weight). Source is collection
  `specifications.category` (sub-group overrides when the photo belongs to one);
  search may seed `category` until detail loads. Display is title-cased
  (`ring` → `Ring`). Hidden when category is empty or Preview details is off.
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
  default**): when checked, category pill + weight chrome show; unchecked hides
  category, weight line, arrow, and all weight details. Description still shows
  when present. Choices are persisted in `ProductDetailsPreferences` /
  `AppSettingsStorage` (survives logout and every re-entry to product details
  until the user changes them). Available from search and browse entry.
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
- When `storeId` is provided, load full collection photos via `GET /stores/:storeId/collections/:id` (list API only supplies cover).
- Capture `revision`, `apiTag`, permission flags, specs, and `subGroups` from that detail response.
- Route args include `isOwnStore` (from store profile / gallery / browse) so edit stays available if the detail payload omits `permissions.edit`.
- **Edit** opens a bottom sheet:
  - **Edit title, tags & photos** → `add_product_form_route` in `mode: edit` (metadata PATCH, or photo add/remove when photos change). Changing title/tags/description updates the whole collection, not a single photo.
  - **Refine items & details** → hydrate `BulkUploadBloc` from collection detail and open preview in `isEditMode`. Save patches specs / creates new subgroups; **never** shows the bulk Published (06) screen. Pop applies `{updated: true, ...product}` like form edit.
- Delete icon on a multi-photo product removes **the current photo only** (`POST .../photos/delete`).
- Last photo: confirm that the whole product will be deleted, then `DELETE /stores/:storeId/collections/:listingId` and pop `{deleted: true, productId}` so store profile / gallery / browse can sync.
- After a successful photo remove or edit, pop with `{updated: true, ...product}` so store profile / gallery / browse can sync.
- Whole-product delete also lives on the store profile grid close button.
- Entry is often via `collection_browse_route` with an `imageIndex` into the full photos list.
- From `store_gallery_route` / `collection_browse_route`, pass a flat
  `galleryFeed` of all photos so details can swipe across every image (all
  dates/groups/sections), not only one cluster. Activating another product
  (gallery) loads its detail quietly. PageView uses iOS-style bouncing physics.
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
