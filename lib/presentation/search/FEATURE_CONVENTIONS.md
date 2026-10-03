# Search Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/search/`.

## Mandatory Update Rule
- If global/in-store search screens, filter sheet behavior, API mapping, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper`, `AppPadding`, `AppTextStyles`, `AppColors`, and `AppBackButton`.
- Reuse local `search_widgets/` for field, chips, discover, suggestions, results, filter bar, filter sheet, and shimmers.
- Telegram-style white surfaces; filled search field matches Stores home
  (`BorderRadius.circular(32)`, `contentPadding` 12/12, `surfaceSecondary`
  fill). `SearchAppBarField` and store-profile footer use the same chrome.
- Global / in-store results use a horizontal filter strip. First pill is **Sort & Filter** → pushes `search_filters_route` (full screen, Flipkart-style split Filters). Remaining pills are per-group dropdowns. In-store drops Store + Location; zero-count options are greyed.
- Selecting a dropdown option applies immediately, closes the menu, and reloads results. **Sort & Filter** screen edits all groups together; **Apply** pops the selection (live preview count on the CTA).
- `global_search_route` uses `SmoothFadePageRoute` (fade only). Keyboard shows after the entry animation and stays until tap-outside, Cancel/Back, or edge back-swipe.
- Loading states use layout-matched shimmers (`search_shimmers.dart`) — never `CircularProgressIndicator` for Discover, suggestions, facets chips, or results grids (including load-more).

## Logic Ownership
- Live catalog search APIs via `SearchRepository` (`lib/webservice/search/`):
  - `GET /search/meta` — Discover (trending + category tiles). **Ignore stub `recentSearches`** until a real per-user recent API exists.
  - `GET /search/suggest` — typeahead (200ms debounce)
  - `GET /search` — global results + facets
  - `GET /stores/:id/facets` — in-store “What this store has” chips
  - `GET /stores/:id/search` — in-store results + facets
- Recent searches are **device-local** via `SearchRecentPreferences` (secure storage). Cap is **3** latest items (storage + Discover UI). Clear persists across route re-entry. Query/store opens are recorded after successful use. In-store search has no Recent section.
- Committing a **text** search (field submit, recent query, trending) resets facet filters (keeps sort) so leftover category/filters do not AND with the new `q`.
- Category tiles set only that category filter (no `q`). Horizontal filter dropdowns / sort update selection and reload results.
- Filter keys sent to API are facet `value`s (e.g. `necklace`, `under_10`), not display labels.
- Sort maps: Newest → `newest`, Lightest → `weight_asc`, Heaviest → `weight_desc`.
- Side effects (snackbars, navigation) stay in route methods, not in `build`.
- Errors use `CatalogErrorMapper.toUserMessage` (never raw API text).

## Route and Navigation Notes
- `global_search_route` — Discover / suggestions / results across all stores. Opened from Stores home search.
- `store_search_route` — Scoped to one store. Opened from store profile app-bar search.
  While browsing results, scrolling down past the first row hides search / filters /
  “What this store has” (store title + back stay). Chrome returns only after
  scrolling back up into the first 2 items. Collapse animates with scroll-offset
  compensation so items do not jump.
- Arguments for store search: `storeId`, `storeName`, optional `storeCity`, `productCount`.
- Store suggestion / result with a store id → `store_profile_route`. Recent store rows without `id` fall back to text search.
- **Product result tap** → `product_details_route` with a `galleryFeed` of the
  **current filtered search results** (one page per hit). Swipe moves to the next
  / previous result — not other photos inside the same collection. Global search
  hits may span stores (per-hit `storeId` on feed items). Store name shows a `>`
  chevron → opens that store’s `store_profile_route` with the listing group
  highlighted; tapping the group opens collection browse (all items). Suggest
  taps open a single-hit feed. Does **not** open `collection_browse_route` on
  the result card itself.
- API contract: `lib/webservice/search/CATALOG_SEARCH_AND_FILTER.md`.

## Folder Scope
- `global_search_route.dart`: platform-wide search UI.
- `store_search_route.dart`: in-store search UI.
- `search_models.dart`: UI filter selection + card mapping from API hits.
- `search_filters_route.dart`: full-screen Sort & Filter (Apply pops selection).
- `search_widgets/`: search-only visual components.
- API DTOs live in `lib/models/catalog/search_models.dart`.
