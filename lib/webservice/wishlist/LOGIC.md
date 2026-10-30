# Wishlist webservice

User-scoped photo likes and wishlist (`/v1/catalog`).

| Method | Path | Notes |
|--------|------|--------|
| PUT | `/products/:listingId/photos/:photoId/like` | Like; creates wishlist row |
| DELETE | `/products/:listingId/photos/:photoId/like` | Unlike; removes wishlist row |
| PUT/DELETE | `/stores/:storeId/collections/:listingId/photos/:photoId/like` | Alias (used when `storeId` known) |
| POST | `/stores/:storeId/collections/:listingId/like` | Batch-like all photos in collection |
| DELETE | `/stores/:storeId/collections/:listingId/like` | Batch-unlike collection |
| POST/DELETE | `/stores/.../collections/:listingId/subgroups/:subGroupId/like` | Sub-collection scope |
| POST/DELETE | `/products/:listingId/like` | Global alias (`?subGroupId=` optional) |
| GET | `/wishlist?limit&cursor` | No `status` query (API rejects unknown fields) |
| DELETE | `/wishlist/:wishlistId` | Remove by wishlist document id |

Auth required on all calls. Locked stubs omit photo/title/specs — only store identity + followStatus.

Visitor store-profile multi-select **Wishlist** likes each selected photo in
parallel (`PUT …/photos/:photoId/like`), then re-fetches collection detail and
sets card `likeCount` from the API (deduped sum of photo `likeCount`). No
optimistic client counts. Wishlist-tab unlike decrements that listing’s cached
badge (`StoreProductsCache`); store quiet refresh also reapplies API counts
(including `likeCount` / `viewCount` in the visual-equality check).
Collection/sub-group like endpoints remain available for whole-collection actions.
