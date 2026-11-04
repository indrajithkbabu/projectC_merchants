# Backend gaps (catalog API)

**Base:** `https://api.bullionare.com/v1/catalog`  
**Auth:** `Bearer <catalog_token>`

Each numbered file is **one issue**. Open that file for request/response examples and what to fix.

---

## What each status means

| Status | Meaning |
|--------|---------|
| **Blocker** | Broken today — please fix |
| **Confirm** | App already handles it — please confirm the API always does this |
| **Verify** | You said it’s fixed — we still need to re-test |
| **Document** | Behavior is fine — please write it in the API docs |

---

## Gaps (open one file)

| # | Topic | Status | File |
|---|--------|--------|------|
| 01 | Product GET must return `liked` + `wishlisted` for signed-in users | Confirm | [01](./01-authed-product-liked-wishlisted.md) |
| 02 | Keep `thumbhash` on images after batch upload | Confirm | [02](./02-thumbhash-after-batch.md) |
| 03 | Stock / lock PATCH on **product** id (not collection id) | Confirm | [03](./03-stock-lock-patch.md) |
| 04 | Store wastage markup + product `wastage_pct` | Confirm | [04](./04-wastage-markup.md) |
| 05 | Activity event `product_liked` (like only — not wishlist) | Confirm | [05](./05-activity-product-liked.md) |
| 06 | Import stubs return **200** + empty list (not 404) | Confirm | [06](./06-import-stubs.md) |
| 07 | Wishlist POST must set `product` (never `null`) | **Blocker** | [07](./07-wishlist-product-null.md) |
| 08 | Allow liking many products in the same collection | **Verify** | [08](./08-product-like-collection-index.md) |
| 09 | Bulk wishlist `POST` / `DELETE /wishlist/batch` | **Verify** | [09](./09-wishlist-batch.md) |
| 10 | `followStatus`: use one name (`following` vs `active`) | Document | [10](./10-follow-status-naming.md) |
| 11 | `GET /products/:collectionId` → 404 is expected | Document | [11](./11-collection-id-on-product-get.md) |
| 12 | Add `createdAt` on collection list + detail | Confirm | [12](./12-collection-created-at.md) |
| 13 | Every collection photo must have a stable `id` | Confirm | [13](./13-collection-photo-id.md) |
| 14 | R2 display URLs: CDN variants + public GET + cover thumbhash | **Verify** | [14](./14-r2-responsive-display-urls.md) |
| 15 | Collection list `cover.thumbhash` still null after #14 | **Blocker** | [15](./15-collection-cover-thumbhash.md) |

---

## Suggested order to fix

1. **15** — collection cover thumbhash on `GET …/collections` (blocker)
2. **07** — wishlist `product: null` (blocker)
3. **08** — re-test multi-product likes in one collection
4. **09** — re-test wishlist batch
5. **14** — finish device verify of media URLs
6. Then confirm **01, 02, 05, 06, 12, 13** when convenient


