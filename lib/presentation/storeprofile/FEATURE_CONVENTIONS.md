# Store Profile Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/storeprofile/`.

## Mandatory Update Rule
- If store profile sections, product preview behavior, actions, import triggers, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for full route rendering.
- Use `AppPadding` for consistent spacing.
- Use `AppTextStyles` and `AppColors` for all display text and palette.
- Keep reusable controls shared; keep store-profile-only visuals inside local widget folder.
- Product grid shares one `CustomScrollView` under a **Telegram floating
  capsule** header (`StoreProfileTelegramHeader`): three frosted pills
  (back circle · DP + name + followers · add/import + search) — not a
  full-width bar. Glassy pills: `BackdropFilter` blur + translucent
  `surface` / `appBar` fill + soft `border`. Day uses `textPrimary` /
  `textSecondary`; Night uses `textOnPrimary`. Tap the identity pill to
  push `store_channel_route` —
  do **not** expand the header in place.
- **Edge-to-edge image lists** (Discover, channel Media/Group/Gallery, store
  gallery, collection browse): no decorative top/bottom list padding — tiles
  flush to the viewport; scroll under status bar + home indicator
  (`extendBodyBehindBottom`). Soft cool top/bottom washes via shared
  `CatalogImageEdgeFades` (under floating chrome). Keep scroll insets only
  for overlay chrome (header extent, docks).
  Store logos are always circular; missing images use name initials (no
  diamond/icon default).   Product cards show Telegram-style **like** + **view** + private
  **wishlist** chips top-left of the collage when counts are positive —
  thumbs-up + eye + heart (`_LikeViewCountBadges`). Like/view prefer
  `max(collection, sum of embedded products)` so a stale collection
  `likeCount: 0` still shows product likes after `products?collectionId=`
  enrich or collection detail. **Wishlist chip** is viewer-private: count of
  embedded products with `wishlisted: true` (API has no public
  `wishlistCount`). Popping product details after like/wishlist (or when
  aggregated counts are already > 0) silently updates the grid card via
  `StoreProfileProductUpdated(silent: true)`. Multi-select wishlist bumps
  `wishlistCount` via `VisitorWishlistBatch.applyWishlistCounts`. Do **not**
  show lock / stock chips on product cards outside selection — those live on
  product details only. After visitor **long-press** photo selection, each
  cell shows per-photo lock / out-of-stock (and In Your Store / Exclusive)
  marks; clearing selection hides them again. Destination **Pending** tags
  stay visible without selection. Grid is **collections-first**
  (`GET …/collections`); collage / browse use `GET …/products?collectionId=`.
  Public like vs private wishlist are separate on product details
  (thumbs-up vs heart).
- `store_channel_route`: opened from Discover header via
  `StoreChannelRevealRoute` (fade + soft rise from top — not a sideways
  Cupertino push). **Back** (icon / edge swipe) pops with **no** reverse
  transition (`reverseTransitionDuration: zero`). Collapsing hero:
  **expanded** = full-bleed store logos
  with no glass / edge-wash overlay (avoids a horizontal seam on the photo);
  **collapsed** = compact title+logo on a frosted pinned bar (`BackdropFilter`
  + translucent fill, no hard bottom border). Scroll down → full-width
  swipeable **store** logos only — never product photos; missing logo →
  name initials. Count buttons: **Products** / **Followers** / **Following**
  only (no Mute/Report/Share row). Owner: followers/following open on tap;
  visitor counts display-only. Store link card: **copy** + **share**
  (WhatsApp via `WhatsAppInvite.shareText`) side by side. Visitor: Follow
  chrome under counts (not on Discover listing). Tabs: **Media** (pinch
  zoom 2–9 columns, smooth continuous resize + snap) / **Group** /
  **Gallery**. Edge-swipe back via `EdgeBackSwipe`.
- Discover scroll: jump-to-bottom FAB uses a `ValueNotifier` (no mid-fling
  `setState` / sliver padding toggle). `BlocBuilder.buildWhen` skips
  unrelated state noise so the product grid stays smooth.
- Toolbar (Telegram flat icons — not phone/menu, not blue chips): **search**
  when content is viewable (opens `store_search_route`; hidden when
  `isContentLocked`). Primary action beside it: own store → **+** (add
  products); other store when `canImport` → **download** import icon. No
  gallery or import-requests icons in the app bar. Private visitor shows a
  small lock beside the follower subtitle.
- Other-store **Import** uses the toolbar download when `canImport` (older
  select route). Long-press a photo (store account) starts selection: check
  circles plus lock / stock / **In Your Store** / **Exclusive** marks.
  `LOCKED_TIER_MAX` tiles cannot be selected (toast). Bottom dock:
  **Import N** + Wishlist; when any locked are selected, an orange strip above
  the buttons shows `N instant · M need approval` (CTA stays short — no overflow).
  Accounts without a store get Wishlist only. Import → compose →
  `POST …/stores/:id/imports`. Close (x) or clearing the last photo ends
  selection. A normal tap still opens the product.
- Own store: products with `isSourceDeleted` show a blurred **Source Deleted**
  ghost + **Remove from Shelf** (`StoreProfileProductsDeleted`). Visitors
  never see those tiles.

## Logic Ownership
- Store profile screens manage store profile presentation and interaction events.
- Use listeners for side effects and navigation (info + error snackbars).
- Keep import/listing/team/auth business logic out of widget build code.
- Own store: load members via `GET /stores/:storeId/members`. Expanded header always shows `N members · M products` (including `0 members`). Below that row, **Add member** → `add_team_route` with `returnToProfile: true`; on Done/Skip/back, pop to store profile and refresh members. Missing catalog names are filled from device contacts by phone via shared `DeviceContactNames` (E.164 / normalizedNumber / last-10; quiet, no loader).
- Other stores: do not call members API (owner-only). Discover shows a glassy
  bottom **Follow** / **Requested** dock when `followStatus` is `none` /
  `pending` (same bloc events as channel). Full Following + notify chrome
  stays on `store_channel_route`. When `canViewContent` is false (private +
  not approved), replace the product grid with the locked gate (“This store
  is private”); hide search / import. Compact title shows a lock icon for
  private stores. Visitor follower lists on the channel screen are **not**
  tappable into list routes.
- **Upload notify bell** (while Following): toggles `notifyUploads` via
  `PATCH /stores/:id/follow` (`StoreProfileToggleNotifyUploads`). Optimistic
  UI; reverts on API failure. Muted followers skip upload push + in-app upload
  feed entries (backend). On new active follow (or pending→following), client
  also `PATCH notifyUploads: true` so the ON bell matches the server — otherwise
  `new_upload` never fires.
- **Own store:** expanded header also shows Products / Followers / Following
  counts + privacy pill. Followers / Following taps open
  `followers_following_route` (owner-only lists). After pop, refresh store meta.
- Follow POST/DELETE returns a slim `{status}` payload — never parse it as
  `CatalogStore` (that incorrectly unlocked private grids). Map
  `active→following`, `pending→Requested` and keep the gate closed until
  `canViewContent` is true.
- Store profile shows **Discover** listing for both owner and visitor (no
  owner floating bottom nav on this route). Wishlist / My store live on the
  main shell; Activity opens from Stores home notification → `activity_route`.
  - Telegram header + products (grid scrolls under translucent bar); tap
    identity → `store_channel_route` (not global search).
  - Own store may show `FollowRequestsBanner` when private + pending > 0;
    tap opens `follow_requests_route` (Confirm / Delete).
  - Shell My store reuses `StoreMyStoreTab` (hamburger → Settings, no back /
    no day-night toggle; **Import requests** + Share CTAs) with
    `AppPadding.screen` chrome.
- Products + collage images are **cache-first**:
  API responses are written to `StoreProductsCache`, then the UI paints
  only from that cache. Soft-prefetch warms the first listing stores and
  store tap; profile joins that warm so landing paints full collages with
  images already on disk (no shimmer when warm/cached). Cold path (empty
  cache, no prefetch) still shows shimmer once. After publish / update /
  delete / import, the mutation result is committed to cache immediately,
  then a quiet GET refresh rewrites the cache again.
- **Create upload UX:** on Publish/Done, upload runs in
  `ProductUploadCoordinator` while the user returns via
  `leaveCreateProductFlow` to Discover `store_profile_route` immediately
  (pushes own-store profile if that route is not on the stack — do not leave
  the user on shell home alone). Existing products stay painted; only the
  in-flight listing shows a shimmer slot at the **top** of the product grid
  (before existing tiles), matching **Group** / **Single** / **Gallery** view.
  The server listing created mid-upload is **hidden** from the grid (and
  skipped by prefetch / quiet refresh) until all photo batches finish — avoids
  partial tiles beside the shimmer. Success → replace shimmer with the product
  at index 0 (no “Product published” snack). Partial photo failures may still
  snack.
  Quiet refresh / listCollections stay **newest-first** so the new tile does
  not jump after upload. Pending uploads live on the coordinator singleton,
  so leave/return still shows the correct shimmer until the upload finishes.
- Network media uses `CachedNetworkImageProvider` with a **file-based**
  `CacheManager` (`JsonCacheInfoRepository` — no sqflite) + `gaplessPlayback`
  so disk cache works without MissingPluginException and rebuilds do not flicker.
- Other store (when viewer has own store): feed enrichment prefers
  `isAlreadyImported` / `canImport` / `importRestrictionReason` on each
  product. Legacy quiet `GET /import-targets` probe may still mark **Added** /
  **Pending** when flags are absent. Product cards show **title only**.
  Refresh after returning from import flow.
- Destination shelf: products with `importStatus: pending` (awaiting source
  owner approval) show an orange **Pending** tag — card chip for singles /
  all-pending groups; per-photo pill on Group collage / Gallery / channel
  Media / collection browse cells. Driven by `ProductImportFlags.isImportPending`
  and parallel `StoreProduct.imageImportStatuses` from collection product
  hydrate. Always probe `products?collectionId` — list `productCount` is
  often live-only (0/1) while pending copies still return in /products.
- Own store: import-requests inbox lives under **Settings** from shell My store
  (`settings_route`; also still on no-store Profile when applicable). Store
  profile no longer shows the inbox badge icon.
- Store header meta is **cache-first** via `StoreMetaCache` (name, link,
  cover, showcase images). Listing seeds cover URLs into that cache so the
  logo does not flash-load; `GET /stores/:id` and image append/delete write
  the cache again, then UI reads from cache.
- Product layout follows Settings → **View products** (`ProductViewPreferences`
  / `AppSettingsStorage`, survives logout): **Group** (2-col cards, default),
  **Single** (Telegram channel feed: centered date pills **Today** /
  **Yesterday** / **October 10** from product upload day; full-width cards;
  no per-card clock time), **Gallery** (light-theme photo mosaic by day,
  same sectioning as `store_gallery_route`).
  Upload day comes from collection `createdAt` (IST `+05:30` or UTC ISO)
  when present; else cover/photo `createdAt`; else Mongo ObjectId time in
  `id`. Single / Gallery / browse share `formatCatalogDayBucket` (Today /
  Yesterday / month day). Group uses the same `StoreProduct.createdAt` for
  ordering consistency when switching view modes.
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
  scroll. Each tile gets a subtle corner radius (`tileBorderRadius` ~3px group /
  ~3.5px single) on all four corners; ~1.5px gap between tiles.
  Product card outer radius unchanged; cards use a soft outline — Day
  `divider` / Night `border` at low alpha (~1px) so edges stay quiet, with
  thicker primary border when selected/focused.
  Product cards show a dark glass image-count chip immediately beside the
  title for any displayable album size (including 1). For **10+** albums the
  card shows carousel page dots above the title — exactly one dot per
  horizontal page (9 images/page; e.g. 4 pages → 4 dots), with the active
  page elongated/highlighted via `onAlbumPageChanged`. Count chip uses
  `AppTextStyles.caption` / `textOnPrimary`, same chrome as view / import
  chips — glued beside the title. No `{page}/{pageCount}` text counter.
  Gallery mosaic separate. Cell taps still report absolute `imagePaths` indexes.
- **InstantCatalogPhoto + R2 responsive URLs (frontend guide):**
  bind by screen role via `CatalogResponsiveImage` /
  `StoreProduct.urlForRole` — **Gallery / dense Media → `thumbnailUrl`**,
  **Media zoom-in → `detailUrl`**, **pinch-zoom / product-details → master
  `url`**. **Group/Single collage (per cell, all 3 tiers):** 1 → master;
  2 → `detailUrl`; 3–4 → left hero master, stacked `thumbnailUrl`; 5–9 →
  2-column rows `detailUrl`, 3-column rows thumb; 10+ (3×3 pages) → all
  thumb. Tap still opens master. Prefer BE variants on
  `media.catly.in` (thumb ~240 @ q40 / detail ~720 @ q70 / master). FE CDN
  synth is **disabled** — missing BE fields fall back to master and log a GAP
  (restore commented `synthesize` in `catalog_responsive_image.dart` if needed).
  ThumbHash is an instant **placeholder** (RGBA blur via
  `ThumbhashBlurPlaceholder`) until the CDN frame arrives. Channel Media
  locks `decodeCacheWidth: gridCacheWidth` and decode-warms a densest-grid
  viewport (profile push + route land; re-warm when pinch densifies). Channel
  / browse photo taps still `precacheUrls(decode: true, fullCacheWidth)` on
  the **master** for product-details pinch. API `quality: low` still gates
  deep zoom on product details.
- **Temp media debug logs:** filter console / Logcat by `CatalogMediaDBG`
  (`lib/helper/catalog_media_debug.dart`) — phases `STEP` / `UPLOAD` /
  `RENDER` / `WARM` / `API` / `GAP` (STEP covers sign → R2 PUT → batch →
  render URL role). Plain-English upload walkthrough: filter
  `CatalogUploadStory` / `JewelUploadQA` — numbered steps + Why/Frontend +
  API request/response. Remove both after gap audit.
- Product grid tap depends on product view mode:
  - **Group**: opens `collection_browse_route` (gallery-style selection), passing
    product + store meta. Collage cell taps use the same destination (any tile
    opens browse for that listing). Browse may bubble `deleted` / `updated` the
    same way product details does — apply `StoreProfileProductUpdated` /
    `StoreProfileProductDeleted`. Tap a photo in browse → `product_details_route`
    with that photo’s `imageIndex`.
  - **Single** / **Gallery**: opens `product_details_route` with Telegram-style
    photo transition (`TelegramPhotoPageRoute`: flyer from cell `sourceRect`
    to centered contain frame, dimmed grid behind, then details fade-in).
    Pass `imageIndex`, `photoSourceRect` / `photoPath` / optional
    `photoThumbhash`, + flat `galleryFeed`. Swipe-down pops; close shrinks
    back into the cell. Same `deleted` / `updated` pop handling as browse.
- Optional route arg `focusProductId` (legacy / deep-link highlight; product
  details no longer offers a store-name chevron)
  scrolls to that listing and draws a primary (blue) border around its group
  card. Tap still follows the view-mode rules above.
- Photo-only deletes from details return `updated`; last-photo delete returns `deleted` after the collection is removed. A follow-up `StoreProfileProductDeleted` treats 404 / `COLLECTION_NOT_FOUND` as already gone.
- Whole-product delete on **your store** uses long-press → multi-select → Delete (not a stacked close icon). Confirm dialog, then `DELETE /stores/:storeId/collections/:listingId` (batch via `StoreProfileProductsDeleted`). Not shown on other stores.
- **Other-store visitor photo multi-select (Telegram-style):** long-press a
  collage / gallery / channel Media photo to enter photo selection
  (`productId|imageIndex` keys, check badges). Works in Discover **Group /
  Single / Gallery** view modes and on `store_channel_route` **Media /
  Group / Gallery** tabs. Further taps toggle photos across listings.
  - Header switches to selection chrome: **close (X)** instead of back; DP +
    name + subtitle (`followers · N selected`) stay in the identity capsule
    with a WhatsApp-style **forward** icon on the right of that same capsule
    (same handler as bottom Import). No Cancel button. Add/search hide while
    selecting. Close, system back, or edge-swipe clears selection (does not
    leave the store).
  - Bottom shows **two separate** glass buttons — **Import** and **Wishlist**
    (not one segmented dock; Follow dock hidden while selecting). **Wishlist**
    bookmarks selected photos via `VisitorWishlistBatch` →
    `POST /wishlist/batch` `{ productIds }` (fallback: parallel
    `POST /wishlist/products/:id` if batch 404). Each key resolves to the
    **embedded CatalogProduct id** for that collage cell
    (`photoAssetIds[imageIndex]`), not a single collapsed listing id (so
    multi-select in one collage creates multiple wishlist rows). No
    optimistic counts / success snackbar; busy shows a spinner on Wishlist.
    **Import** still unwired.
  - Own-store long-press product selection / Delete is unchanged.
- Do not show add-product / team CTAs on other stores. Product details receive `isOwnStore` so own-store originals can edit even when list permissions omit `edit`. Selection delete is gated by `isOwnStore`.
- Import is gated by `viewerHasOwnStore` (session `ownStoreId`): hide Import CTAs and refuse `_openImport` / import probe until the user has created a store (Profile tab **Create store** → `store_setup_route` → team → store listing).
- Opening the gallery also passes `isOwnStore` so details opened from a photo keep the same edit gate.
- **Add products** / app-bar **+** opens one Telegram-style
  `ProductGalleryPicker` **bottomsheet** (`includeCamera: true`,
  `confirmAsSend: true`; lightweight `PopupRoute` with barrier / slide-up /
  rounded sheet / drag handle / tap-outside dismiss; progressive thumbs;
  deferred camera; live preview stays on while scrolling; `pausePreview` /
  `resumePreview` when the camera cell leaves the viewport; cached
  `AssetEntityImageProvider` + `RepaintBoundary` tiles; clamping scroll on
  Android / bouncing on iOS) — no Camera/Gallery chooser. Confirm is a green
  WhatsApp **send** icon with selection count (not Done text). Photo
  permission is requested **before** the sheet; deny → snackbar + Settings, no
  sheet. Live **Camera** preview (2 cols × 3 rows, `camera` package) on the
  left with a 2×3 photo block beside it, then the rest of the library below
  (album dropdown; multi-select via `drag_select_grid_view`: tap + hold/slide;
  numbered badges; max 50). One grid for all photos — camera is a 2×3 overlay
  on spacer cells so slide-select continues from the side band into row 4+.
  Camera cell shows a live preview; tap closes the sheet (preview released),
  then an in-app full-screen camera (`camera` package — not `image_picker`,
  which races CameraX on MIUI) → photo. After pick →
  `add_product_compose_route` (WhatsApp compose: edit crop/mark/text, title
  note, send) → `add_product_group_route`.

## Collection browse
- `collection_browse_route` on land: prefer **seeded tiles** from the Group
  collage card (`StoreProduct` parallel paths / product ids written during
  profile enrich via `products?collectionId=` limit 100) so Group → browse
  paints immediately. Quiet background refresh: always
  `GET …/products?collectionId=`; `GET .../collections/:id` only for
  **own-store** manage (Select / Edit / Ungroup) or when there is no seed /
  products page is empty (legacy fallback). Products + detail run in
  **parallel** when both are needed. Quiet refresh **keeps seed / collage
  (cover-first) tile order** when merging API products so images do not
  rearrange on land. When products are present, tiles are one-per-product;
  otherwise legacy collection photo / sub-group layout.
- Layout mirrors `store_gallery_route`: plain date header (`Sep 17`, no
  Today/Yesterday brackets), section titles (main = collection name; custom
  sub-group names only — auto `{title} precise|standalone {n}` stay under the
  collection title), pinch-to-zoom column count (min 4). Keeps
  `AppColors.background` (not the dark gallery chrome). Top bar shows the store
  name (with Select / Edit / Ungroup when own store).
- Photo order (legacy): main group, then each sub-group (no nested browse cards).
  Section keys stay distinct when two custom-named sub-groups share a display
  name. Auto publish names (`{title} precise {n}` / `{title} standalone {n}`)
  merge under the collection title — no separate section header (Precise still
  uses the blue dot). Only **custom** sub-group names get their own section title.
- Photos in a Precise sub-group get a small **blue dot** on the right (not a
  “Precise” text chip); Standalone stays unmarked.
- Tap any tile → `product_details_route`. Jewel-flow product tiles open with
  that product’s id (`GET /products/:id`) and a per-product `galleryFeed`.
  Legacy photo tiles keep a flat collection `galleryFeed` + `imageIndex`.
  Returning from details: `silent` count pops are no-op on browse (no loader);
  real edits refresh with `_load(quiet: true)` so tiles stay visible.
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
- Own-store **Add products** / blue app-bar **+** opens
  `ProductGalleryPicker(includeCamera: true)` then `add_product_group_route`
  (title / tags / description → publish title-only **or** expand more details
  for weight/purity/size → preview). Edit metadata still goes through product
  details → edit sheet → `add_product_form_route` with `mode: edit`.
- Refine items opens preview in `isEditMode` (no Published screen).
- App-bar **search** icon → `store_search_route` with `storeId`, `storeName`,
  `productCount`.

## Scroll (Telegram model)
- Product `CustomScrollView` uses bouncing physics + elevated `cacheExtent`
  for smoother flings.
- Floating down-arrow (glassy, header-matched) sits mid-low on the right;
  when the Follow dock is visible it stacks above it with a gap. Tap animates
  to the end of the list.
- Scroll offset is remembered per store + view mode in
  `StoreProfileScrollCache` (memory). Leaving and reopening the same store
  resumes where left (including bottom). Persist on back/`deactivate`/`dispose`
  using the best of lastKnown / resume / controller (never write `0` — pop
  teardown often reports `pixels=0`).   Restore jumps to `min(saved, maxScrollExtent)` promptly (interim pin to
  current bottom while extent may still grow; finalize when extent is stable
  even if shorter than when left). While resume is in progress the product
  list stays at opacity 0 so open does not flash the top then scroll. Reveal
  after the jump lands. Skipped when `focusProductId` is set. Debug: filter
  console / Logcat for `StoreScrollCache`.

## Folder Scope
- `store_profile_route.dart`: store profile route.
- `collection_browse_route.dart`: gallery-style collection photo browse (date /
  section titles / pinch zoom + Select) after tapping a collection.
- `storeprofile_widgets/`: profile-specific visual sections/components, including
  the collapsing header, product grid, and embedded gallery sliver.
