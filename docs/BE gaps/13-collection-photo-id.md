# 13 — Collection photo `id` on reads

**Status:** Confirm  
**Index:** [README.md](./README.md)  
**Detail history:** `lib/webservice/wishlist/WISHLIST_BACKEND_GAP.md`

---

## Ask

Every photo in `photos`, `mainGroupPhotos`, and `subGroups[].photos` on

```http
GET /stores/:storeId/collections/:listingId
```

must include a non-empty stable `id` (used as `:photoId` for legacy photo-like
and collage asset mapping). Recommended: `liked`, `likeCount` for the viewer.

Without `id`, FE cannot call photo-like and may show “Photo is still loading”.
Jewel path now prefers **product** like/wishlist on embedded CatalogProduct
ids; photo `id` remains required for asset mapping and legacy photo APIs.

---

## FE today

Resolves missing ids via on-demand collection GET before like when possible;
jewel collage prefers product `_id`.

---

## Acceptance

- [ ] Every photo object has non-empty stable `id`
- [ ] Same id across list / detail / wishlist `assetId`
- [ ] Optional `liked` / `likeCount` for viewer on those photos
