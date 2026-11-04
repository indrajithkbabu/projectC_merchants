# Cart Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/cart/`.

## Mandatory Update Rule
- If cart layout, grouping, remove/wishlist actions, or requirements change, update this file in the same PR.

## Scope
- Wired to Catalog cart API (`CATALOG_CART_API.md`):
  - `POST /me/cart`, `GET /me/cart`, `GET /me/cart/count`
  - `DELETE /me/cart/:productId`, `DELETE /me/cart/batch`
  - `POST|DELETE /me/cart/:productId/wishlist`
- `CartStore` is an in-memory badge/cache only; BE is source of truth.
- No checkout / buy. Footer shows non-tappable “You can continue buying soon”.
- No FE cart-size cap (BE has none).

## UI Rules
- Wrap with `ScreenWrapper`, use `AppPadding` / `AppTextStyles` / `AppColors` / `AppBackButton`.
- Items grouped by store in first-added store order from `GET /me/cart`.
- TOTAL FINE uses `summary.displayTotalFine` (Au · Ag segregation).
- Out-of-stock rows: greyscale thumb, muted text, red “Out of stock →” pill (opens store). Excluded from totals by BE.
- Row actions always visible: delete (bin) and Wishlist. Undo snack ~2.5s:
  - Delete undo → `POST /me/cart` with that product id
  - Wishlist undo → `DELETE /me/cart/:productId/wishlist`
- Header heart: `popUntil` shell (`store_listing_route` / first), then
  `ShellNav.request(wishlist)` — do **not** only `maybePop` (that leaves
  store profile / channel on the stack). Wishlist tab exists for store
  accounts; personal accounts have no Wishlist tab (request is a no-op).

## Entry points
- **Global (own-store shell):** Wishlist bottom tab → **Cart** pill
  (`CartRoute(embeddedInShell: true)` via `WishlistTab` /
  `ShellNavTab.cart`).
- Store profile / channel visitor header cart badge → `Routes.cartRoute`
  (full-screen; Back returns to store).
- Selection dock **Add N to cart** / **Go to cart** (toast prefers server `toastMessage`).
- Product details cart toggle (visitors only).
- Snack **View** action → cart route.
- Full-screen cart header heart → shell Wishlist pill (`ShellNavTab.wishlist`).

## QA
- Device cases: `docs/CART_QA.md` (TC-00…TC-12).
- Logcat / console filter: **`CART_QA`** (`lib/helper/cart_qa.dart`).
- Walk one TC at a time; look for `TC-xx START` / `PASS|FAIL`.
