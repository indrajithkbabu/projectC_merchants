# 16 — Cart API device verify (after `CART_QA`)

**Status:** Verify (run on device; open blockers from failures)  
**Filter:** `CART_QA` · Checklist: `docs/CART_QA.md`

## What to confirm

Walk TC-00…TC-10 against live Catalog cart (`CATALOG_CART_API.md`):

| TC | API surface |
|----|-------------|
| TC-00 | `GET /me/cart` and/or `GET /me/cart/count` on hydrate |
| TC-01 | `POST /me/cart` bulk add + `toastMessage` / `storeCount` |
| TC-02 | Skip already-in-cart + OOS; only addables posted |
| TC-05 | Single add / remove from photo |
| TC-06 | Grouped cart + `displayTotalFine` Au·Ag |
| TC-07 | `DELETE /me/cart/:id` + undo `POST /me/cart` |
| TC-08 | `POST …/wishlist` + undo `DELETE …/wishlist` |
| TC-09 | Cross-store cart / toast store count |
| TC-10 | `403` `STORE_PRIVATE` / `LOCKED_PRODUCT` |

## After device

- Paste failing `CART_QA` lines here (or split into new numbered gap files).
- Update this file’s status to Confirm when all TC PASS, or promote each failure to its own Blocker file and link from `README.md`.

## FE-only (not BE)

TC-11 (Import dock gating), TC-12 (no checkout footer) — FE UI; no BE ticket unless API forces checkout.
