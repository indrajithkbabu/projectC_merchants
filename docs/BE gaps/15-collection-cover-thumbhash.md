# 15 — Collection list cover still missing `thumbhash`

**Status:** Blocker (re-open of Gap C from ticket #14)  
**Related:** R2 responsive display URLs / InstantCatalogPhoto  
**Log filter (FE):** `CatalogMediaDBG`  
**Environment:** Production (post–ticket #14 deploy)

---

## Do not change

Please **do not** change anything else that is already working:

- `POST /uploads/sign` / store-scoped sign
- Direct **PUT** to Cloudflare R2 (`presignedUrl`)
- `POST …/products/batch` schema, idempotency, or product `primaryImage` fields
- Media host / `cdn-cgi/image` URL shapes for product `url` / `thumbnailUrl` / `detailUrl`
- Stock / lock / like / wishlist / follow / import flows

**Only fix collection cover inheritance on list (and detail if the same code path).**

---

## Verified OK after #14 (no action)

From a live device run after the #14 deploy:

| Step | Result |
|------|--------|
| Sign → R2 PUT → `products/batch` `201` | OK |
| Product `primaryImage.thumbhash` | OK (`primaryHashYES=1`, FE merge `serverYES=1`) |
| Display host `api.bullionare.com` | OK (no more `r2.dev` paint ERROR) |
| Grid paint | OK (`paint asyncFrame` / `paint syncFrame`) |
| FE binds `role=grid source=be.thumbnailUrl` | OK |

---

## Gap — `GET …/collections` cover thumbhash still null

### Claimed in #14

> On `GET /stores/:storeId/collections` and `GET …/collections/:collectionId`, collections now inherit `thumbhash`, `thumbnailUrl`, and `detailUrl` from the primary product photo whenever a thumbhash was supplied.  
> Result: `coverThumbhashNULL=1` is eliminated.

### Observed after deploy (same session as a successful batch)

Immediately after batch create of a product that **has** `primaryImage.thumbhash`:

```text
[API] RESPONSE 201 …/products/batch
  primaryThumbYES=1 primaryDetailYES=1 primaryHashYES=1
  … thumbhash=YES(…)
  listItems=1 coverThumbhashYES=0 coverThumbhashNULL=1 GAP_THUMBHASH_NULL

[API] RESPONSE 200 …/stores/:storeId/collections
  listItems=1 coverThumbhashYES=0 coverThumbhashNULL=1 GAP_THUMBHASH_NULL
[GAP] API thumbhash missing in …/collections status=200
```

So:

- Product-level thumbhash on batch **works**
- Collection **list cover** still omits thumbhash (and FE still flags `GAP_THUMBHASH_NULL`)

Cold-start InstantCatalogPhoto on collection/group cards depends on `cover.thumbhash`. In-session product paint can still work from product payload / FE merge; list cover does not.

---

## Ask

On every collection row returned by:

```http
GET /v1/catalog/stores/:storeId/collections
```

and on collection detail cover:

```http
GET /v1/catalog/stores/:storeId/collections/:collectionId
```

set:

```json
{
  "cover": {
    "url": "…/v1/catalog/media/catalog/products/…/img_….webp",
    "thumbnailUrl": "…/v1/catalog/media/cdn-cgi/image/width=320,…/catalog/products/…/img_….webp",
    "detailUrl": "…/v1/catalog/media/cdn-cgi/image/width=1080,…/catalog/products/…/img_….webp",
    "thumbhash": "<same base64 as primary product image when client supplied one>"
  }
}
```

Inherit from the primary product photo whenever that photo has a non-empty `thumbhash` (and the responsive URL fields when available).

---

## Acceptance

- [ ] Right after `products/batch` that sent `thumbhash`, `GET …/collections` shows `cover.thumbhash` non-null for that listing
- [ ] FE log: `coverThumbhashYES=1` (no `coverThumbhashNULL=1` / `GAP_THUMBHASH_NULL` on collections list)
- [ ] Cold kill/reopen store: collection/group card shows InstantCatalogPhoto blur before the thumbnail loads
- [ ] No change to sign / PUT / batch product `primaryImage` behavior

---

## Minimal repro

1. `POST /uploads/sign` → PUT WebP → `POST …/products/batch` with `thumbhash` non-empty.  
2. Confirm batch response `primaryImage.thumbhash` is present.  
3. `GET /stores/:storeId/collections`.  
4. Inspect the new item’s `cover.thumbhash` — must be non-null and match the primary image hash.

---

## Optional confirm (not blocking paint)

FE short logs truncate paths. Please confirm full `cover.thumbnailUrl` / product `thumbnailUrl` contain:

`/v1/catalog/media/cdn-cgi/image/width=320…`

and are not identical to master `url`. Paint already works on `api.bullionare.com`; this is only to confirm resize variants are real.
