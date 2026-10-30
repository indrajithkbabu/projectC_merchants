# Backend handoff — product like `409` on `user_1_collectionId_1`

**Status:** BE reports fixed (partial unique index only when
`itemType: 'collection'` — see bulk-wishlist-and-like-fixes). **Re-verify**
liking 2+ photos in one collection before treating as closed. Gap file:
[`docs/BE gaps/08-product-like-collection-index.md`](./docs/BE%20gaps/08-product-like-collection-index.md).

**Prior verdict: BE fix required.** FE is calling the correct product id.

Observed Oct 2026 against `api.bullionare.com` / `test.catalog_like` while
liking **one photo** inside a multi-product collection from product details.

---

## Observed (mobile `BeVerify` logs)

```text
[BeVerify] ==== L like product ====
[BeVerify]   -> id=6adb36…4cef listing=6adb36…4cec photo=1 → like
[BeVerify] ==== L PUT /products/:id/like ====
[BeVerify]   -> id=6adb36…4cef
[BeVerify] FAIL product like | status=409 code=CONFLICT
  E11000 duplicate key error collection: test.catalog_like
  index: user_1_collectionId_1
  dup key: { user: ObjectId('6adb0251eac743540995717d'),
             collectionId: ObjectId('6adb361aa783c5569c224cec') }
```

### Ids

| Role | Id (suffix) | Source |
|------|-------------|--------|
| **Product** FE liked | `…4cef` | Embedded `products[]._id` for photo index 1 |
| **Collection** listing | `…4cec` | Store-grid / collection detail id |
| Dup key `collectionId` | `…4cec` | Server wrote / matched **collection**, not product |

### Request FE sent

```http
PUT /v1/catalog/products/6adb36…4cef/like
Authorization: Bearer …
Content-Type: application/json

{}
```

FE does **not** send the collection id on this call. The conflict key is the
parent collection id — so the like writer is stamping `collectionId` (and
colliding on a unique index that ignores `product`).

---

## FE behavior (already shipped — keep)

1. Open multi-photo collection → `GET /products/:collectionId` → 404 →
   collection detail with embedded `products[]`.
2. Thumbs-up on photo N → `PUT /products/:embeddedProductId/like` where
   `embeddedProductId` is that photo’s CatalogProduct `_id` (not the
   collection listing id).
3. UI likes **only that product**; other photos stay unliked.
4. On `409` / `CONFLICT` with this Mongo message, FE surfaces the error (does
   **not** treat as already-liked), so the BE bug stays visible — same pattern
   as wishlist `product: null`.

Related: wishlist path must set `product` (see `BACKEND_HANDOFF.md` §5). This
like bug is the same class: wrong / missing document field + unique index.

---

## Root cause (server-side)

`catalog_like` unique index:

```text
user_1_collectionId_1
```

On `PUT/POST /products/:productId/like` the handler appears to:

1. Resolve the product’s parent collection, then
2. Upsert a like row keyed by `{ user, collectionId }`, and/or
3. Leave `product` unset / unused for uniqueness.

So:

- First like on **any** product in the collection may succeed (or leave a row
  for `collectionId=…4cec`).
- Second like on a **different** product in the same collection → `E11000` on
  `user_1_collectionId_1`.
- Or a prior like already exists for that user+collection → same 409 even on
  the first FE attempt for product `…4cef`.

Product-level public like (docs / activity `product_liked`) cannot work while
uniqueness is only `(user, collectionId)`.

---

## What backend should guarantee

1. On `PUT` / `POST` / `DELETE` `/products/:productId/like`:
   - Always set **`product = ObjectId(path.productId)`** (never null).
   - Optionally also store `collectionId` for aggregation — but uniqueness for
     **product like** must be **`(user, product)`**, not `(user, collectionId)` alone.
2. Replace or complement `user_1_collectionId_1` with something like:
   - `user_1_product_1` unique (sparse / partial where `product` exists), **or**
   - separate collections / discriminators for collection-like vs product-like.
3. Idempotent: same user + product already liked → **`200`** with
   `alreadyLiked: true` (do not surface raw Mongo `E11000`).
4. Clean up existing `catalog_like` rows that only have `collectionId` and no
   `product` (or duplicate collection-scoped rows) so good inserts are not
   trapped.
5. `GET /products/:productId` with Bearer must return `liked: true|false` for
   **that product** (not “any like in the parent collection”).

### Suggested success responses

First like:

```json
{
  "liked": true,
  "productId": "6adb36…4cef",
  "likeCount": 1,
  "likeId": "…"
}
```

Already liked:

```json
{
  "liked": true,
  "alreadyLiked": true,
  "productId": "6adb36…4cef",
  "likeCount": 1,
  "likeId": "…"
}
```

---

## Not an FE fix

| Change | Why not |
|--------|---------|
| Like with collection id again | Breaks per-photo / per-product like; all photos show liked |
| Treat this 409 as `alreadyLiked` | Conflict is on **collection**, not the product FE asked to like — would lie to the UI |
| Photo-like alias only | Jewel path is product like; BE should honor product id |

FE stays on embedded product id. BE must fix `catalog_like` write + index.

---

## Quick checklist for BE

| Item | Status needed |
|------|----------------|
| `PUT /products/:id/like` sets `product` from path | **Fix — blocker** |
| Unique index allows one like per **product** (not only per collection) | **Fix — blocker** |
| Idempotent 200 + `alreadyLiked` (no raw E11000) | Fix |
| Authed GET product returns per-product `liked` | Confirm (handoff §1) |
| Cleanup bad `catalog_like` rows / index | Ops |

See also: `BACKEND_HANDOFF.md` §1 (liked/wishlisted on GET), §5 (wishlist
`product: null` — same pattern).
