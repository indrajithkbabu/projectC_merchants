# 08 — Product like index (`user_1_collectionId_1`)

**Status:** Claimed fixed — verify  
**Index:** [README.md](./README.md)  
**Detail history:** root `PRODUCT_LIKE_BACKEND.md`

---

## BE claim

Uniqueness on `(user, collectionId)` only when `itemType: 'collection'`; users
can like unlimited photos/products in one collection. Endpoints unchanged:
`PUT|POST /products/:productId/like` (ObjectId or `img_…`).

---

## Prior observed failure

```text
PUT /products/:embeddedProductId/like
→ 409 E11000 index: user_1_collectionId_1
  dup key: { user: …, collectionId: <parent collection id> }
```

FE liked the **embedded CatalogProduct** id; conflict key was the **collection**
id. FE does **not** treat this 409 as `alreadyLiked`.

---

## Still guarantee

1. Set `product = ObjectId(path.productId)` on product like (never null).
2. Product-like uniqueness = `(user, product)`; collection-like may use
   `(user, collectionId)` only for whole-collection likes.
3. Idempotent → `200` + `alreadyLiked: true`.
4. Cleanup bad `catalog_like` rows with only `collectionId` / missing `product`.
5. Authed GET product returns per-product `liked` (see [01](./01-authed-product-liked-wishlisted.md)).

---

## Verify

Like 2+ different photos in the same multi-product collection — both succeed,
no E11000.

---

## Acceptance

- [ ] Second product like in same collection → 200 (not 409 on collection index)
- [ ] Idempotent already → `alreadyLiked: true`
- [ ] GET product `liked` is per-product
