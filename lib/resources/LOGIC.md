# Resources

## endpoints.dart
Path constants relative to flavor catalog base URL (`…/v1/catalog`).
Prefer helpers for path parameters (`storeById`, `storeCollection`, …).
Do not duplicate the `/v1/catalog` prefix here.

Media (profile / store / collections):
- Profile: multipart `PATCH /me` + `POST|DELETE /me/profile-image`
- Store showcase: multipart create/append/replace + `DELETE .../images/:imageId` (max 5)
- Collections (preferred): `POST .../uploads/presign` (staging keys + `sessionId`)
  → client S3 PUT of compressed bytes → JSON
  `POST /stores/:storeId/collections` with `photos: [{key, thumbhash, …}]`,
  `clientRequestId`, and `Idempotency-Key` header
- Append photos: JSON `POST .../collections/:listingId/photos`
- Delete photos: `POST .../photos/delete` (preferred on mobile) or DELETE variants
- Legacy multipart create/PATCH append remains available for compatibility
