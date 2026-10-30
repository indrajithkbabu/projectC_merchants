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
│ 2. 90% Mobile Data Savings: Grid thumbnails download ~15KB (not 2MB!). │
│ 3. Instant Previews: 28-char ThumbHash renders in < 1ms on-device.     │
│ 4. Native AVIF / WebP: Cloudflare automatically negotiates best format.│
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. The 3-Step Lifecycle

### Step 1: Request Presigned Upload URLs
Call `POST /v1/catalog/uploads/sign` (or `/v1/catalog/stores/:storeId/uploads/sign`).

Strict MIME whitelist: `image/webp`, `image/jpeg`, `image/png`.

### Step 2: Binary Upload Directly to Cloudflare R2
`PUT` to `presignedUrl` with the exact `Content-Type` from sign. No `Authorization` on R2.

### Step 3: Phase 2 Commit
`POST /v1/catalog/stores/:storeId/products/batch` with `image_id` + metadata (JSON only).

---

## 3. Display URLs (prod — ticket #14)

| Field | Role | Example shape |
| :--- | :--- | :--- |
| `thumbnailUrl` | Grid / feed (low) | `https://media.catly.in/cdn-cgi/image/width=240,height=240,fit=cover,quality=40,format=auto/catalog/products/…/img_….webp` |
| `detailUrl` | Product detail (medium) | `https://media.catly.in/cdn-cgi/image/width=720,fit=scale-down,quality=70,format=auto/catalog/products/…/img_….webp` |
| `url` | Pinch-zoom master (high) | `https://media.catly.in/catalog/products/…/img_….webp` |
| `thumbhash` | Instant placeholder | ~28-char base64 |

Notes: Cloudflare uses `fit=scale-down` (not Sharp `fit=inside`). FE binds BE fields only (no CDN synth). Collection list/detail `cover` inherits `thumbhash`, `thumbnailUrl`, `detailUrl`, and `url` from the primary product photo.

---

## 4. Frontend checklist

1. Compress on-device: max edge **1080** WebP @ 85% + ThumbHash from the
   compressed master (native resize; no full 2K/4K Dart decode).
2. Sign → PUT → `products/batch` (do not send binaries through Node).
3. Grid → `thumbnailUrl`; detail → `detailUrl`; zoom → `url`.
4. Never bind master `url` on feed grids.
