# Store profile optimisations (selected)

## 1. One-call collections (BE-2 FE)

Opening a store used to ask for the album list, then ask again for each album’s photos. Now one request returns every album and the first 9 photos of each.

That request uses an include flag and a per-album product limit of 9. Product rows (ids, image URLs, badges) come embedded on each album. The app builds grid cards from that embed and only falls back to a per-album product list when the embed is empty—so the old 1 + N open storm goes away when the backend supports it.

## 2. Quiet refresh TTL (45 seconds)

If you leave and come back within about 45 seconds, the app doesn’t call collections again for the same data—it reuses what it just fetched.

After a successful network enrich, a per-store timestamp is kept. A non-forced quiet refresh inside 45 seconds reads cache instead of hitting the network. Forced refresh (upload, delete, or an explicit force) ignores the window. That cuts duplicate collections traffic on quick reopen without freezing the grid forever.

## 3. Import-targets removed

Visitor opens used to ask “already in my store?” once per product. Those calls often failed (404) and wasted radio. Badges now use flags that already arrive with the album data.

The N× import-target probes on profile open were dropped. Added / Pending come from import flags on the collection/product payload. Probing remains for dedicated import-picker screens when those open. Expected 404 noise on store open goes away.

## 4. Background album expand

After the grid appears, albums bigger than 9 quietly load the rest of their photos so swipe / browse / channel usually already have them (same feel as the fast reference APK).

Any card with fewer loaded frames than the album total is enqueued for one product-list request (limit = album size, capped at 100). The queue waits ~80ms after first paint, then runs **waves of up to 4 albums in parallel**, with a short gap between waves. The same album won’t expand twice. Swiping past the first page still triggers that album immediately if background work isn’t done—still one request per album, not per swipe.

Visitor collection browse **skips** the quiet `products?collectionId=` refetch when the card is already fully expanded (`!needsAlbumExpand`). Own-store browse still quiet-refreshes for manage chrome.

While a later swipe page is still waiting on that expand, the collage shows a **blurred preview grid** (reusing first-page photos) instead of a circular loader—same expand/navigation behavior, friendlier placeholder.

## 5. Swipe UX fix

When the rest of the photos arrive, the collage no longer flashes loading and jumps back to the first page. You stay where you were.

The collage shell stays stable when paths grow from 9 to N, so the pager isn’t torn down and rebuilt. Page index resets only when the listing changes, not when more frames are appended. Updates keep the current page instead of forcing the first page.

## 6. Quiet refresh won’t shrink albums

After an album was fully loaded to 20 photos, a soft refresh must not throw away frames and leave only 9 again.

When quiet refresh returns a preview payload (limited to 9 products), the app merges with what’s already on screen: if that listing already has more frames, those stay; likes, locks, title, and counts update from the network. The merged list is what gets cached, so disk doesn’t reintroduce the shrink.

## 7. Product details skip GET after browse

Group browse already loads every product in the album. Opening details and swiping used to call `GET /products/:id` again for each piece.

Browse now passes that list row on each feed item (`seedCatalog`). Details hydrates specs, like, wishlist, and like/view count chips from a **rich** seed (or a same-session cache after one GET) and skips the per-swipe product GET. Thin stubs / incomplete multi-image seeds still GET. Gallery / Single / search without a seed still fetch as before.

Like / wishlist toggles write session overrides (`WishlistPrefetcher` / `ViewerProductFlags`) so a stale browse seed (`liked`/`wishlisted: false`) cannot wipe chrome when you reopen the same product. Removing from the Wishlist tab clears that override (and the warm page row) so details does not keep showing wishlisted. Seed hydrate also keeps imported `canEdit` rules and list `isLocked` → lock chrome.

## 8b. Browse / details / decode Medium slice

- Collection browse: `products?collectionId=` first; `fetchCollection` only when own-store or empty (no parallel).
- Channel Media/Gallery + store gallery feed + search attach `seedCatalog` so product-details can skip `GET /products/:id`.
- Product-details root `BlocBuilder` uses `buildWhen` on painted fields.
- Media/Gallery/browse tiles decode at **cell** width (`cacheWidthForMediaColumns`); role still picks URL tier.

## 8a. Channel / Gallery pinch smoothness

Media pinch no longer `setState`s the whole channel (TabBarView). Columns live in `ValueNotifier`s; only the Media grid rebuilds. Gallery mosaics use real `SliverGrid`s (no nested shrinkWrap). Paint URL tier stays locked while pinching; image warm runs when the pinch settles. Channel collapsed glass bar is translucent fill only (no `BackdropFilter`).

## 8. Faster tap → first grid paint

Opening a store felt multi-second even though `pushNamed` was immediate, because the visitor grid stayed blank until `GET /stores/:id` finished, then waited on collage decode inside the shared prefetcher.

- Seed `canViewContent` when listing follow is already `following` / `self` / `member` (same rule as `CatalogStore.resolvedCanViewContent`). Pending / none still wait for meta — never guess public.
- After **disk** meta unlocks, kick `LoadCollections` immediately (do not wait for the network meta refresh). Open-path kicks are coalesced so memory / disk / network do not triple-load.
- Prefetcher `ensure` / enrich **writes cache and returns** before awaiting collage `precacheUrls(decode: true)`; decode keeps warming in the background.
- Store tap **pushes immediately** (no await). Catalog loads + collage decode are **deferred ~320ms** so the push animation is not fighting JSON/image work. Prefetch enrich is delayed the same way; disk memory prime stays immediate.
- `GET /stores/:id` soft-open is **deduped**: in-flight coalesce + 45s quiet TTL across bloc remounts; follow/privacy/explicit refresh use `force: true`.
- Own-store open: profile-switch prefetch is **disk/memory only** (`networkEnrich: false`) so Ensure owns the single collections GET; quiet collections refresh is skipped while prefetcher TTL is fresh; members use shared in-flight + 45s memory TTL across shell remounts.
- **Empty store:** `ensure` returning `[]` must not fall through to a second `refresh(force: true)` — empty cache reads as miss, which previously doubled `collections?include=products`.
- Home listing seeds `canViewContent` from `resolvedCanViewContent` so public/followed grids unlock without waiting GET store.
- Profile emit paints cache **before** image warm (ThumbHash/blur OK); warm runs in background.
- **First-open jank (Plan A):** collage decode warm waits ~360ms after emit (push-friendly). First ~4 albums (≈2 Group rows) decode first; the rest follow ~220ms later. Prefetcher matches that split (no full-grid decode on ensure). Store-profile `cacheExtent` is **480** so fewer off-screen collages build on open. Does not change APIs, TTL, expand, or selection.
- **Chrome state (Plan B):** Discover selection / busy / paint rebind → `StoreProfileChromeCubit`. Channel visitor selection / busy / logo page → `StoreChannelChromeCubit`. Stores home activity unread → `StoreListingBloc` (`activityUnread`). Scroll reveal stays a `ValueNotifier` (safe with build-time restore). No whole-route `setState` on those screens for chrome.
- **Open + scroll jank (UI-2):** Discover header / jump FAB / Follow dock are **fill-only glass** (no `BackdropFilter` over collages). Resume hold uses `Visibility(maintainSize)` instead of full-tree `Opacity`. Scroll resume persist is throttled (~80px). Album expand starts ~420ms after paint, waves of 2 with ~120ms gaps (less fight with fling).
- Empty / meta-loading grid shows **shimmer**, never a blank hole.
- Listing idle warms covers + soft-enriches last-opened / first visible stores (cap 2).
- Album expand starts ~420ms after paint (waves of 2) so open/scroll stay smooth; channel/browse still fill soon after.
- Browse seeds from collection cards with ≥1 displayable path (not only 2+).
- No full home refresh on every store pop (was stalling Stores + stealing radio).
