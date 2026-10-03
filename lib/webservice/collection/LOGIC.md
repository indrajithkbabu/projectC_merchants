# Collection webservice logic

Catalog “collections” map to UI “products”:
- `name` / `title` → product title
- `tag` / `description` → sent on create/patch (API tag ≤40, description ≤1000)
- ordered photo URLs → `imagePaths` (network)
- member photo `id` → `photoAssetIds` / gallery `assetId`
- photo `thumbhash` → `imageThumbhashes` (instant placeholders)

## Create (preferred — direct S3)
1. `POST /stores/:storeId/uploads/presign` with `files: [{filename, contentType}]`
   - Response includes `sessionId` + staging keys under `catalog/staging/...`
2. Client `PUT` **exact compressed** JPEG/WebP bytes to each `presignedUrl`
   (no Auth header; renew URL if >850s old or S3 returns 403)
3. `POST /stores/:storeId/collections` as **application/json** with
   `title`/`name`, optional `tag`/`description`/`specifications`/`usePrecisionTag`,
   `clientRequestId`, and
   `photos: [{key, thumbhash, width, height, bytes, originalName}]`
   - Also send header `Idempotency-Key: <clientRequestId>`
- Abandoned staging objects are purged by S3 lifecycle (~24h)
- **201** may still include `failedPhotos`
- Client timeout for commit ~2 minutes (S3 PUTs use their own timeouts)

## Append photos
`POST /stores/:storeId/collections/:listingId/photos` as JSON with
`photos: [{key, thumbhash, …}]` (+ optional `revision`)

## Legacy multipart (kept for compatibility)
`POST /stores/:storeId/collections` as **multipart/form-data**:
- fields: `name` (required), `tag`, `description`
- files: repeated `photos`
- Multipart PATCH append also remains available

## Update
- Metadata only: JSON `PATCH` `{revision, name?, tag?, description?}`
- Remove photos: `POST .../photos/delete` `{photoIds, revision?}`
  (must keep ≥1 photo; otherwise delete the collection)
- Edit flow adds new locals first (S3 + append), then deletes removed ids
- Sub-groups: `POST .../subgroups` to create; `PATCH .../subgroups/:subGroupId` to
  update name/tag/description/specs/`usePrecisionTag` (membership via photos/move)

## Other
- List/get/delete under `/stores/:storeId/collections`
- `REVISION_CONFLICT` when revision is stale
- Imported listings are read-only for edits
