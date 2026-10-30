# 03 — Owner stock / lock PATCH

**Status:** Confirm  
**Index:** [README.md](./README.md)

---

## Ask

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

Return the updated product document (same shape as GET).

**Important:** Collection listing ids are **not** product ids.

- `GET /products/:collectionId` → `404 PRODUCT_NOT_FOUND` (expected).
- FE Availability PATCHes each embedded `products[]._id` from collection detail.
- Observed: collection GET may keep `is_locked: false` while every `products[]`
  row is locked. Prefer refreshing collection-level `stock_status` / `is_locked`
  / `mto_days` after child changes, **or** document a collection-level fan-out PATCH.
- For `kind: sub_collection`, keep “PATCH one product → sync all photos”.

---

## FE today

Owner Availability UI live; patches product ids only; ORs product locks for
listing chrome; pops `{updated: true}` to store grid.

---

## Acceptance

- [ ] PATCH on real product `_id` returns updated product
- [ ] Collection GET reflects child lock/stock, or fan-out is documented
- [ ] `sub_collection` photo sync still works
