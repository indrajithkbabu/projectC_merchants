# Store Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/storeprofile/`.

## Mandatory Update Rule
- If store profile sections, product preview behavior, actions, import triggers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full route rendering.
- Use `AppPadding` for consistent spacing.
- Use `AppTextStyles` and `AppColors` for all display text and palette.
- Keep reusable controls shared; keep store-profile-only visuals inside local widget folder.
- Product grid shares one `CustomScrollView` with the profile header. The header **starts collapsed** (compact bar + `PRODUCTS · N`) so landing is listing-first. Tap the compact store identity (logo / name / link) to expand store details (logo, name, copy link, members, Add products / Import). While expanded, the compact identity is hidden; tap the header again or **actively drag** the product list upward to collapse. Bounce-back / fling after finger lift does not collapse. Expand/collapse uses a curved animation (~380ms). Own store shows a **+** in the app bar while collapsed (same picker flow as **Add products**); it fades out when details expand and the actions row appears. Import requests and gallery icons stay in the app bar. Other-store import remains on the expanded actions row only. The products row is `PRODUCTS · N` then a small vertical divider and **View all** (`AppColors.primary`) when the store has products; it opens `store_gallery_route` via the same `_openGallery` path as the app-bar gallery icon.

## Logic Ownership
- Store profile screens manage store profile presentation and interaction events.
- Use listeners for side effects and navigation (info + error snackbars).
- Keep import/listing/team/auth business logic out of widget build code.
- Own store: load members via `GET /stores/:storeId/members`. Expanded header always shows `N members · M products` (including `0 members`). Below that row, **Add member** → `add_team_route` with `returnToProfile: true`; on Done/Skip/back, pop to store profile and refresh members. Missing catalog names are filled from device contacts by phone (quiet, no loader).
- Other stores: do not call members API (owner-only); show products count only.
- Collections list returns cover only; after list load, fetch each multi-photo collection detail so grid/gallery/product details have full image URLs (collage uses enriched multi-photo lists).
- Own store: inbox icon (top-right) shows pending **incoming** import request count; opens `store_import_requests_route`. Count refreshes when returning.
- Store showcase images (1–5): loaded via `GET /stores/:id` into `coverImageUrl` /
  `storeImages`. Own-store logo camera opens `store_images_manager_sheet` — same
  carousel bottomsheet pattern as group photo preview (`ProductImageCarousel` +
  Camera/Gallery picker). Append via `POST .../images`, delete via
  `DELETE .../images/:imageId` (max 5).
- Product grid tap opens `collection_browse_route` (not product details directly), passing product + store meta. Browse may bubble `deleted` / `updated` the same way product details does — apply `StoreProfileProductUpdated` / `StoreProfileProductDeleted`.
- Photo-only deletes from details return `updated`; last-photo delete returns `deleted` after the collection is removed. A follow-up `StoreProfileProductDeleted` treats 404 / `COLLECTION_NOT_FOUND` as already gone.
- Whole-product delete also lives on the product grid of **your store**: visible rounded close button on each card. Confirm dialog, then `DELETE /stores/:storeId/collections/:listingId`. Not shown on other stores.
- Do not show add-product / team CTAs on other stores. Product details receive `isOwnStore` so own-store originals can edit even when list permissions omit `edit`. Grid close is gated by `canDelete`.
- Opening the gallery also passes `isOwnStore` so details opened from a photo keep the same edit gate.

## Collection browse
- `collection_browse_route` fetches `GET .../collections/:id` on land.
- Layout mirrors `store_gallery_route`: plain date header (`Sep 17`, no
  Today/Yesterday brackets), section titles (main = collection name, then each
  sub-group name), pinch-to-zoom column count (min 4). Keeps
  `AppColors.background` (not the dark gallery chrome). Top bar shows the store
  name (with Select / Edit / Ungroup when own store).
- Photo order: main group, then each sub-group (no nested browse cards).
  Section keys stay distinct when two sub-groups share a display name.
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
- Own-store **Add products** / app-bar **+** opens image picker then `add_product_group_route`
  (group title → title-only form **or** weight/purity/size flow). Edit metadata still goes
  through product details → edit sheet → `add_product_form_route` with `mode: edit`.
- Refine items opens preview in `isEditMode` (no Published screen).

## Folder Scope
- `store_profile_route.dart`: store profile route.
- `collection_browse_route.dart`: gallery-style collection photo browse (date /
  section titles / pinch zoom + Select) after tapping a collection.
- `storeprofile_widgets/`: profile-specific visual sections/components, including the collapsing header.
