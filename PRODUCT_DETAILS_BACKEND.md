# Backend handoff — product details (jewel collections)

> BE gaps folder: [`docs/BE gaps/`](./docs/BE%20gaps/README.md) (see 03, 04, 11–13).

Observed against `api.bullionare.com` while opening a multi-photo collection
from the store grid (`listingId` = collection id).

**Verify (debug):** filter `BeVerify` — see `BE_VERIFY.md` scenarios B, D, I.

---

## 1. `GET /products/:id` with a collection id → 404

### Observed
```http
GET /v1/catalog/products/6ad899d79a6e0514bf0e8c56
→ 404 {"error":{"message":"PRODUCT_NOT_FOUND"}}
```

Same id succeeds as a collection:
```http
GET /v1/catalog/stores/:storeId/collections/6ad899d79a6e0514bf0e8c56
→ 200  (embeds products[] with real product ids …8c59 / …8c5a / …8c58)
```

### FE behavior
Treats `PRODUCT_NOT_FOUND` as “not a product id” and loads collection detail.
This is correct for collection cards; no FE change needed beyond that fallback.

### Backend ask (optional)
If product GET is ever meant to accept collection ids, document it. Otherwise
keep 404 — FE already falls back.

---

## 2. Availability PATCH must use **product** ids

### Observed (broken before FE fix)
```http
PATCH /v1/catalog/products/6ad899d79a6e0514bf0e8c56
body: {"stock_status":"out","is_locked":false}
→ 404 PRODUCT_NOT_FOUND
```

`:productId` was the **collection** id from `StoreProduct.id`.

### FE fix (shipped)
Availability now PATCHes every embedded CatalogProduct id from collection
detail (`products[]._id` / photo asset ids that are not `img_*`), then
updates local stock/lock chrome from the response, pops `{updated: true}` to
the store profile, and on reopen prefers `products[].is_locked` /
`stock_status` when collection-level fields lag (observed: products locked
while collection `is_locked` stayed `false`).

### Backend ask
1. Confirm PATCH `/products/:productId` is the only write path for stock/lock.
2. Prefer also updating collection-level `stock_status` / `is_locked` /
   `mto_days` on collection GET when any child product changes (or expose
   `PATCH …/collections/:id` that fans out).
3. For `kind: sub_collection`, keep “PATCH one product → sync all photos”
   as documented.

---

## 3. Specs shape: `defaults` + flat product fields (not nested `specifications`)

### Observed collection payload
```json
{
  "defaults": { "metal": "gold", "purity": "92", "wastage_pct": null },
  "products": [
    {
      "metal": "gold",
      "purity": "92",
      "gross_min": 50,
      "gross_max": 50,
      "wastage_pct": null,
      "size_mode": "free",
      ...
    }
  ]
}
```

No nested `specifications.weight` / `purity` / `wastage` object.

### FE fix (shipped)
- Parse `defaults` → group fallback spec.
- Parse each `products[]` → per-id `ProductSpec` for details chrome + edit hydrate.
- Null `wastage_pct` → show Gross (Fine needs numeric wastage).

### Backend ask
- Persist / return `wastage_pct` when merchants set wastage (Fine line).
- Keep flat product fields stable on collection detail + product GET.
- Thumbhash on every product image (collection GET still logs
  `GAP_THUMBHASH_NULL` on some list paths — see main `BACKEND_HANDOFF.md` §2).

---

## 4. Quick checklist for BE

| Item | Status needed |
|------|----------------|
| PATCH stock/lock on real product `_id` | Working path FE uses now |
| Collection-level stock after child PATCH | Nice-to-have consistency |
| Non-null `wastage_pct` when weight set | Improves Fine chrome |
| Thumbhash on product images | Cold-start placeholders |
| Authed `liked` / `wishlisted` on product GET | See `BACKEND_HANDOFF.md` §1 |
