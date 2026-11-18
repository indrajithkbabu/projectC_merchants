# Catly / project_c — App Optimisation Backlog

Findings are grouped by area, then ranked **High / Medium / Low** inside each area. Static review of the Flutter codebase plus `docs/BE gaps`. Nothing was profiled on a device — confirm with DevTools in `--profile` before large refactors.

**Sources:** codebase review; API / UI / state audits (Nov 2026); Project C Merchants Optimisation Plan (cross-checked and merged).

**IDs:** Merchants plan IDs (`API-1`, `ST-1`, `SM-2`, `BE-1`, …) are noted in parentheses where they map.

---

## Summary counts (merged)

| Area | High | Medium | Low |
|------|------|--------|-----|
| API optimisation | 10 | 12 | 5 |
| Backend payload / APIs | 4 | 6 | 3 |
| Caching & request dedupe | 3 | 5 | 2 |
| UI and rendering | 6 | 12 | 4 |
| State management | 6 | 8 | 4 |
| Image / media pipeline | 4 | 6 | 3 |
| Prefetch strategy | 3 | 4 | 1 |
| Startup, memory & storage | 3 | 3 | 2 |
| Search & lists | 2 | 3 | 1 |
| Networking client hardening | 2 | 3 | 1 |
| Code health | 0 | 0 | 4 |

---

## Suggested order of work

| Step | Slice | Why first |
|------|--------|-----------|
| 1 | **Quick wins (~1 day):** API-1 (decode/log), ST-1 (`bloc_concurrency`), SM-2 (image cache size) | Hours-scale; every screen / correctness / OOM |
| 2 | **Biggest perceived speed:** API-2 path (N+1 + shared enrich + quiet TTL), SM-1 (Stores paint before contacts), API-3 (GET coalesce), API-4 + BE-1 (batch delete) | Largest request + TTFP wins |
| 3 | Tab refresh TTL + import-targets probe removal | Everyday battery / radio |
| 4 | State — reuse shell `StoreProfileBloc` + My Store `buildWhen` | Duplicate work + jank |
| 5 | **Scroll smoothness:** ST-2/ST-3, UI pinch / shrinkWrap / blur / existsSync | Jank |
| 6 | Image — cell decode width + emit-before-warm | Open-store feel |
| 7 | Network + startup hardening: API-5…7, SM-3, SM-4 | Resilience |
| 8 | BE-2 / BE-3 / BE-5 (one-call collections, blockers, ETag/lite) | Removes FE workarounds |
| 9 | Prefetch priority queue | Cold start |
| 10 | Low items + code health | As time allows |

**Preserve (do not undo)**

- Home-first cold start + `StoreHomeCache`
- Cache-first store products/meta + `_sameGridVisual` skip emit
- Prefetcher `_inFlight` maps (`StoreHome` / `StoreProducts` / `Wishlist` — Wishlist already dedupes; see API-8)
- Discover / channel `buildWhen` where already applied
- Jump FAB via `ValueNotifier` (not scroll `setState`)
- Token refresh single-flight
- Wishlist/cart batch APIs where BE supports them
- View beacon batching (~4s)
- Search suggest debounce (200ms)
- DI singletons for API + session
- Cart mirror pattern (`CartStore` + repository)

---

## 1. API Optimisation

Duplicate and N+1 calls, dual enrich paths, and a client that decodes/logs too much are the main API costs.

### High

1. ~~**Every response is JSON-decoded twice; log sanitize runs even in release** `(API-1)`~~ **DONE**  
   **Done in:** `lib/webservice/catalog_api_client.dart`

   **What we did (simple):**
   - In release builds, we no longer clean or prepare API data only so it can be printed in the console (those logs are off anyway).
   - Each successful or error response is turned from text into usable data **once**. In debug, the console log reuses that same data instead of parsing again.
   - **Large** API replies (about 32 KB or bigger — big store lists, search, wishlist, etc.) are parsed on a **background worker** so the screen stays smoother as the app grows. Small replies still parse on the main thread (faster for tiny messages).
   - Login, token refresh, headers, photo uploads, and normal API behaviour are unchanged.

   **What we did (technical):**
   - Request sanitize (`_sanitizeForLog`) and response log prep run only inside `kDebugMode` (`_logOutgoingJsonRequest` / `_logOutgoingMultipartRequest`).
   - Success/error bodies use a single decode path; debug logs reuse that map via `_logDecodedResponse`.
   - `_decodeJsonBody`: `jsonDecode` on UI isolate when `body.length < 32 KiB`; otherwise `compute(jsonDecode, body)`. `_decodeOrThrow` is async and awaits it.
   - Auth, refresh retry, headers, multipart, and API behaviour unchanged. Small error/401 bodies stay sync on the UI isolate.

2. ~~**Store grid loaded by two code paths, each 1 + N** `(API-2)`~~ **DONE** (+ **BE-2 FE consumer**)  
   **Done in:** `lib/services/store_products_prefetcher.dart`, `lib/bloc/storeprofile/store_profile_bloc.dart`, `lib/bloc/storeprofile/store_profile_event.dart`, `lib/session/catalog_session.dart`, `lib/models/catalog/collection_models.dart`, `lib/webservice/collection/collection_request.dart`

   **What we did (simple):**
   - One shared enrich loader for tap prefetch, cold load, and quiet refresh.
   - After a warm paint, quiet refresh is skipped for 45s if we just networked.
   - Listing soft-prefetch warms covers + soft-enriches last-opened / first visible (cap 2).
   - Post-paint album expand: parallel waves of 4× `products?collectionId=&limit≤100` (fast-APK fan-out); visitor browse skips refetch when album already complete.
   - Collage enrich capped at **9** products per listing (was 100).
   - **BE-2:** enrich calls `collections?include=products&productsLimit=9` and builds cards from embedded `products[]` (skips N× product list when present).

   **What we did (technical):**
   - Prefetcher: `listCollections(include: products, productsLimit: 9)` → map `summary.products` via `collectionCardFromProducts` → legacy `listStoreProducts?collectionId=&limit=9` / `fetchCollection` only when embed empty + `photoCount > 0`.
   - `CollectionSummary.products` parsed from JSON `products` only (not page `items`).
   - Removed bloc `_fetchEnrichedProducts` / `_productFromSummary`; quiet refresh calls `StoreProductsPrefetcher.refresh(force:)`.
   - `StoreProfileQuietRefreshCollections(force: false)` after disk/warm paint; mutations keep default `force: true`.
   - `_inFlight` coalesce + `_lastNetworkAt` TTL; `invalidateAll` on session clear.

   **How to test:**
   1. Cold open a store from listing (empty products cache) → one enrich; log `Enriched store=… embedded=N legacy=0 limit=9` (no mass `products?collectionId=`).
   2. Re-open same store within 45s → quiet refresh logs `Skip quiet refresh … (TTL 45s)`.
   3. Listing home paint → no mass `products?collectionId=` for visible stores (covers only).
   4. Upload/delete product → quiet refresh still updates grid (`force: true`).
   5. Group / Single / Gallery still open browse / details as before.

3. **No client-level coalescing of identical GETs** `(API-3)`  
   Hand-rolled `_inFlight` only in home/products prefetchers + token refresh.  
   **Partial:** `collection_browse_route` no longer parallel `listStoreProducts` + `fetchCollection` (products first; detail only when own-store / empty). Global client coalesce still open.  
   **Fix:** Key GETs by method + path + query + profile header; share one in-flight `Future`. Short TTL (2–5s) for `/me`, `/stores/:id`, collection detail; invalidate on mutation. Optional repository LRU for collection detail.

4. **Bulk deletes: one request + emit + cache write per item** `(API-4)`  
   **Where:** `store_profile_bloc.dart` (~1680–1870) — `deleteCollection` / `deleteProduct` in loops.  
   Deleting 20 items → 20 sequential round trips, 20 emits, 20 `_commitProducts` disk writes.  
   **Fix:** Batch delete endpoints (BE-1); emit/commit once. Until then: bounded parallelism (3–4) + single commit.

5. ~~**Remove legacy `/import-targets` fan-out**~~ **DONE**  
   **Done in:** `lib/bloc/storeprofile/store_profile_bloc.dart`, `lib/presentation/storeprofile/FEATURE_CONVENTIONS.md`

   **What we did:** Dropped N× `GET /import-targets` on visitor open. **Added** / **Pending** badges derive from list/product import flags (`isAlreadyImported` / `isImportPending`). Probe event kept as a no-network flag sync. Quick Import select flow unchanged (still probes when that screen opens).

6. **Stop refresh-on-every-tab**  
   Stores → always `GET /home`. Profile → `GET /me` + `GET /me/profiles`. Wishlist → force refetch (`refreshSignal`, including same-tab re-tap).  
   **Fix:** Soft refresh TTL (30–60s); force only pull-to-refresh / dirty flag.

7. **Auth / shell cold-start cascade**  
   Parallel: `/home`, `/me`, `/me/profiles`, `/wishlist`, full `/me/cart`, activity unread, then store meta/collections/members.  
   **Fix:** Ordered bootstrap; skip `/me/profiles` when `/me` bootstrap present; cart **count-only** at start; defer wishlist/activity/store until first need or idle.

8. **Profile switch refetch storm**  
   `StoreHomeCache.clearAll()` + home/wishlist/products prefetch + shell `ValueKey` remount → full store load.  
   **Fix:** Profile-scoped invalidation; reuse warm/in-flight; don’t double-prefetch what remount loads.

### Medium

9. **Networking policy is thin** `(API-5)` — 30s default timeout; no GET retry/backoff on network/5xx; no request cancellation; no ETag.  
   **Fix:** 8–10s reads; up to 2 retries with jitter for idempotent GETs; long timeouts only for uploads. Consider `dio` CancelToken or `cronet_http` / `cupertino_http` for HTTP/2. ETag / If-None-Match on `/home`, collections, products.

10. **Repeated profile and store calls** `(API-6)` — `fetchMe` after verify (body already has user), restore, hydrate, AccountProfile, Contacts; `fetchProfiles` ×6 in ProfileContext; `fetchStore` from independent callers.  
    **Fix:** One cached profile session; use mutation responses; share `fetchStore` via client cache (API-3).

11. **Known-fail requests and fallbacks that double traffic** `(API-7)` — gap #11: wishlist batch falls back to parallel single POSTs on 404.  
    **Partial:** Product details now skips `GET /products/:id` when seed has empty `collectionId` (listing id → collection detail first). Wishlist batch 404 fallback still open.  
    **Fix:** Once #09 verified, drop wishlist fallback; use batch DELETE on wishlist screen.

12. OTP verify → skip immediate `GET /me` unless fields missing; seed AccountProfile from session.  
13. Prefer `fetchMeWithBootstrap` — skip `GET /me/profiles` when profiles already present.  
14. Create store → avoid extra `fetchMe` + home wipe if response is enough.  
15. Accept/decline invite — use response as bootstrap.  
16. ~~Product details always `GET /products/:id` (then often collection) on open~~ **DONE (browse + channel/gallery/search seeds)** — listing cards stay collection-first (empty `collectionId`). Jewel browse attaches rich `seedCatalog`; channel Media/Gallery, store gallery feed, and search feeds attach thin `catalogSeedFromStoreProduct` so open + swipe can skip `GET /products/:id` when frames are present. Thin seeds may still lack full specs.  
17. Cart hydrate: `GET /me/cart/count` by default; full cart when Cart opens.  
18. Activity unread: poll less; push badge; or return on `/home` / `/me`.  
19. Multi-select wishlist/cart re-fetches when assets are `img_*` — BE must return real product ids on list.  
20. Home soft-prefetch of 4 stores fights the opened store — covers only; enrich on tap; cancel others.  
21. `StoreHomePrefetcher.ensure` consumes warm once — keep TTL / `peek()`.  
22. Cap `listCollections(limit: 50)` + enrich pages; don’t enrich off-screen.

### Low

23. Followers/Following — lazy-load inactive tab.  
24. Own-store members — first page on open; rest on Staff/Team.  
25. Contacts must not fire `StoreListingRefreshed`.  
26. **Wishlist prefetch dedupe** `(API-8)` — **Verified:** `WishlistPrefetcher` already has `_inFlight`. Keep an eye on auth ×2 + shell + profile-switch call sites; no new map needed unless regression.  
27. Surface 304/ETag when BE adds it (pairs with API-5 / BE-5).

---

## 2. Backend Optimisation

Some client volume only goes away with BE changes. See also `docs/BE gaps/`.

### High

1. **Batch delete endpoints** `(BE-1)` — `DELETE /products/batch` and `DELETE /collections/batch` (wishlist batch shape from gap #09: max 100 ids, counts/ids in response). Unblocks API-4.

2. ~~**One-call collections with cover + products** `(BE-2)`~~ **DONE (BE + FE)** — `GET …/collections?include=products&productsLimit=9`. FE prefetcher maps embedded `products[]`; legacy N+1 only when embed empty. See `docs/BE gaps/17-collections-include-products.md`.

3. Collection list missing collage / product ids / pending import / liked+wishlisted (gaps 01, 07, 11–13, 15).  
4. Cover `thumbhash` null on list (**blocker** gap 15).  
5. `/import-targets` 404 → FE still probes (gap 06 — return 200 empty or remove).

### Medium

6. **Open blockers** `(BE-3)` — #15 cover thumbhash; #07 wishlist `product: null`; #02 persist thumbhash + width/height after batch create.  
7. **Verify pending fixes** `(BE-4)` — re-test #08 (multi-like in one collection), #09 (wishlist batch POST/DELETE), #14 (R2/CDN URLs) on device.  
8. **HTTP and payload efficiency** `(BE-5)` — ETag/304 on `/home`, collections, products; gzip/brotli; cursor + capped limit; lite list vs detail (field projection); image dimensions + CDN variant URL in list payloads.  
9. `liked` / `wishlisted` on product GET (gap 01).  
10. Follow status `active` vs `following` (gap 10).  
11. `createdAt` on collection list (gap 12).  
12. Activity unread on home/me.  
13. Stable photo ids on list covers.

### Low

14. **Confirm and document** `(BE-6)` — #01, #02, #05, #06, #12, #13 when convenient; write #10 and #11 into API docs.  
15. Search `recentSearches` stub.  
16. Import request count when live.  
17. Profile bootstrap unread counts.

---

## 3. Caching & Request Deduplication

### High

1. In-flight coalescing for idempotent GETs on `CatalogApiClient` / repos (`ensureMe`, `ensureHome`, …) — same as API-3.  
2. Quiet refresh must share `StoreProductsPrefetcher.ensure` / shared loader.  
3. Shell `StoreProfileBloc` + pushed Discover — one bloc per `storeId` (`BlocProvider.value` when shell already hosts it).

### Medium

4. TTL for products/meta/home caches (30–120s).  
5. Soft vs hard refresh; skip network when fingerprint unchanged.  
6. Debounce Profile tab quiet refresh.  
7. Don’t invalidate whole home cache on every store create if response can patch one row.  
8. Profile-scoped home cache instead of `clearAll` on switch.

### Low

9. Persist activity unread with short TTL.  
10. Confirm single-flight `DeviceContactNames.prefetch`.

---

## 4. UI Rendering & Smoothness

Scrolling depends on eager lists, blur, pinch `setState`, and sync file checks. Merchants plan ranks pure UI as Medium (not correctness blockers); pinch/shrinkWrap/blur remain **High for jank**.

### High

1. ~~**Gallery / Media pinch:** `setState` every scale tick rebuilds full scroll/grid (and channel parent rebuilds all `TabBarView` tabs).~~ **DONE (channel Media + GalleryPinchHost)**  
   **Done in:** `gallery_pinch_host.dart`, `store_channel_route.dart`.  
   Mid-pinch uses `ValueNotifier` / `ListenableBuilder` on the Media grid only; Gallery host settles `onColumnsChanged` on release; warm/role lock until snap (Img High #4).

2. ~~**Discover Gallery nested `shrinkWrap` grids** `(UI-1)`~~ **DONE**  
   **Done in:** `store_product_gallery_sliver.dart` — real `SliverGrid`s (no nested shrinkWrap).

3. **`BackdropFilter` over scrolling imagery** `(UI-2)` — frosted pills, channel glass bar, docks (~15 BackdropFilters, few RepaintBoundarys).  
   **Partial:** channel collapsed glass bar is translucent fill only (no `BackdropFilter`). Store-profile pills / other frosts still open.  
   **Fix:** Solid/translucent fill; frost only when collapsed; `RepaintBoundary`; prefer alpha colors / `FadeTransition` over `Opacity`.

4. **Shell `IndexedStack` keeps heavy tabs alive** — also verify tab retention `(UI-4)`: shell uses IndexedStack (state kept); goal is **lazy** inactive bodies without losing badges, not accidental full remount/refetch. Nested wishlist/cart IndexedStack same idea.

5. **Discover rebuild storms** — broad `BlocBuilder`, prefs listener, chat unread, blank `setState` after details, full-tree `Opacity` for reveal. Split header/grid/docks; unread `ValueNotifier`; `Offstage` instead of `Opacity`.

6. ~~**Await image warm before first products emit**~~ **DONE** — `StoreProfileBloc._emitProductsFromCache` emits then `unawaited(_warmGridTilesBeforePaint)`; empty hydrate uses shimmer not blank.

### Medium

7. Eager `ListView(children:)` / `GridView` / shrinkWrap beyond gallery — chat_timeline, import requests, staff list, new chat, invite friends, pending uploads, store gallery, product gallery picker `(UI-1 sweep)`. Prefer `.builder` / slivers; `itemExtent` / `prototypeItem` for fixed rows.  
8. `MyStoreTab` / product details / listing — `BlocBuilder` without `buildWhen` `(ST-2)`.  
9. **Synchronous `File.existsSync` on UI paths** `(UI-3)` — `product_image.dart`, chat pieces, telegram photo route, bulk upload. Memoize outside `build()` or async.  
10. Scroll persist every tick — throttle `StoreProfileScrollCache`.  
11. Wishlist / channel pinch decode-warm — viewport only; warm on snap.  
12. Selection / wishlist / cart busy `setState` on whole store profile — isolate chrome.  
13. Shell title + activity unread — `ValueNotifier`.  
14. Discover `cacheExtent: 1800` → ~600–900.  
15. Heavy work in `build()` (selection sets, gallery sections) — memoize.  
16. Drag-select package: `setState` on every index change — selection notifier / per-cell listenables.  
17. ~357 `setState` hotspots — worst: global_search, product_details, compose, wishlist, store_channel — push local UI to `ValueNotifier`.

### Low

18. More `const` on static chrome.  
19. Stable keys; avoid rebuilding non-visible tiles.  
20. Reduce edge-fade repaints.  
21. Push listenables to leaves with `child:`.

---

## 5. State Management

BLoC handlers are concurrent by default; screens rebuild too much; some states are huge.

### High

1. **Almost no BLoC event concurrency control** `(ST-1)`  
   **Where:** `lib/bloc/**`. Only `StoreListingBloc` sets a transformer (`asyncExpand`). Default concurrent transformer on the rest.  
   **Problem:** Double-tap like/wishlist/follow, repeated load-more, fast search → duplicate/out-of-order requests; last response wins even if stale.  
   **Fix:** `bloc_concurrency` — `droppable()` for load-more / refresh / submit / toggle; `restartable()` for search/suggest; `sequential()` only where order matters.  
   **Effort:** small–medium. **Impact:** correctness + network.

2. Push Discover creates a **second** `StoreProfileBloc` when shell already hosts that store — reuse `BlocProvider.value`.  
3. **`MyStoreTab` rebuilds on every emit** (no `buildWhen`) — throttle upload progress; narrow builders.  
4. Profile switch invalidates too much (home clear-all + remount).  
5. Follow/unfollow cascades to full `LoadStoreMeta` + `LoadCollections` after optimistic update.  
6. Tab focus = full remote refresh (see API High #6).

### Medium

7. **Rebuild scope too wide** `(ST-2)` — ~44 BlocBuilders / ~13 `buildWhen`.  
   **Partial:** `product_details_route` root `BlocBuilder` now has field `buildWhen`. Remaining routes / further `BlocSelector` splits still open.  
8. **Large Equatable state** `(ST-3)` — `StoreProfileState` ~34 fields including products / productsDetailed / pendingUploads. Split cubits (header/meta, grid, uploads, follow) or compare lists by version/length+ids.  
9. Multiple SoTs: session + AccountProfile + ProfileContext + caches + legacy `MerchantStoreSession`.  
10. Dual `products` + `productsDetailed` kept equal — drop or stage cover-first.  
11. Wishlist dual state vs cart’s `CartStore` — introduce `WishlistStore`.  
12. Listener → clear-message cascades.  
13. Shell `ValueKey` remount — LRU of blocs or `StoreProfileRebind`.  
14. Settings may spawn second `AccountProfileBloc` — always pass shell `.value`.

### Low

15. **Unbounded view-dedupe set** `(ST-4)` — `ViewBeacon._sessionSeen` grows without cap. Cap size or clear on profile switch (clear already exists — ensure switch path calls it; add max size).  
16. DI healthy — preserve.  
17. Upload/connectivity dispose discipline — keep; coordinator stop on logout optional.  
18. Slim `isRefreshing` emits when UI shows no spinner.

---

## 6. Image / Media Pipeline

### High

1. Prefetch / quiet refresh decode budget (~48) — viewport-first (~12–16).  
2. Don’t await `_warmGridTilesBeforePaint` before first emit.  
3. ~~Dense 6–9 col tiles decode at half-screen `gridCacheWidth` — decode to **cell** width; role only picks URL tier.~~ **DONE (channel Media/Gallery + collection browse)** — `cacheWidthForMediaColumns` / cell `LayoutBuilder`; role still picks CDN URL.  
4. ~~Quality ladder / role switch mid-pinch — lock tier until pinch ends.~~ **DONE (channel Media + Gallery mosaics)** — role locked at pinch start; warm on settle.  
5. **Image cache too large** `(SM-2)` — see §8 High (also listed there).

### Medium

6. Quiet refresh re-precaches full grid — only new/changed URLs.  
7. Align grid cache width with column count.  
8. List cover ThumbHash from BE (gap 15).  
9. Avatar warm on every `/me` — skip if URL unchanged.  
10. Cache `existsSync` hits off paint path `(UI-3)`.  
11. Cap concurrent decodes during scroll.

### Low

12. Evict store-specific decodes when leaving a large store.  
13. Collage multi-role keys by design — limit warm window.

---

## 7. Prefetch Strategy

### High

1. Auth restore priority: home → me → (idle) wishlist; cart count / FCM after first frame.  
2. `prefetchVisible` first 4 stores — covers only; full enrich on tap.  
3. Align prefetcher enrich with bloc (API-2).

### Medium

4. Cancel store prefetch when user opens a different store.  
5. Don’t prefetch wishlist until first open (or once after auth idle).  
6. Stagger own-store products + wishlist on shell mount.  
7. Deprioritize other stores’ in-flight enrich when one store opens.

### Low

8. Prefetch product-details master on tap-down only.

---

## 8. Startup, Memory & Storage

First paint, memory headroom, and disk writes decide mid-range feel.

### High

1. ~~**Stores first paint waits on contacts index** `(SM-1)`~~ **DONE**  
   **Done in:** `store_listing_bloc.dart` — cache paints immediately; contact names enrich on the ensuing home ensure/refresh emit (phone subtitle ok until then).

2. **Image cache too large** `(SM-2)`  
   **Where:** `lib/main/main.dart` — `maximumSizeBytes = 384 << 20`, `maximumSize = 4000`.  
   **Problem:** OOM / GC jank on 3–4 GB devices.  
   **Fix:** ~100–150 MB and ~1000 entries; rely on `cacheWidth` / `ResizeImage` + disk cache; optionally device-aware.  
   **Effort:** small. **Impact:** stability.

3. Cancel in-flight store enrich when route pops; confirm upload sub / camera dispose.

### Medium

4. **Disk cache writes block and rewrite everything** `(SM-3)`  
   **Where:** `store_home_cache`, `store_products_cache`, `store_meta_cache` — full JSON rewrite with `flush: true`, encoded on UI thread.  
   **Fix:** Debounce 1–2s; encode in isolate; drop `flush: true` for disposable caches; consider drift/isar for partial updates later.

5. **Sequential startup** `(SM-4)`  
   **Where:** `main.dart` awaits Firebase → theme → quality ladder → push before `runApp`.  
   **Fix:** `Future.wait` independent steps; move push init to after first frame.

6. Cap `ChatMockStore`; bound scroll-cache map; split chat notifiers (`unreadTotal` vs full store).

### Low

7. **Oversized runtime asset** `(SM-5)` — `assets/icons/app_logo.png` ~1 MB. If only for launcher generation, remove from `pubspec` assets; if shown in-app, ship 256–512 WebP.  
8. QA / `FCM_DEBUG` `print`s behind `kDebugMode` only.  
9. `ProductUploadCoordinator.dispose` on logout optional.

---

## 9. Search & Lists

### High

1. Global search: no double suggest+search on submit.  
2. Private products client-filtered after full page — BE should omit invisible hits.

### Medium

3. In-store search chrome — notifier, not per-pixel `setState`.  
4. Returning from profile: don’t refresh `/home` unless stale.  
5. Cancel in-flight suggest when query changes.

### Low

6. Suggest debounce 200ms — keep.

---

## 10. Networking Client Hardening

### High

1. Global GET coalescing + short TTL (API-3).  
2. Concurrency budget (e.g. max 4 catalog GETs + 6 image downloads).

### Medium

3. Retry only idempotent GETs; split timeouts (API-5).  
4. 304/ETag when BE supports (BE-5).  
5. Optional better HTTP stack for HTTP/2 / cancellation (API-5).

### Low

6. Compress/redact debug JSON only inside `kDebugMode` (pairs with API-1).

---

## 11. Code Health

None are speed blockers; they make the fixes above cheaper.

### High / Medium

None.

### Low

1. **Very large files** `(CH-1)` — `product_details_route` (~2815), `bulk_upload_bloc` (~2585), `product_gallery_picker` (~2421), `store_profile_bloc` (~2324), `add_product_compose_route` (~2303), `store_profile_route` (~2193). Split into widgets / use cases / small cubits so `const` + selective rebuilds are practical.  
2. **Mock chat in the app** `(CH-2)` — `ChatMockStore` (~1454 lines, many refs). Feature-flag or lazy-init until real API.  
3. **Leftover prints** `(CH-3)` — ~14 `print(` including `AppLog.full`. Gate or remove.  
4. **Lint and analysis** `(CH-4)` — `flutter analyze` / `dart fix`; enable `prefer_const_constructors`, `unawaited_futures`, `avoid_print`.

---

## Top duplicate-call hotspots (impact order)

| # | Hotspot | Typical redundant calls |
|---|---------|-------------------------|
| 1 | Store open / remount | `GET store` + `GET collections` + **N×** products/collection detail + quiet refresh repeat |
| 2 | Cold start / session restore | `/home` + `/me` + `/me/profiles` + `/wishlist` + full `/me/cart` + activity unread + store storm |
| 3 | Profile switch | Clear home → prefetch home + wishlist + products; remount → meta + collections N+1 |
| 4 | Home soft-prefetch vs tap | Up to 4 stores enrich while opened store enriches again |
| 5 | Stores tab select | Always `GET /home` |
| 6 | Wishlist tab select | Always force `GET /wishlist` |
| 7 | Profile tab select | `GET /me` + `GET /me/profiles` |
| 8 | Product details open / swipe | Browse jewel: seed / session cache (no per-swipe GET). Else `GET /products/:id` then often collection |
| 9 | OTP login | Verify + `GET /me` ×2–3 + profiles + home/wishlist/cart |
| 10 | Visitor import probe | **N×** `GET …/import-targets` |
| 11 | Bulk owner delete | **N×** delete + emit + cache write |
| 12 | Logging path | Double `jsonDecode` + sanitize even when logs discarded |

---

## Top UI jank hotspots (user-visible impact)

| # | Hotspot | Priority |
|---|---------|----------|
| 1 | ~~Gallery / Media pinch → `setState` every frame~~ **DONE** (ValueNotifier) | High |
| 2 | ~~Discover Gallery nested `shrinkWrap` grids~~ **DONE** (SliverGrid) | High |
| 3 | Await disk/decode warm before first products emit | High |
| 4 | `BackdropFilter` over scrolling imagery | High (channel glass **partial**) |
| 5 | Dense tiles decode at half-screen width | High |
| 6 | ~~Channel parent `setState` rebuilds all tabs while pinching~~ **DONE** | High |
| 7 | Shell `IndexedStack` always-alive heavy tabs | High |
| 8 | Discover rebuild storms | Medium–High |
| 9 | `ChatMockStore.notifyListeners` fan-out | Medium |
| 10 | Large `cacheExtent` + ThumbHash / ladder pressure | Medium |
| 11 | Contacts gate delaying Stores first paint | High (SM-1) |
| 12 | 384 MB image cache → GC / OOM pressure | High (SM-2) |

---

## How to verify

1. `flutter run --profile` — DevTools timeline for cold start, Stores scroll, store profile scroll, product details.  
2. **Track widget rebuilds** — compare before/after ST-2 / ST-3.  
3. Filter debug logs with tag **`ApiCallCount`** (`CatalogApiCallLog`) — scopes: `STORE_OPEN`, plus child screens from store profile (`COLLECTION_BROWSE`, `PRODUCT_DETAILS`, `STORE_CHANNEL`, `STORE_SEARCH`, `CART`, `FOLLOW_REQUESTS`, `FOLLOWERS_FOLLOWING`, `ADD_PRODUCT`, `CHAT_THREAD`). Each scope lists endpoints + total; ends on idle after last call; navigating starts a new scope (previous dumps). Compare `total=` to CloudWatch.  
4. Memory: image cache **384 MB vs ~128 MB** (SM-2).  
5. After API-1: confirm release builds no longer `jsonDecode` solely for logging (CPU sample / breakpoint).  
6. After ST-1: double-tap like/follow — single network call.  
7. After SM-1: Stores paints before contacts permission settles.  
8. Measurable wins to record in PRs: GET count on store open, TTFP, pinch timeline, tab-switch network.

---

## Related docs

- `docs/BE gaps/README.md` — backend payload gaps  
- `docs/profile-switching-be-gaps.md` — profile switch FE/BE alignment  
- `docs/profile-switching-test-cases.md` — switch QA  
- `PROJECT_UI_CONVENTIONS.md` — UI / shell conventions  
- Feature `FEATURE_CONVENTIONS.md` under each `lib/presentation/*/` folder  

---

## Tracking

When implementing a slice:

1. Check items off here (or link a PR); cite Merchants IDs (`API-1`, `ST-1`, …) in the PR description when applicable.  
2. Update the matching `FEATURE_CONVENTIONS.md` if behaviour changes.  
3. Prefer the verify checklist above over anecdotal “feels faster”.
