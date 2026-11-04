# Cart QA — test cases (`CART_QA`)

**Logcat / console filter:** `CART_QA`  
**API:** `CATALOG_CART_API.md` · Base `/v1/catalog`  
**Helper:** `lib/helper/cart_qa.dart`

Walk **one TC at a time**. Filter logs with `CART_QA`. Each action emits `TC-xx START` / `PASS|FAIL`.

---

## How to run

1. Debug build, signed in.
2. Logcat filter: `CART_QA`
3. Follow each case below on device.
4. Paste filtered lines when filing BE gaps.

---

## Test matrix

| TC | Case | Steps | Expect | FE wired | Device |
|----|------|-------|--------|----------|--------|
| TC-00 | Hydrate | Cold start / login | `GET /me/cart` (or count fallback); badge ids ready | Yes | Verify |
| TC-01 | Bulk add | Long-press → select new photos → Add | `POST /me/cart`; toast; badge bump | Yes | Verify |
| TC-02 | Mixed skip | Select new + in-cart + OOS → Add | Button counts addable only; toast skips; no dupes | Yes | Verify |
| TC-03 | Go to cart | Select only already-in-cart | Dock **Go to cart** → opens cart; Back returns | Yes | Verify |
| TC-04 | All OOS | Select only out-of-stock | Dock **Out of stock** disabled; heart still works | Yes | Verify |
| TC-05 | Photo add/remove | Open photo → trolley → again | Add toast+check; second tap removes | Yes | Verify |
| TC-05b | Photo OOS | Open OOS photo | Add blocked / dimmed | Yes | Verify |
| TC-06 | Cart screen | Open cart from header/View | Grouped by store; `displayTotalFine` Au·Ag | Yes | Verify |
| TC-07 | Remove + Undo | Bin → Undo within ~2.5s | `DELETE` then undo `POST /me/cart` | Yes | Verify |
| TC-08 | Wishlist + Undo | Wishlist → Undo | `POST …/wishlist` then `DELETE …/wishlist` | Yes | Verify |
| TC-09 | Cross-store | Add from store A then B | One cart; toast may say from N stores; groups both | Yes | Verify |
| TC-10 | Private/locked | Add locked/private without access | `403 STORE_PRIVATE` / `LOCKED_PRODUCT` snack | Yes | Verify |
| TC-11 | Account dock | Store visitor vs individual | Import shown only for store-on-store | Yes | FE UI |
| TC-12 | No checkout | Cart footer | Dashed “continue buying soon” not tappable | Yes | FE UI |

**Legend:** FE wired = code path exists. Device = needs live BE confirm (`PASS` in Logcat).

---

## Static FE review (pre-device)

| TC | Verdict | Notes |
|----|---------|-------|
| TC-00 | FE ready | Hydrate after auth + cart open |
| TC-01 / TC-02 | FE ready | `VisitorCartBatch` → `addProductIds`; snack prefers `toastMessage` |
| TC-03 / TC-04 | FE ready | `CartSelectionBreakdown` drives dock |
| TC-05 | FE ready | Product details toggle |
| TC-06 | FE ready | `CartRoute` + Au/Ag footer |
| TC-07 / TC-08 | FE ready | Undo wired to restore / undoWishlist APIs |
| TC-09 | FE ready | Global cart + `storeCount` in toast |
| TC-10 | FE ready | Errors via `CatalogErrorMapper` |
| TC-11 | FE ready | `showImport: state.canImport` |
| TC-12 | FE ready | Non-tappable dashed bar |

**Known FE gaps (not BE):**
- No global cart entry on Stores home / Settings yet (entry today: store header, Go to cart, toast View, photo).
- Fly-to-cart animation / long-press hint pill not shipped.
- Photo chrome uses top cart toggle (not exact bottom-right trolley mock).

---

## After device run → BE gaps

If any `TC-xx FAIL` with API status/code, open a file under `docs/BE gaps/` (next: **17-cart-…**) and update `docs/BE gaps/README.md`.
