# Resources

## endpoints.dart
Path constants relative to flavor catalog base URL (`…/v1/catalog`).
Prefer helpers for path parameters (`storeById`, `storeCollection`, …).
Do not duplicate the `/v1/catalog` prefix here.

Media (CATALOG_IMAGES.md):
- Create: multipart `POST /stores/:storeId/collections` with `photos`
- Add photos / update: multipart `PATCH /stores/:storeId/collections/:listingId`
- Delete photos: `POST .../photos/delete` (preferred on mobile) or DELETE variants
- No separate `/uploads` S3 ticket flow in this contract
