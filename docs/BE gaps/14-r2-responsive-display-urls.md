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

Per backend ticket #14 (confirmed):

| Gap | Fix |
|-----|-----|
| A / B | Display via `https://media.catly.in/…` with `/cdn-cgi/image/` thumb/detail; public GET **200** + edge cache (no Bearer) |
| C | Collection list/detail `cover` inherits `thumbhash`, `thumbnailUrl`, `detailUrl`, `url` from primary photo |

Example shapes:

```text
url          = https://media.catly.in/catalog/products/…/img_….webp
thumbnailUrl = https://media.catly.in/cdn-cgi/image/width=240,height=240,fit=cover,quality=40,format=auto/catalog/products/…/img_….webp
detailUrl    = https://media.catly.in/cdn-cgi/image/width=720,fit=scale-down,quality=70,format=auto/catalog/products/…/img_….webp
```

Notes:

- Cloudflare rejects Sharp’s `fit=inside` → use **`fit=scale-down`** (same intent: fit within width, no upscale).
- BE never copies master into `thumbnailUrl` / `detailUrl`.

---

## FE alignment (done)

- Role binding unchanged: grid → `thumbnailUrl`, detail → `detailUrl`, zoom → `url`
- Prefer BE variants when present (`source=be.*` in logs)
- **FE CDN synth disabled** — if BE omits a variant, paint master + GAP log (commented `synthesize` can be restored in `catalog_responsive_image.dart`)
- Image widgets use plain HTTPS GET (public media; no Bearer unless QA proves 401)

---

## Device acceptance

Filter Logcat: `CatalogMediaDBG`

- [ ] `[STEP] 2 R2 PUT OK` then `[STEP] 3 BATCH` → `201`
- [ ] `[RENDER] URL role=grid source=be.thumbnailUrl` → `cdn-cgi/image/width=240` + `quality=40`
- [ ] `[RENDER] URL role=detail source=be.detailUrl` → `width=720` + `fit=scale-down` + `quality=70`
- [ ] `[RENDER] URL role=zoom source=be.url` → master (no `width=`)
- [ ] `[QUALITY] CHECK` → `thumbnailUrl(240)` / `detailUrl(720)` / `master(url)` **PASS**
- [ ] Missing BE variant → `source=fallback.master` + GAP (not `fe.synth`)
- [ ] `paint asyncFrame` / `syncFrame` — **no** `paint ERROR`
- [ ] Cold open store: InstantCatalogPhoto blur then thumbnail
- [ ] Product details pinch still uses master `url`

---

## If paint ERROR returns

1. Confirm URL opens **without** auth in browser/`curl -I` → 200.  
2. If 401/403 without Bearer → FE must attach catalog token to media GETs (separate change).  
3. Do **not** change sign / PUT / batch for display-only failures.
