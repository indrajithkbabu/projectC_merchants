# Catalog Images: Upload → Backend → Render (End to End)

How product photos are prepared on device, uploaded, committed, and shown in the app — including what the backend returns and what the frontend does with that data.

Debug Logcat filter: **`CatalogMediaDBG`**

---

## 1. Summary

When product photos are added, the phone shrinks them first (a 4K camera shot becomes a WebP with long edge ≤ 1080). The app asks the backend for temporary upload links, sends the small files straight to Cloudflare R2 (binaries do not go through the API), then commits with JSON only (`image_id` + metadata + ThumbHash).

On browse, the backend returns three display URLs (grid / detail / zoom) plus a ThumbHash blur string. The app picks the right URL per screen so the feed stays light and zoom stays sharp.

| Goal | How |
| :--- | :--- |
| Fast create with many 2K/4K photos | On-device compress; prepare up to 3 at a time |
| Save data on browse | Grid uses `thumbnailUrl`, not master |
| Instant preview | ThumbHash blur before the network image arrives |
| Keep API light | Binaries → R2; API signs + commits JSON |
| Correct portrait/landscape | EXIF orientation before resize |

**Measured (Redmi Note 10 Pro Max, ~4K JPEGs):** 14 photos prepare ≈ **4.5s**; 1 photo ≈ **1.2s**. Sign + PUT + batch add network time on top.

---

## 2. Big picture

```text
┌──────────────┐     ┌─────────────────┐     ┌────────────┐     ┌──────────────┐
│ Phone gallery│────▶│ FE prepare      │────▶│ BE sign    │────▶│ Cloudflare R2│
│ 2K/4K JPEG   │     │ compress+hash   │     │ URLs+ids   │     │ PUT WebP     │
└──────────────┘     └─────────────────┘     └────────────┘     └──────┬───────┘
                                                                       │
                                                                       ▼
┌──────────────┐     ┌─────────────────┐     ┌────────────┐     ┌──────────────┐
│ Store UI     │◀────│ FE pick URL     │◀────│ BE product │◀────│ BE batch     │
│ grid/detail/ │     │ by screen role  │     │ JSON+URLs  │     │ commit JSON  │
│ zoom + blur  │     │ + ThumbHash     │     │            │     │              │
└──────────────┘     └─────────────────┘     └────────────┘     └──────────────┘
```

1. **Write path** — prepare → sign → PUT → batch commit.  
2. **Read path** — list/get products → choose CDN URL by role → paint (+ ThumbHash).

---

## 3. Write path (upload)

### 3.1 UI entry

User picks photos in the create flow (title / specs / group). Frontend prepares files on device, then runs sign → R2 PUT → products batch commit.

---

### 3.2 On-device prepare (FE only — no BE yet)

The original 4–6 MB camera file is **not** uploaded. A smaller, correctly rotated WebP is.

For each local photo (up to **3 in parallel**):

| Step | What happens | Typical time |
| :--- | :--- | :--- |
| **Probe** | Read first ~256KB of the JPEG; parse size + **EXIF orientation** | ~30–100 ms |
| **Target size** | Fit so **long edge ≤ 1080** (e.g. 2252×4000 → **608×1080**) | instant |
| **Compress** | Native compress → **WebP quality 85**, EXIF rotation applied | ~0.5–0.9 s |
| **ThumbHash** | Native shrink of that WebP to ~100px → ~28-char Base64 string | ~40–90 ms |

**EXIF** = metadata in the photo. Orientation says which way is “up” (phones often store the bitmap sideways and tag rotation).

**Probe** = quick header read for size + orientation. It does not load the full 5 MB file just to measure it (that older path was ~2–3 s/photo; now ~0.1 s).

Device example:

```text
sourceBytes ≈ 4.8 MB JPEG
oriented 2252x4000 exif=6 → target 608x1080
compress outBytes ≈ 139 KB WebP
thumbhash=YES (len=28)
prepare total ≈ 1.2 s (1 photo)
```

Prepare output (held until PUT):

- `bytes` — compressed WebP  
- `width` / `height`  
- `thumbhash`  
- `originalName` (`.webp`)  
- `contentType` = `image/webp`

Defaults: max edge **1080**, WebP quality **85**, prepare concurrency **3**, ThumbHash from a native ~100px preview of the compressed master.

---

### 3.3 Sign — BE upload slots

**Request (FE → BE)**  
`POST /v1/catalog/uploads/sign` (or store-scoped alias)

File descriptors only — **no image bytes**:

```json
{
  "files": [
    { "filename": "IMG_….webp", "contentType": "image/webp" }
  ]
}
```

**Response (BE → FE)** — one slot per file:

| Field | Meaning |
| :--- | :--- |
| `sessionId` | Upload session |
| `imageId` | Id used later in batch (`img_…`) |
| `key` | R2 object key |
| `presignedUrl` | Time-limited URL for **PUT** (~900s) |
| `url` | Public **master** display URL |
| `thumbnailUrl` | Public **grid** variant URL |
| `detailUrl` | Public **detail** variant URL |
| `contentType` | Must match PUT header |
| `expiresIn` | Seconds until presign expires |

BE does not receive the photo yet. It reserves storage and returns a temporary upload link plus future public links. FE attaches these fields to each prepared photo.

---

### 3.4 Direct PUT to Cloudflare R2 (FE → R2)

Up to **3 concurrent** PUTs:

- `PUT` exact compressed WebP bytes to `presignedUrl`
- `Content-Type` from sign (usually `image/webp`)
- No catalog Bearer token on R2
- Silent retries 2s / 4s / 8s; renew if expired / 403

Bytes go phone → Cloudflare, not phone → API → Cloudflare.

---

### 3.5 Batch commit — FE → BE

**Request**  
`POST /v1/catalog/stores/:storeId/products/batch`  
Header: `Idempotency-Key` (pending upload id)  
Body: **JSON only**

```json
{
  "image_id": "img_…",
  "thumbhash": "<base64>",
  "title": "Chain",
  "stockStatus": "…",
  "specifications": { },
  "imageKey": "catalog/products/…/img_….webp",
  "width": 608,
  "height": 1080,
  "bytes": 138600
}
```

**Response** — typically **201**:

- Created `products[]` with ids  
- Primary image: `url`, `thumbnailUrl`, `detailUrl`, `thumbhash` (when persisted)  
- Optional collection / listing binding  

FE merges server fields with local sign/prepare data when a field is missing (current session only).

Legacy multipart create is fallback only if sign has no `imageId`.

---

### 3.6 Write path — BE vs FE

| Step | BE gives | FE does |
| :--- | :--- | :--- |
| Before any API | — | Probe EXIF, compress ≤1080 WebP, build ThumbHash |
| Sign | `imageId`, `key`, `presignedUrl`, `url` / `thumbnailUrl` / `detailUrl` | Call sign; attach slots |
| PUT | (R2 stores object) | Upload compressed bytes to `presignedUrl` |
| Batch | Product/collection records + image fields | Send `image_id` + specs + thumbhash; bind listing; refresh store |

---

## 4. Read path (render)

### 4.1 Fields on each image (list / get / batch)

| Field | Use | Typical shape |
| :--- | :--- | :--- |
| `thumbnailUrl` | Small / grid | `…/cdn-cgi/image/width=240,height=240,fit=cover,quality=40,…/img_….webp` |
| `detailUrl` | Medium / detail | `…/cdn-cgi/image/width=720,fit=scale-down,quality=70,…/img_….webp` |
| `url` | Master / zoom | `…/catalog/products/…/img_….webp` (no `width=`) |
| `thumbhash` | Instant blur | ~28-char Base64 |

Host: **`media.catly.in`**. Public GET (no Bearer) for paint.

Mapped on the product model:

| FE field | From BE |
| :--- | :--- |
| Master image list | `url` |
| Thumbnail list | `thumbnailUrl` |
| Detail list | `detailUrl` |
| ThumbHash list | `thumbhash` |

---

### 4.2 URL by screen role

| Role | BE field | Where used |
| :--- | :--- | :--- |
| **grid** | `thumbnailUrl` | Group mosaics, Media/Gallery 6–9 cols, small collage cells |
| **detail** | `detailUrl` | Single view, Media 2–5 cols, medium collage cells |
| **zoom** | `url` | Pinch / full-screen / large hero cells |

FE binds **BE fields only**. If thumb/detail is missing → fall back to master + log `[GAP]` (frontend does not invent CDN URLs).

Same photo, three links: feed = small, open/zoom = larger.

---

### 4.3 Collage / Media rules

**Group / Single collage:**

- 1 photo → zoom (master)  
- 2 photos → detail  
- 3–4 → hero zoom, smaller cells grid  
- 5–9 → detail / grid by row layout  

**Media / Gallery columns:**

- 6–9 cols → grid  
- 2–5 cols → detail  
- Product-details pinch still uses master for deep zoom  

---

### 4.4 ThumbHash on screen

1. UI gets `thumbhash` from product JSON.  
2. Decode locally → soft blur (ms).  
3. Load network image for the role URL.  
4. Replace blur when the frame is ready.

Logs: `paint placeholder` → `asyncFrame` / `syncFrame` / `reuseDecoded`.

---

### 4.5 Read path — BE vs FE

| BE gives | FE does |
| :--- | :--- |
| `thumbnailUrl`, `detailUrl`, `url`, `thumbhash` | Store on the product image lists |
| — | Pick URL by role (grid / detail / zoom) for the current screen |
| — | Show ThumbHash first, then paint CDN image |
| Missing variant | Fallback master + `[GAP]` log |

---

## 5. End-to-end example (1 photo)

1. User picks a phone JPEG (~4.8 MB, portrait, EXIF=6).  
2. FE probe → 2252×4000 oriented → target 608×1080.  
3. FE compress → ~139 KB WebP + ThumbHash.  
4. FE `POST /uploads/sign` → `img_…`, `presignedUrl`, three display URLs.  
5. FE `PUT` WebP to R2 → OK.  
6. FE `POST …/products/batch` with `image_id` + thumbhash + title → 201.  
7. Store has product with `thumbnailUrl` / `detailUrl` / `url` / `thumbhash`.  
8. Group grid → **grid** role → `thumbnailUrl` + ThumbHash placeholder.  
9. Details / pinch → **detail** or **zoom** as needed.

---

## 6. Prepare timing estimates

From **14 photos ≈ 4.5s** (concurrency 3, ~4K sources). Prepare only — not sign/PUT/batch.

| Photos | Prepare (approx.) |
| ---: | :--- |
| 1 | ~1–1.4 s |
| 5 | ~1.5–2 s |
| 10 | ~3–3.5 s |
| 14 | ~4.5 s (measured) |
| 20 | ~6–7 s |
| 40 | ~12–14 s |
| 50 | ~15–18 s |

Compress stays ~0.5–1 s per photo. Total prepare improved mainly from faster probe + ThumbHash and prepare×3.

2K and 4K both end as long-edge **1080** WebP (~100–190 KB typical). 4K only takes a bit longer to compress; upload size target is the same.

---

## 7. QA checklist

Filter: `CatalogMediaDBG`

**Upload**

- [ ] `oriented … → target …x1080`  
- [ ] `compress OK` / `listFallback=false`  
- [ ] `meta … path=nativePreview` + `thumbhash=YES`  
- [ ] `[STEP] 1 SIGN` → 200, `imageId` + thumb/detail/url  
- [ ] `[STEP] 2 R2 PUT OK`  
- [ ] `[STEP] 3 BATCH` → 201, `primaryThumbhashYES`  

**Render**

- [ ] `role=grid source=be.thumbnailUrl`  
- [ ] `role=detail source=be.detailUrl`  
- [ ] `role=zoom source=be.url`  
- [ ] Placeholder then frame (no `paint ERROR`)  
- [ ] Missing variant → `fallback.master` + `[GAP]`  

---

## 8. Known gaps

`[GAP]` when BE omits fields FE expects:

- Some list payloads: cover thumbhash null while primary image hash is present  
- Optimistic UI may paint master briefly before refresh fills thumb/detail  

Display-only fixes must not change sign / PUT / batch behavior.

---

## 9. Glossary

| Term | Meaning |
| :--- | :--- |
| **EXIF** | Photo metadata; orientation = which way is up |
| **Probe** | Header-only size + orientation read before compress |
| **WebP** | Uploaded format (q85, max edge 1080) |
| **ThumbHash** | Tiny Base64 blur placeholder |
| **Presigned URL** | Temporary R2 PUT link from BE |
| **imageId** | Links R2 object to product image |
| **Master `url`** | Full display file (zoom) |
| **thumbnailUrl / detailUrl** | CDN grid / detail variants |
| **Role** | grid / detail / zoom → which URL FE binds |
