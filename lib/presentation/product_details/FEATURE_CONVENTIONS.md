# Product Details Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/product_details/`.

## Mandatory Update Rule
- If product detail layout, metadata rendering, actions, media behavior, or requirements change, update this file in the same PR.

## UI Rules
- Wrap route with `ScreenWrapper`.
- Use `AppPadding` for layout spacing.
- Use `AppTextStyles` and `AppColors`.
- Keep product-detail-specific visual pieces in `product_details_widgets/`.
- On land, show the photo only. Tap the image to toggle the top chrome (back,
  share / edit / delete) and the bottom panel (specs, description, thumbnails).
- Product title appears under the icon row when chrome is visible, with the store
  name as a subtitle under the title (store link is not shown). System /
  `PopScope` back still works when chrome is hidden.
- Title is **photo-aware**: main photos use `{collectionName} {n}`; Precise/Standalone
  photos use `{subGroupName} {n}` (same numbering as collection browse). Swiping
  updates the title.
- Bottom panel (when chrome is visible): **Fine weight** line (when computable)
  above the weight/purity/size line from `precisionTag` / specs for the current
  photo (no “Precise” / “Group” label above the line). Title-only collections
  omit that line. Fine weight = net × (purity% + wastage%) / 100; when there is
  no other deduction, net equals gross. Example: purity 92, wastage 2%, net 25g
  → `Fine weight : 23.5g`. Display mapping for `precisionTag`:
  - `22K (92%) | 55g | 2% W | Free Size` → `92 | Gross 55g | 2% | Free Size`
  - `22K (92%) | 25g (Net: 20g) | 1% W | Free Size` → `92 | Net 25g | 1% | Free Size`
  - `22K (92%) | 10-20g | 1% W | Free Size` → `92 | Gross 10-20g | 1% | Free Size`
  (karat dropped; purity without `%`; plain/range weight → Gross; weight with Net →
  Net + gross grams; wastage drops the `W`). Specs fallback uses the same shape.
  Collection tags are hidden here (still editable via Edit). Description still
  shows when present.
- Edit title/tags/description remain collection-level (API has no per-photo captions).
- Show **edit** and **remove photo** when `permissions.edit` is true, or on your own store for originals (`kind != imported`). Other stores stay read-only.

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
  dates/groups/sections), not only one cluster. The bottom thumbnail strip
  uses the same feed order as the browse/gallery grid (not API `photos`
  order). Activating another product (gallery) loads its detail quietly.
  PageView uses iOS-style bouncing physics.
- From other entries without a feed, swipe stays within that product’s photos.

## Route and Navigation Notes
- Register route through centralized navigation files.
- Keep shared transition style consistent.

## Folder Scope
- `product_details_route.dart`: product details route.
- `product_details_widgets/`: product details specific widgets.
