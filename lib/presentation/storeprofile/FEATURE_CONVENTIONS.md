# Store Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/storeprofile/`.

## Mandatory Update Rule
- If store profile sections, product preview behavior, actions, import triggers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full route rendering.
- Use `AppPadding` for consistent spacing.
- Use `AppTextStyles` and `AppColors` for all display text and palette.
- Keep reusable controls shared; keep store-profile-only visuals inside local widget folder.
- Product grid shares one `CustomScrollView` with the profile header. As the user scrolls, the expanded header (logo, name, copy link, members) translates away and is clipped under the pinned bar. Add products / Import fade out completely (not a residual ghost) before the compact bar settles. Compact bar: store logo, store name, store link (no copy). Own store shows a **+** in the app bar for add-product (same picker flow as **Add products**). Import requests and gallery icons stay in the app bar. Other-store import remains on the expanded actions row only. The products row is `PRODUCTS · N` then a small vertical divider and **View all** (`AppColors.primary`) when the store has products; it opens `store_gallery_route` via the same `_openGallery` path as the app-bar gallery icon.

## Logic Ownership
- Store profile screens manage store profile presentation and interaction events.
- Use listeners for side effects and navigation (info + error snackbars).
- Keep import/listing/team/auth business logic out of widget build code.
- Own store: load members via `GET /stores/:storeId/members`. If no teammates (owner only), show **Add members** CTA → `add_team_route`.
- Other stores: do not call members API (owner-only); show products count only.
- Collections list returns cover only; after list load, fetch each multi-photo collection detail so grid/gallery/product details have full image URLs.
- Own store: inbox icon (top-right) shows pending **incoming** import request count; opens `store_import_requests_route`. Count refreshes when returning.
- Product details return values: apply `StoreProfileProductUpdated` / `StoreProfileProductDeleted` (or gallery snapshot via `StoreProfileProductsReplaced`). Photo-only deletes from details return `updated`; last-photo delete returns `deleted` after the collection is removed. A follow-up `StoreProfileProductDeleted` treats 404 / `COLLECTION_NOT_FOUND` as already gone.
- Whole-product delete also lives on the product grid of **your store**: visible rounded close button on each card. Confirm dialog, then `DELETE /stores/:storeId/collections/:listingId`. Not shown on other stores.
- Do not show add-product / team CTAs on other stores. Product details receive `isOwnStore` so own-store originals can edit even when list permissions omit `edit`. Grid close is gated by `canDelete`.
- Opening the gallery also passes `isOwnStore` so details opened from a photo keep the same edit gate.

## Route and Navigation Notes
- Keep route registration in centralized navigation files.
- Use shared Cupertino-style page transitions.
- Add members from profile uses `pushNamed(add_team_route)`; Continue/Skip from team still clears to listing.

## Folder Scope
- `store_profile_route.dart`: store profile route.
- `storeprofile_widgets/`: profile-specific visual sections/components, including the collapsing header.
