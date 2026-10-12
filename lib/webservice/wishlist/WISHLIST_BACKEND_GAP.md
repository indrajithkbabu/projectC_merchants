# Wishlist / Photo Like — Backend Gap (Blocker)

**Audience:** Catalog backend  
**Base path:** `/v1/catalog`  
**Priority:** Blocker for mobile wishlist (was)  
**Date observed:** 2026-10-07 (prod `api.bullionare.com`)  
**Update:** Backend contract in `CATALOG_PRIVACY_FOLLOW_WISHLIST_API` (modified) adds
`id`, `liked`, and `likeCount` on collection detail photos. Mobile resolves missing
ids via on-demand `GET …/collections/:listingId` before like/unlike.

---

## Summary

Mobile wishlist likes a **photo** (`photoId`), not a whole product.  
Like / unlike APIs exist on the client. Collection detail must return stable photo
**`id`** on `photos[]`, `mainGroupPhotos[]`, and `subGroups[].photos[]` (plus
optional `liked` / `likeCount` for the viewer).

---

## Client contract (from wishlist API)

| Action | Method + path |
|--------|----------------|
| Like | `PUT /products/:listingId/photos/:photoId/like` |
| Unlike | `DELETE /products/:listingId/photos/:photoId/like` |
| Alias | `PUT\|DELETE /stores/:storeId/collections/:listingId/photos/:photoId/like` |
| List wishlist | `GET /wishlist?limit=&cursor=&status=all\|active\|locked` |
| Remove by id | `DELETE /wishlist/:wishlistId` |

`listingId` = collection id (already available).  
`photoId` = **member photo / asset id** (missing today on GET collection).

---

## Gap (what is broken today)

### Endpoint

```http
GET /v1/catalog/stores/:storeId/collections/:listingId
Authorization: Bearer <accessToken>
```

### Observed response (prod) — photos have no `id`

```json
{
  "id": "6ac5e2c5c0143724f64e03af",
  "name": "ring",
  "photoCount": 2,
  "photos": [
    {
      "width": 1850,
      "height": 2560,
      "quality": "standard",
      "thumbhash": "yQcCBQAIOXN4CKend3R5WQh8ZpBn",
      "url": "https://d3239y96m2a1lo.cloudfront.net/catalog/collections/.../IMG-....jpg"
    },
    {
      "width": 1956,
      "height": 2560,
      "quality": "standard",
      "thumbhash": "xwcCBQAWKUFlCKmXmZRqOAR3VlBY",
      "url": "https://d3239y96m2a1lo.cloudfront.net/catalog/collections/.../IMG-....jpg"
    }
  ],
  "mainGroupPhotos": [ /* same shape — also no id */ ],
  "subGroups": []
}
```

Same missing `id` on `mainGroupPhotos[]` and `subGroups[].photos[]`.

### Mobile impact

1. Client maps `photos[].id` → `photoAssetIds[]`.
2. Heart tap needs non-empty `photoId`.
3. With empty `id`, client **does not** call like (no `PUT …/like` in logs).
4. User sees: *“Photo is still loading. Try again in a moment.”* (misleading; photos loaded, ids missing).

Delete-photo and other flows that send `photoIds` are also at risk when ids are absent.

---

## Required fix

### 1) Always return photo `id` on read

On **every** photo object in:

- `GET /stores/:storeId/collections/:listingId` → `photos`, `mainGroupPhotos`, `subGroups[].photos`
- Prefer also on list covers if a cover is likeable later: `GET /stores/:storeId/collections` → `cover.id` / `mainGroupCover.id`

**Required field**

| Field | Type | Notes |
|-------|------|--------|
| `id` | string (non-empty) | Stable asset/photo id used as `:photoId` in like URLs |

**Recommended optional fields (wishlist UX)**

| Field | Type | Notes |
|-------|------|--------|
| `liked` | boolean | Whether the **current viewer** has liked this photo |
| `likeCount` | number | Aggregate count (owner tiles / chrome) |

### 2) Expected shape (minimal)

```json
{
  "id": "6ac5e2c5c0143724f64e03af",
  "name": "ring",
  "photos": [
    {
      "id": "6ac454820c1bff7f98483eb1",
      "width": 1850,
      "height": 2560,
      "quality": "standard",
      "thumbhash": "yQcCBQAIOXN4CKend3R5WQh8ZpBn",
      "url": "https://d3239y96m2a1lo.cloudfront.net/...",
      "liked": false,
      "likeCount": 0
    }
  ],
  "mainGroupPhotos": [
    {
      "id": "6ac454820c1bff7f98483eb1",
      "width": 1850,
      "height": 2560,
      "url": "https://...",
      "liked": false,
      "likeCount": 0
    }
  ],
  "subGroups": []
}
```

`id` in `photos` / `mainGroupPhotos` / subgroup photos must be the **same** id accepted by:

```http
PUT /v1/catalog/products/:listingId/photos/:photoId/like
```

and the store/collections alias.

### 3) Like / unlike response (unchanged contract)

```json
{
  "liked": true,
  "assetId": "6ac454820c1bff7f98483eb1",
  "listingId": "6ac5e2c5c0143724f64e03af",
  "wishlistId": "6ac454820c1bff7f98483fcc"
}
```

`assetId` should equal the photo `id` returned on GET collection.

### 4) Wishlist list (sanity)

`GET /wishlist` items already document `assetId` + `listingId`. Those ids must match collection photo `id`s so open-from-wishlist and unlike stay consistent.

---

## Acceptance checklist (backend)

- [ ] `GET …/collections/:listingId` includes non-empty `id` on every photo in `photos`, `mainGroupPhotos`, and `subGroups[].photos`.
- [ ] Same photo always returns the same `id` across list/detail/wishlist.
- [ ] `PUT …/photos/:photoId/like` succeeds with that `id` (auth required).
- [ ] `DELETE …/photos/:photoId/like` removes the wishlist row.
- [ ] After like, `GET …/collections/:listingId` returns `"liked": true` for that viewer on that photo (recommended).
- [ ] Private-store / non-follower still get `403 STORE_PRIVATE` on collection when `canViewContent` is false (no change to privacy rules).
- [ ] Locked wishlist stubs remain sanitized (no photo url/title) when access is lost.

---

## Out of scope for this ask

- Activity feed APIs  
- Search privacy  
- Follow / privacy mode changes  

Only: **photo ids on collection reads** so wishlist like/unlike can run.

---

## Reproduce (quick)

1. Auth as user B (not store owner).  
2. `GET /stores/{storeId}/collections/{listingId}` for a public listing with photos.  
3. Confirm each `photos[i]` has `id`.  
4. `PUT /products/{listingId}/photos/{photoId}/like` → 200 with `liked: true`.  
5. `GET /wishlist` → item appears with matching `assetId`.

---

## Contact / FE note

Mobile already calls:

- `PUT|DELETE /products/:listingId/photos/:photoId/like` (or store/collections alias when `storeId` known)
- `GET /wishlist`, `DELETE /wishlist/:wishlistId`

No further FE change is required for the happy path once photo `id` (and ideally `liked`) are present on collection detail.
