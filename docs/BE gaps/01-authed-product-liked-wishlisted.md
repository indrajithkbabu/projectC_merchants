# 01 — Authed product GET → `liked` + `wishlisted`

**Status:** Confirm  
**Index:** [README.md](./README.md)

---

## Ask

```http
GET /v1/catalog/products/:productId
Authorization: Bearer …
```

Always include for signed-in viewers:

```json
{
  "liked": true,
  "wishlisted": false
}
```

- `liked` — public appreciation for **this product** (not “any like in parent collection”)
- `wishlisted` — private bookmark for this viewer (**no** activity / push)

Omit only for fully anonymous requests.

---

## FE today

Warm `GET /wishlist` via `WishlistPrefetcher` when `wishlisted` is omitted.

---

## Acceptance

- [ ] Authed GET always returns both booleans for the path product id
- [ ] Anonymous omit is OK; signed-in omit is not
