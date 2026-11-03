# 14 — R2 responsive display URLs (read path)

**Status:** Done (BE verified on `media.catly.in`; FE prefers BE variants + aligned synth fallback)  
**Related FE guide:** Cloudflare R2 & Responsive Image Frontend Integration  
**Log filter (FE):** `CatalogMediaDBG`

---

## Do not change

Upload invariants stay untouched on both sides:

- `POST /uploads/sign` (imageId / key / presignedUrl)
- Direct **PUT** to Cloudflare R2
- `POST …/products/batch` schema + idempotency
- Stock / lock / like / wishlist / follow / import flows

---

## BE resolution (prod)

Per backend ticket #14 + R2 responsive guide:

| Gap | Fix |
|-----|-----|
| A / B | Display via `https://media.catly.in/…` with `/cdn-cgi/image/` thumb/detail; public GET **200** + edge cache (no Bearer) |
| C | Collection list/detail `cover` inherits `thumbhash`, `thumbnailUrl`, `detailUrl`, `url` from primary photo |

Example shapes:

```text
url          = https://media.catly.in/catalog/products/…/img_….webp
thumbnailUrl = https://media.catly.in/cdn-cgi/image/width=360,height=360,fit=cover,quality=60,format=webp/catalog/products/…/img_….webp
detailUrl    = https://media.catly.in/cdn-cgi/image/width=1080,fit=scale-down,quality=75,format=webp/catalog/products/…/img_….webp
```

Notes:

- Cloudflare rejects Sharp’s `fit=inside` → use **`fit=scale-down`** (same intent: fit within width, no upscale).
- Prefer **`format=webp`** (Flutter image fetches often omit `Accept: image/webp`; `format=auto` can fall back to larger JPEG).
- BE never copies master into `thumbnailUrl` / `detailUrl`.

---

## FE alignment (done)

- Role binding unchanged: grid → `thumbnailUrl`, detail → `detailUrl`, zoom → `url`
- Prefer BE variants when present (`source=be.*` in logs)
- **FE CDN synth disabled** — if BE omits a variant, paint master + GAP log (commented `synthesize` can be restored in `catalog_responsive_image.dart`)
- Image widgets use plain HTTPS GET (public media; no Bearer unless QA proves 401)
- Product feed: parse `primaryImage` and fall back to `cover` / `coverImage`
- QUALITY / ladder classify **only** thumb `width=360` and detail `width=1080`

---

## Device acceptance

Filter Logcat: `CatalogMediaDBG` and **`R2_QA`**

### Low (CDN / ladder) — filter `R2_QA` → `L1`
- [ ] Grid paint → `L1 PASS | role=grid … cdn=thumbnailUrl(360)` (or ladder)
- [ ] Detail paint → `L1 PASS | … cdn=detailUrl(1080)`
- [ ] Zoom / master → `cdn=master(url)`
- [ ] `[RENDER] URL role=grid source=be.thumbnailUrl` → `width=360` + `format=webp`
- [ ] `[RENDER] URL role=detail source=be.detailUrl` → `width=1080` + `format=webp`
- [ ] Missing BE variant → `source=fallback.master` + GAP (not `fe.synth`)
- [ ] Cold open store: InstantCatalogPhoto blur then thumbnail
- [ ] Product details pinch still uses master `url`

### Medium — filter `R2_QA` → `M1` / `M2` / `M3`
- [ ] Upload → `M1 PASS | presignRenew … defaultExpiresIn=300s` and/or `sign expiresIn=… renewAfter=…`
- [ ] Multi-photo publish → `M2 PASS | batchShape images[]=N image_id=… image_ids(legacy)=0`
- [ ] First catalog image paint → `M3 PASS | imageFetch Accept=image/webp…`
- [ ] `[STEP] 2 R2 PUT OK` then `[STEP] 3 BATCH` → `201`

---

## If paint ERROR returns

1. Confirm URL opens **without** auth in browser/`curl -I` → 200.  
2. If 401/403 without Bearer → FE must attach catalog token to media GETs (separate change).  
3. Do **not** change sign / PUT / batch for display-only failures.
