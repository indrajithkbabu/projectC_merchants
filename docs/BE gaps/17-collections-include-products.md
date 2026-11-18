# 17 — One-call collections with embedded products (BE-2)

**Status:** Done (BE Option A shipped; FE consumes `include=products`)  
**Base:** `https://api.bullionare.com/v1/catalog`  
**Auth:** `Bearer <catalog_token>` (public stores: allow anonymous / allowAnonymousBearer)  
**Related:** Collection counter sync (gap 16), cover thumbhash (gap 15), liked/wishlisted (gap 01)

---

## 1. Scenario (what users hit)

1. User opens **Stores** → taps a store → **Store profile** paints.
2. Profile needs a **collage card per collection** (Group / Single / Gallery):
   - cover image
   - up to **9** product image URLs for the collage
   - per-cell **CatalogProduct ids** (like / wishlist / import)
   - import flags (`live` / `pending` / …) when viewing another store
3. Today FE must:
   - `GET /stores/:storeId/collections?limit=50` → N collection summaries
   - then **N ×** `GET /stores/:storeId/products?collectionId=:id&limit=9`
4. On a store with ~15 collections that is **1 + 15 product list GETs** every enrich (open / quiet refresh), plus decode work → slow profile, radio/battery burn, and jank after enrich lands.

**Goal:** One list call returns enough data to build every collage card. FE drops the N product GETs when embedded products are present.

---

## 2. Current FE workaround (do not keep forever)

```
GET /stores/:storeId/collections?limit=50
  → for each summary (concurrency 4):
       GET /stores/:storeId/products?collectionId=:collectionId&limit=9
       (fallback) GET /stores/:storeId/collections/:collectionId
```

FE maps `products[]` + summary → collage (cover-first image order, product ids on cells).

---

## 3. Requested API

### Option A (preferred) — opt-in include on existing list

```http
GET /v1/catalog/stores/:storeId/collections?include=products&productsLimit=9&limit=50
Authorization: Bearer <token>
```

| Query | Required | Notes |
|-------|----------|--------|
| `include` | yes for this feature | Support `products` (and existing cover fields). Comma-separated OK: `include=products` or `include=cover,products`. |
| `productsLimit` | no | Default **9**. Cap hard at **9** (or 12 max). Same semantics as today’s FE `limit=9` enrich. |
| `limit` / `cursor` | existing | Unchanged pagination of collections. |

**Without** `include=products`: keep today’s slim summary (backward compatible).

### Option B (acceptable) — always embed first N products

Same response shape as Option A, but products always present (still cap at 9). Prefer Option A so light clients stay cheap.

### Not requested

- Do **not** require FE to call `GET /collections/:id` for every card on profile open.
- Do **not** change browse/detail contracts except that list embeds a **prefix** of the same product rows browse would return.

---

## 4. Response shape (per collection item)

Keep existing collection summary fields. Add:

```json
{
  "id": "<collectionId>",
  "name": "...",
  "productCount": 24,
  "photoCount": 24,
  "liveProductCount": 22,
  "pendingProductCount": 2,
  "declinedProductCount": 0,
  "createdAt": "2026-…",
  "likeCount": 3,
  "viewCount": 10,
  "cover": {
    "id": "img_…",
    "url": "https://…",
    "thumbnailUrl": "https://…",
    "detailUrl": "https://…",
    "thumbhash": "<base64 or null>",
    "width": 1200,
    "height": 1600
  },
  "products": [
    {
      "_id": "<catalogProductId>",
      "id": "<catalogProductId>",
      "collectionId": "<collectionId>",
      "kind": "single",
      "title": "...",
      "primaryImage": {
        "id": "img_…",
        "url": "…",
        "thumbnailUrl": "…",
        "detailUrl": "…",
        "thumbhash": "…"
      },
      "cover": {
        "id": "img_…",
        "url": "…",
        "thumbnailUrl": "…",
        "detailUrl": "…",
        "thumbhash": "…"
      },
      "images": [],
      "liked": false,
      "wishlisted": false,
      "likeCount": 1,
      "viewCount": 2,
      "is_locked": false,
      "stock_status": "in_stock",
      "importStatus": "live",
      "canImport": true,
      "isAlreadyImported": false,
      "importRestrictionReason": null
    }
  ]
}
```

### Product row rules (critical)

1. **Same identity & visibility** as `GET /stores/:storeId/products?collectionId=:id&limit=9` (owner vs visitor rules from gap 16).
2. Order: **newest-first** (same as products list / FE collage seed).
3. Length: `min(productsLimit, visible productCount)` — never invent empties.
4. Each product must expose a stable **CatalogProduct id** (`_id` / `id`) — collage cells like/wishlist/import that id, **not** the collection id.
5. At least one displayable image URL per product (`primaryImage` / `cover` / `images`).
6. Authed viewer: include `liked` + `wishlisted` when known (gap 01).
7. Cross-store import enrichment: prefer `importStatus` / `canImport` / `isAlreadyImported` / `importRestrictionReason` on each product (so FE can drop `/import-targets` probes).
8. **Visitor:** never embed `pending` / `declined` / `sourceDeleted` products; counters match gap 16.
9. **Owner:** embed the same set the owner products list would return (including pending when applicable); `productCount` must stay consistent with that list length semantics from gap 16.

### Cover

- `cover` must remain populated (gap 15: `thumbhash` when available).
- Prefer cover URL matching the first collage-eligible product image when possible (FE already cover-first sorts).

---

## 5. Consistency invariants

For a given viewer identity:

```
len(products) <= productsLimit
len(products) <= productCount   // for that viewer’s productCount semantics
```

If `productCount > productsLimit`, FE will still call  
`GET …/products?collectionId=` (or browse) for the **remainder** only — not for the first page used on the profile grid.

If `products` is **missing or empty** but `productCount > 0`, FE may fall back to today’s N+1 (legacy). Once this ships, that path should be rare.

---

## 6. Why this matters (numbers)

| Path | Today (≈15 collections) | After BE-2 |
|------|-------------------------|------------|
| Open store profile enrich | 1 collections + ~15 products lists | **1** collections (`include=products`) |
| Quiet refresh (TTL window) | same storm if forced | still **1** |
| Group / Single / Gallery | all need collage urls + product ids | unchanged UX; same payload |

This unblocks FE optimisation **API-2 / BE-2**: shared prefetcher can map list → cards with **zero** per-collection product GETs when `products[]` is present.

---

## 7. Acceptance checklist (BE)

- [ ] `GET …/collections?include=products&productsLimit=9` returns `products[]` per item.
- [ ] Omitting `include=products` keeps slim payload (Option A).
- [ ] Product rows match `GET …/products?collectionId=` (order, visibility, ids).
- [ ] Owner vs visitor filtering matches gap 16 (no privacy leak of pending/declined).
- [ ] Cap respected (`productsLimit`, hard max ≤ 12).
- [ ] Authed: `liked` / `wishlisted` on embedded products when available.
- [ ] Cover + thumbhash still present on list items.
- [ ] Documented in API docs (query params + example JSON).
- [ ] Load test: store with 50 collections, include=products, productsLimit=9 — p95 acceptable vs N separate product list calls.

---

## 8. Out of scope (FE will handle separately)

These are **not** required for this ticket:

- Collection **browse** seeding from profile (FE; may still page products when `productCount > seeded.length`).
- ~~Product **details** swipe TTL / skip GET when seed is complete (FE).~~ Done for browse jewel feed (`seedCatalog`).
- View beacon: FE will send `type: "collection"` with **collection id** (not product id). Confirm beacon accepts that; no schema change expected if already documented.
- Scroll `clearMode` jank (pure FE).

---

## 9. Suggested FE follow-up (after BE ships)

1. Parse optional `products` on collection summary JSON.
2. If `products.isNotEmpty` → map to collage card and **skip** `listStoreProducts` for that id.
3. If missing/empty and `productCount > 0` → keep legacy enrich.
4. Mark BE-2 DONE; remove N+1 from happy path.

---

## 10. Please reply with

1. Chosen option (A `include=` vs B always-embed).
2. Exact query param names.
3. Sample JSON for one collection with 3 embedded products (owner + visitor).
4. Deploy env + date so FE can flip the consumer.
