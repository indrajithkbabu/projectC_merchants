# Import webservice logic

## Flow
1. `GET /import-targets?listingId=` (follow all `nextCursor` pages) before counting destinations
2. Zero requestable targets → prompt user to join/create a store (or already added/pending)
3. One requestable → auto destination; many → UI selection (disable `alreadyAdded` / `pending`)
4. `POST /import-requests` with `destinationStoreId` (omit only when API allows a single membership)
5. Source-store members decide via `POST /import-requests/:id/decision`
6. Clients poll lists (`incoming` / `outgoing`); no push in v1

## Conflicts
Already added, pending, cooldown, destination required — user-friendly via `CatalogErrorMapper`.
