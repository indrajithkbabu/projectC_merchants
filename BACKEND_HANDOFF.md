# Backend handoff — remaining catalog gaps

> **Prefer [`docs/BE gaps/`](./docs/BE%20gaps/README.md)** — one markdown per
> gap. This file keeps the longer narrative / payloads.

Frontend has implemented best-effort clients for the items below. Please confirm
or fix server behavior so these FE paths are authoritative (not cache/fallback).

**Verify (debug):** filter logs with `BeVerify` — scenarios in `BE_VERIFY.md`
(and product-details notes in `PRODUCT_DETAILS_BACKEND.md`).

---

## 1. `liked` + `wishlisted` on every authed product GET

### FE logic (already shipped)
- `GET /products/:productId` uses `allowAnonymousBearer: true` so a JWT is
  attached when the user is signed in.
- On success, `ProductDetailsBloc` sets:
  - heart from `liked == true` (also seeds primary `imageId` into liked set)
  - bookmark from `wishlisted` when present
- If `wishlisted` is **omitted**, FE falls back to warm `GET /wishlist` cache
  (`WishlistPrefetcher.containsTargetId`) so the bookmark can still light up.

### What backend should guarantee
When `Authorization: Bearer <token>` is present on:

```http
GET /v1/catalog/products/:productId
```

Always include:

```json
{
  "liked": true,
  "wishlisted": false
}
```

- `liked` — public appreciation for this viewer (drives heart)
- `wishlisted` — private bookmark for this viewer (drives bookmark; **no** notify)

Omit only for fully anonymous requests. Do not omit for signed-in viewers.

---

## 2. Thumbhash (and bytes) persisted after batch create

### FE logic (already shipped)
- Batch rows send `thumbhash`, `key`, `bytes`, `width`, `height` with
  `image_id` / `image_ids` on `POST …/products/batch`.
- After batch success, FE **merges local ThumbHashes** onto the in-memory
  `StoreProduct` when the response omits them (so InstantCatalogPhoto still
  works immediately).
- List/detail later still need server-persisted hashes for cold start / other
  devices.

### What backend should guarantee
On batch create (and subsequent `GET /products/:id` / store products list),
each image should retain the client-supplied (or server-computed) fields:

```json
{
  "images": [
    {
      "imageId": "img_…",
      "url": "https://…cloudfront…",
      "thumbhash": "<non-null base64>",
      "width": 978,
      "height": 1280
    }
  ]
}
```

If the sign session already stored thumbhash/bytes, copy them onto the product
image docs at commit time. Prefer non-null `thumbhash` whenever the client sent
one.

---

## 3. Owner stock / lock PATCH + store wastage markup

### FE logic (already shipped)
**Product availability** (owner overflow → Availability):
```http
PATCH /v1/catalog/products/:productId
```
```json
{
  "stock_status": "in" | "out" | "mto",
  "mto_days": 7,
  "is_locked": true
}
```
FE expects the updated product document back (same shape as GET).

**Important (observed prod):** Collection detail ids are **not** product ids.
- `GET /products/:collectionId` → `404 PRODUCT_NOT_FOUND` (FE falls back to
  collection detail).
- FE Availability now PATCHes each embedded `products[]._id` from collection
  detail (never the collection id).
- Collection GET may keep `is_locked: false` while every `products[]` row is
  locked after PATCH. FE ORs product locks / prefers product `stock_status` for
  listing chrome, and pops `{updated: true}` so the store grid stays in sync.

**Store default wastage** (Account privacy → Store defaults):
```http
PATCH /v1/catalog/stores/:storeId/wastage-markup
```
```json
{ "wastageMarkup": 12.0 }
```
FE also reads `defaultWastageMarkup` from `GET /stores/:storeId`.

### What backend should guarantee
- PATCH product syncs all photos of a `sub_collection` (docs already say this).
- For multi-product collections, either:
  - accept a **collection-level** stock/lock PATCH that fans out to all
    products, **or**
  - keep per-product PATCH and also refresh collection-level `stock_status`
    on collection GET after any child product changes.
- wastage-markup endpoint returns the store (or at least the new
  `defaultWastageMarkup`) and GET store includes it.
- Prefer non-null `wastage_pct` on products when weight is set (Fine weight
  needs it); FE shows Gross when wastage is null.

---

## 4. Activity `product_liked` + import stubs

### FE logic (already shipped)
**Activity**
- Parses `type: "product_liked"`.
- `entityId` from `entityId` **or** `productId` **or** `data.productId`
  **or** `listingId`.
- Actor avatar from `actor.image` (also `avatarUrl` / `avatar`).
- Uses server `title` / `message` when present.
- Tap opens **own** store profile with `focusProductId = entityId`.

Expected payload fields (matches likes-and-wishlist §5):

```json
{
  "id": "…",
  "type": "product_liked",
  "title": "…",
  "message": "Ajith liked Antique Jhumka",
  "actor": { "id": "…", "name": "…", "image": null },
  "store": { "id": "<ownerStoreId>", "name": "…" },
  "productId": "<CatalogProduct._id>",
  "entityId": "<same>",
  "data": { "productId": "…", "collectionId": "…", "storeId": "…" },
  "thumbnails": ["https://…"],
  "read": false,
  "createdAt": "2026-10-16T12:00:00.000Z"
}
```

Wishlist must **not** create activity or push.

**Import requests**
- FE treats empty `items: []` as success.
- FE also treats `404` / message containing `disabled` as empty (no error
  snackbar), matching the documented stub.

### What backend should guarantee
- Emit `product_liked` on public like only (in-app; zero push).
- Keep import stubs as **HTTP 200** with empty items on all environments
  (avoid 404 so older clients stay quiet).

---

## 5. Wishlist add must set `product` (blocker — observed in prod/test)

### Observed (mobile logs, Oct 2026)

```http
POST /v1/catalog/wishlist/products/6ad23d65a3cea5a8ee346ae8
Authorization: Bearer …
Content-Type: application/json

{}
```

```http
HTTP/1.1 409 Conflict
```

```json
{
  "error": {
    "code": "***",
    "message": "E11000 duplicate key error collection: test.catalog_wishlist index: user_1_product_1 dup key: { user: ObjectId('6ad2234905fc7b607e51fa4c'), product: null }"
  }
}
```

### FE logic (already shipped)
- Primary: `POST /wishlist/products/:productId` (empty JSON body; path is the
  contract).
- On `404` / `409`: retries documented aliases —
  `POST /wishlist` with `{ "productId" }`, then `POST /photos/:id/wishlist`.
- Expects `200`/`201` with `{ "wishlisted": true, "productId": "…" }` or
  idempotent `{ "alreadyWishlisted": true, … }`.
- Treats non–`product:null` duplicate `409` as already bookmarked; still
  surfaces `product: null` conflicts so the BE bug stays visible.

### Root cause (server-side)
Unique index `user_1_product_1` is violated with **`product: null`**. The path
id is not being written onto the wishlist document’s `product` field (or a
prior bad row already exists with `{ user, product: null }`).

### What backend should guarantee
1. On `POST /wishlist/products/:productId`, always set  
   `product = ObjectId(path.productId)` (never null).
2. Same for collection wishlist: set `collection` from path, not null.
3. Idempotent: same user + product already wishlisted → **`200`** with
   `alreadyWishlisted: true` (do not surface raw Mongo `E11000`).
4. Clean up any existing `catalog_wishlist` rows where `product` (or
   `collection`) is `null` so the unique index cannot trap the first good
   insert after a bad write.
5. Prefer a partial unique index that ignores nulls, **or** make `product` /
   `collection` required so null rows cannot be inserted.

### Suggested success responses

First bookmark:
```json
{
  "wishlisted": true,
  "productId": "6ad23d65a3cea5a8ee346ae8",
  "wishlistId": "…"
}
```

Already bookmarked:
```json
{
  "wishlisted": true,
  "alreadyWishlisted": true,
  "productId": "6ad23d65a3cea5a8ee346ae8",
  "wishlistId": "…"
}
```

---

## Quick checklist for BE

| # | Endpoint / behavior | Status needed |
|---|---------------------|---------------|
| 1 | Authed `GET /products/:id` → always `liked` + `wishlisted` | Confirm |
| 2 | Batch create → persist `thumbhash` (+ size) on images | Confirm |
| 3a | `PATCH /products/:id` stock/lock/mto | Confirm (FE UI live) |
| 3b | `PATCH /stores/:id/wastage-markup` + GET field | Confirm (FE UI live) |
| 4a | Activity `product_liked` with `productId`/`entityId` | Confirm |
| 4b | Import stubs → 200 empty everywhere | Confirm |
| 5 | `POST /wishlist/products/:id` sets `product` (not null); idempotent 200 | **Fix — blocker** |
| 6 | `PUT /products/:id/like` must not collide on `user_1_collectionId_1` | **Claimed fixed** — verify (`PRODUCT_LIKE_BACKEND.md`); see `REMAINING_BE_GAPS.md` |
| 7 | `POST`/`DELETE /wishlist/batch` | **Claimed fixed** — FE uses batch add; verify |
