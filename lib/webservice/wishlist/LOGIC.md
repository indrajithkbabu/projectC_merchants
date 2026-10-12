# Wishlist webservice

User-scoped photo likes and wishlist (`/v1/catalog`).

| Method | Path | Notes |
|--------|------|--------|
| PUT | `/products/:listingId/photos/:photoId/like` | Like; creates wishlist row |
| DELETE | `/products/:listingId/photos/:photoId/like` | Unlike; removes wishlist row |
| PUT/DELETE | `/stores/:storeId/collections/:listingId/photos/:photoId/like` | Alias (used when `storeId` known) |
| GET | `/wishlist?limit&cursor&status` | `status`: `all` \| `active` \| `locked` |
| DELETE | `/wishlist/:wishlistId` | Remove by wishlist document id |

Auth required on all calls. Locked stubs omit photo/title/specs — only store identity + followStatus.
