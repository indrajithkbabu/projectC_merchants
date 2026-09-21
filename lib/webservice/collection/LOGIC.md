# Collection webservice logic

Catalog “collections” map to UI “products”:
- `name` → product title
- `tag` / `description` → sent on create/patch (API tag ≤40, description ≤1000)
- ordered photo URLs → `imagePaths` (network)
- member photo `id` → `photoAssetIds` / gallery `assetId`

## Create
`POST /stores/:storeId/collections` as **multipart/form-data**:
- fields: `name` (required), `tag`, `description`
- files: repeated `photos` (1–50, each ≤500 MB; batch ≤500 MB total)
- Client timeout up to 5 minutes
- **201** may include `failedPhotos` while still creating the collection
- **400 NO_VALID_PHOTOS** includes `error.failedPhotos`; no collection created

## Update (CATALOG_IMAGES.md)
- Metadata only: JSON `PATCH` `{revision, name?, tag?, description?}`
- Add photos: multipart `PATCH` same listing with `photos` + optional fields + `revision`
  (photos are **appended**)
- Remove photos: `POST .../photos/delete` `{photoIds, revision?}`
  (must keep ≥1 photo; otherwise delete the collection)
- Edit flow adds new locals first, then deletes removed ids, same listing id
- Sub-groups: `POST .../subgroups` to create; `PATCH .../subgroups/:subGroupId` to
  update name/tag/description/specs/`usePrecisionTag` (membership via photos/move)

## Other
- List/get/delete under `/stores/:storeId/collections`
- `REVISION_CONFLICT` when revision is stale
- Imported listings are read-only for edits
