# 07 — Wishlist path must set `product` (not null)

**Status:** Fix — blocker  
**Index:** [README.md](./README.md)

---

## Observed

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
    "message": "E11000 duplicate key error collection: test.catalog_wishlist index: user_1_product_1 dup key: { user: ObjectId('…'), product: null }"
  }
}
```

---

## Root cause

Unique index `user_1_product_1` violated with **`product: null`**. Path id is not
written onto the wishlist document (or a prior bad `{ user, product: null }` row
exists).

---

## Required

1. On `POST /wishlist/products/:productId`, set `product = ObjectId(path.productId)` (never null).
2. Same for collection wishlist: set `collection` from path.
3. Already bookmarked → **`200`** + `alreadyWishlisted: true` (no raw Mongo E11000).
4. Cleanup null-product / null-collection wishlist rows.
5. Prefer a partial unique index that ignores nulls, **or** make fields required.

### Suggested responses

```json
{ "wishlisted": true, "productId": "…", "wishlistId": "…" }
```

```json
{ "wishlisted": true, "alreadyWishlisted": true, "productId": "…", "wishlistId": "…" }
```

---

## FE today

Body alias `POST /wishlist` `{ productId }`, then photos alias. Still surfaces
`product: null` conflicts (does not hide the bug).

---

## Acceptance

- [ ] Path POST never inserts `product: null`
- [ ] Idempotent already → 200 + `alreadyWishlisted`
- [ ] No raw E11000 to clients
- [ ] Null rows cleaned up / index fixed
