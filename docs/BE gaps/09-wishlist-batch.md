# 09 — Bulk wishlist batch

**Status:** Claimed fixed — verify (FE add wired)  
**Index:** [README.md](./README.md)

---

## Add

```http
POST /v1/catalog/wishlist/batch
```

```json
{ "productIds": ["66f…", "img_…", "66f…"] }
```

Max 100 ids. Also accepted on `POST /wishlist` with array body (compat).

Success (`200` / `201`):

```json
{
  "success": true,
  "totalRequested": 3,
  "addedCount": 2,
  "alreadyWishlistedCount": 1,
  "failedCount": 0,
  "items": [
    {
      "productId": "…",
      "wishlisted": true,
      "alreadyWishlisted": false,
      "wishlistId": "…"
    }
  ]
}
```

---

## Remove

```http
DELETE /v1/catalog/wishlist/batch
```

```json
{ "productIds": ["…", "img_…"] }
```

```json
{
  "success": true,
  "removedCount": 2,
  "productIds": ["…", "…"]
}
```

---

## FE today

Multi-select Wishlist → `POST /wishlist/batch` (`VisitorWishlistBatch`); on
batch `404` falls back to parallel single POSTs. `DELETE` batch is on the
repository; wishlist screen still removes one row via `DELETE /wishlist/:id`.

---

## Acceptance

- [ ] Batch add returns counts + `items[]`
- [ ] Batch remove returns `removedCount` + ids
- [ ] Max 100 enforced cleanly
