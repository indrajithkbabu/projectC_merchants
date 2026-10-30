# Frontend gaps (vs catalog API docs + upload UI)

## Fixed (latest pass — products / likes / stores docs)

1. **Activity `product_liked`** — parses `actor.image`, `title`/`message`,
   `entityId` from `entityId` | `productId` | `data.productId` | `listingId`;
   tap still opens own store with `focusProductId`
2. **Like / wishlist idempotent flags** — `alreadyLiked`, `alreadyWishlisted`
3. **Wishlist add aliases** — path POST → body `POST /wishlist` → photos /
   collection aliases; duplicate `409` (non–`product:null`) treated as already
   bookmarked
4. **Product / collection like** — PUT primary with POST fallback
5. **Collection like response** — `collectionId`, `likeCount`, `likeId`

## Fixed (prior passes)

- liked / wishlisted hydrate + WishlistPrefetcher fallback
- Thumbhash merge after batch; Owner Availability; wastage-markup UI
- Wishlist remove = private APIs; collection wishlist rows
- Product DELETE + `kind` + durable batch Idempotency-Key
- Post-upload leave (no double-pop); search filters; locked UX
- Import stub 404 / “disabled” → empty list

## FE wired (latest — bulk wishlist)

- Multi-select wishlist → `POST /wishlist/batch` (`VisitorWishlistBatch` /
  `WishlistRepository.addWishlistProductsBatch`); parallel single POSTs if
  batch `404`
- `DELETE /wishlist/batch` on repository (wishlist screen still one-item
  remove)
- Models: `WishlistBatchAddResult` / `WishlistBatchRemoveResult`

## Waiting on backend only

Canonical list: **`docs/BE gaps/`** (one MD per case; index in README).

BE claims like-index + wishlist batch fixed — **verify** with `BE_VERIFY.md`
(`BeVerify`). Confirm before removing FE fallbacks:

| Gap | FE fallback | Verify |
|-----|-------------|--------|
| Authed product GET always has `liked`/`wishlisted` | Wishlist cache for bookmark | Scenario A |
| Thumbhash persisted after batch | Local merge after upload | Scenario C |
| Import stubs 200 empty on all envs | 404 treated as empty | Scenario G |
| Wishlist path sets `product` (not null) | Body alias `POST /wishlist` | Scenario H |
| Like 2+ products in same collection | Surfaces `409` if index still wrong | Like twice in one collection |
| Doc: store GET `followStatus: active` vs `following` | FE maps both → following | — |

## Optional polish

- Upload progress rings on store profile
- Collection card social controls
