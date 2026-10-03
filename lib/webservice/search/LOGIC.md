# Search webservice

Catalog search & filter HTTP layer.

## Ownership
- `search_request.dart` — calls `CatalogApiClient` with optional auth (`allowAnonymousBearer`).
- `search_repository.dart` — thin repository used by presentation routes.

## Endpoints
| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/search/meta` | Discover: trending, recent, category tiles |
| GET | `/search/suggest` | Typeahead (`storeId` + `slug` on product matches) |
| GET | `/search` | Global search + facets |
| GET | `/stores/:id/facets` | In-store summary chips |
| GET | `/stores/:id/search` | In-store search + facets |

Filter query params use singular keys (`category`, `metal`, …); backend also accepts plurals.

DTOs: `lib/models/catalog/search_models.dart`.

## Backend contract
Full API + Flutter navigation notes: [CATALOG_SEARCH_AND_FILTER.md](./CATALOG_SEARCH_AND_FILTER.md).

**Open product:** use hit `collectionId` as listing id with `store.id` / suggest `storeId` → `GET /stores/:storeId/collections/:collectionId` (200). Do not resolve via collection list.
