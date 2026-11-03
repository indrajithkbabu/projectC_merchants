# JewelFlow Catalog: Cloudflare R2 & Responsive Image Frontend Integration Guide

This guide details the frontend integration for the **Cloudflare R2 Direct Upload Pipeline** and **Responsive Image Rendering** in the Bullionare Catalog subsystem (`/v1/catalog`).

> **Full end-to-end upload + render:**  
> [CATALOG_IMAGE_UPLOAD_AND_RENDER_E2E.md](./CATALOG_IMAGE_UPLOAD_AND_RENDER_E2E.md)

> FE binds by role via `CatalogResponsiveImage` / `StoreProduct.urlForRole`.
> Debug: Logcat filter `CatalogMediaDBG`.

---

## 1. Overview & Key Benefits for Mobile / Web Apps

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. Zero-Copy Upload: Commit response drops from 2,500ms down to < 30ms.│
│ 2. Mobile Data Savings: Grid thumbnails via edge resize (~12–16 KB).   │
│ 3. Instant Previews: 28-char ThumbHash renders in < 1ms on-device.     │
│ 4. Native AVIF / WebP: Prefer format=webp on CDN transforms.           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. The 3-Step Lifecycle

### Step 1: Request Presigned Upload URLs
Call `POST /v1/catalog/uploads/sign` (or `/v1/catalog/stores/:storeId/uploads/sign`).

Strict MIME whitelist: `image/webp`, `image/jpeg`, `image/png`.
`expiresIn` is typically **300** seconds.

### Step 2: Binary Upload Directly to Cloudflare R2
`PUT` to `presignedUrl` with the exact `Content-Type` from sign. No `Authorization` on R2.

### Step 3: Phase 2 Commit
`POST /v1/catalog/stores/:storeId/products/batch` with JSON body
`{ "products": [ { "image_id", "thumbhash", … } ], "batchId", "idempotencyKey" }`
(envelope is **`products[]`**, not a flat single object).

---

## 3. Display URLs (prod)

| Field | Role | Example shape |
| :--- | :--- | :--- |
| `thumbnailUrl` | Grid / feed (low) | `https://media.catly.in/cdn-cgi/image/width=360,height=360,fit=cover,quality=60,format=webp/catalog/products/…/img_….webp` |
| `detailUrl` | Product detail (medium) | `https://media.catly.in/cdn-cgi/image/width=1080,fit=scale-down,quality=75,format=webp/catalog/products/…/img_….webp` |
| `url` | Pinch-zoom master (high) | `https://media.catly.in/catalog/products/…/img_….webp` |
| `thumbhash` | Instant placeholder | ~28-char base64 |

Notes: Cloudflare uses `fit=scale-down` (not Sharp `fit=inside`). Prefer `format=webp` so Flutter clients get WebP without relying on `Accept` negotiation. FE binds BE fields only (no CDN synth). Collection list/detail **`cover`** inherits `thumbhash`, `thumbnailUrl`, `detailUrl`, and `url` from the primary product photo (FE readers prefer `cover`; legacy `coverImage` is soft-fallback only). Product feed prefers `primaryImage`, then `cover`.

---

## 4. Frontend checklist

1. Compress on-device: max edge **1080** WebP @ 85%, **`keepExif: false`**, + ThumbHash from the
   compressed master (native resize; no full 2K/4K Dart decode).
2. Overlap prepare with sign/PUT → `products/batch` (do not send binaries through Node).
3. Grid → `thumbnailUrl`; detail → `detailUrl`; zoom → `url`.
4. Never bind master `url` on feed grids (except session quality ladder after unlock).
5. Keep `ProductMediaImage` / `CatalogImageCache` (do not replace with a bare `CachedNetworkImage` sample).
6. Decode grids at **cell × dpr**; ThumbHash via shared LRU; seed local bytes after PUT.
