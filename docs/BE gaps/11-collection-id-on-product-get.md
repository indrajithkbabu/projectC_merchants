# 11 — Collection id on product GET

**Status:** Document  
**Index:** [README.md](./README.md)  
**Detail history:** root `PRODUCT_DETAILS_BACKEND.md`

---

## Behavior (by design)

```http
GET /v1/catalog/products/:collectionId
→ 404 PRODUCT_NOT_FOUND
```

Same id succeeds as:

```http
GET /v1/catalog/stores/:storeId/collections/:collectionId
→ 200  (embeds products[] with real product ids)
```

---

## FE today

Treats product 404 as “not a product id” and loads collection detail. Do not
treat as a transient error.

---

## Ask

Keep documenting this so clients do not mis-handle the 404.

---

## Acceptance

- [ ] API docs state collection ids are not product ids on `GET /products/:id`
- [ ] Collection detail continues to embed `products[]` with real ids
