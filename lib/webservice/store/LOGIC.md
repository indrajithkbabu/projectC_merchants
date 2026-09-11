# Store webservice logic

## Endpoints
- `GET /home` (cursor pagination, optional bearer for relationship)
- `GET /store-slugs/:slug/availability`
- `POST /stores` `{name, slug}`
- `POST /stores/:id/contacts` `{phones}` batches ≤30
- Members list/remove, leave store, rename

## Notes
- After create, refresh `/me` so `ownStore` is current.
- Contact batch failures must not undo store creation.
- Team screen submits selected demo contact phones (device picker can replace later).
