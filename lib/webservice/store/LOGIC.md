# Store webservice logic

## Endpoints
- `GET /home` (cursor pagination, optional bearer for relationship)
- `GET /store-slugs/:slug/availability`
- `POST /stores` `{name, slug}`
- `POST /stores/:id/contacts` `{phones}` batches ≤30
- `PATCH /stores/:id/privacy` `{privacy: public|private}` — store-wide
  visibility; response may include `autoApprovedFollowers` when going public
- `POST|DELETE /stores/:id/follow` — follow / request / unfollow / cancel request
- `PATCH /stores/:id/follow` `{ notifyUploads: bool }` — mute/unmute upload
  push for an active follow (bell on visitor follow chrome). Client must
  `PATCH notifyUploads: true` when follow becomes **active** (and when a
  pending request flips to following) — UI bell ON alone does not enable
  `new_upload` pushes.
- Members list/remove, leave store, rename

## Notes
- After create, refresh `/me` so `ownStore` is current, then invalidate +
  re-prefetch `StoreHomePrefetcher` so the Stores tab shows the new store
  without a manual pull-to-refresh.
- Contact batch failures must not undo store creation.
- Team screen submits selected demo contact phones (device picker can replace later).
- Privacy switch does not copy/move products; access is evaluated at read time
  from `privacy` + follow relationship (`canViewContent` when provided).
- Private visitor profiles: when `canViewContent` is false, do not fetch
  collections; show locked gate. Follow updates meta then loads products if
  access is granted.
- Follow POST/DELETE return `{status: active|pending|none}` — parse via
  `FollowActionResult`, not `CatalogStore.fromJson`.
- Owner follow requests: `GET .../follow-requests`, accept/reject under
  `.../follow-requests/:followerUserId/{accept|reject}`.
