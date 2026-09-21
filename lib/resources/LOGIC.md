# Resources

## endpoints.dart
Path constants relative to flavor catalog base URL (`…/v1/catalog`).
Prefer helpers for path parameters (`storeById`, `storeCollection`, …).
Do not duplicate the `/v1/catalog` prefix here.

Media (profile / store / collections):
- Profile: multipart `PATCH /me` + `POST|DELETE /me/profile-image`
- Store showcase: multipart create/append/replace + `DELETE .../images/:imageId` (max 5)
- Collections: multipart `POST /stores/:storeId/collections` with `photos` (up to 50 / 500 MB)
- Add photos: multipart `PATCH /stores/:storeId/collections/:listingId`
- Delete photos: `POST .../photos/delete` (preferred on mobile) or DELETE variants
- No separate `/uploads` S3 ticket flow in this contract
