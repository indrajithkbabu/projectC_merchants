# 05 — Activity `product_liked`

**Status:** Confirm  
**Index:** [README.md](./README.md)

---

## Ask

Emit on **public like only**. Wishlist must **not** create activity or push.

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

FE opens own store with `focusProductId = entityId`.

---

## FE today

Parses full payload aliases (`entityId` / `productId` / `data.productId` /
`listingId`, `actor.image`).

---

## Acceptance

- [ ] Public like creates `product_liked` (in-app; zero push)
- [ ] Wishlist creates neither activity nor push
- [ ] `productId` / `entityId` present and match CatalogProduct id
