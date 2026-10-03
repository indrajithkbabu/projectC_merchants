# JewelFlow Catalog Search & Filter API Documentation

This document covers the high-performance search and multi-select dynamic filtering engine for JewelFlow / Catalog (`/v1/catalog`). It is designed to match the 7-page "Jewel Flow Search & filter walkthrough" specification with sub-50ms latency at scale.

---

## Table of Contents

1. [Architecture & Performance](#1-architecture--performance)
2. [Endpoints Overview](#2-endpoints-overview)
3. [Pre-Search (Screen 01): `GET /v1/catalog/search/meta`](#3-pre-search-screen-01-get-v1catalogsearchmeta)
4. [Typeahead & Instant Suggestions (Screen 02): `GET /v1/catalog/search/suggest`](#4-typeahead--instant-suggestions-screen-02-get-v1catalogsearchsuggest)
5. [Global Search & Results Grid (Screens 03 & 04): `GET /v1/catalog/search`](#5-global-search--results-grid-screens-03--04-get-v1catalogsearch)
6. [In-Store Header Chips (Screen 05): `GET /v1/catalog/stores/:storeId/facets`](#6-in-store-header-chips-screen-05-get-v1catalogstoresstoreidfacets)
7. [In-Store Search & Results Grid (Screens 05 & 06): `GET /v1/catalog/stores/:storeId/search`](#7-in-store-search--results-grid-screens-05--06-get-v1catalogstoresstoreidsearch)
8. [Multi-Select & Sibling Filter Logic](#8-multi-select--sibling-filter-logic)
9. [Filter Bands Reference](#9-filter-bands-reference)
10. [Flutter / Dart Integration Guide](#10-flutter--dart-integration-guide)

---

## 1. Architecture & Performance

### 1.1 Read-Optimized Product Index (`catalog_productindex`)
Instead of performing complex `$lookups` across collections, listings, assets, and stores on every query, a flattened, read-optimized document collection (`CatalogProductIndex`) is maintained in MongoDB:
- Main collections and each individual sub-group variant article are indexed as independent searchable product records.
- Net weight, weight band, wastage band, size band, store name, city, and cover thumbnails are pre-computed upon write.
- Compound indexes ensure queries resolve in **< 30ms**:
  - Compound: `{ storeId: 1, category: 1, purity: 1, weightBand: 1 }`
  - Compound: `{ category: 1, metalType: 1, purity: 1, city: 1 }`
  - Sorts: `{ netWeight: 1, createdAt: -1 }`, `{ netWeight: -1, createdAt: -1 }`, `{ createdAt: -1 }`
  - Full-text search: `{ title: 'text', tag: 'text', category: 'text', storeName: 'text' }`

### 1.2 Zero-Lag Mutation Sync
The index automatically updates within the same database transaction during:
- Collection creation (`POST /v1/catalog/stores/:storeId/collections`)
- Collection updates & photo additions (`PATCH /v1/catalog/stores/:storeId/collections/:listingId`, `POST .../photos`)
- Photo deletions (`DELETE /v1/catalog/stores/:storeId/collections/:listingId/photos`)
- Sub-group variant creations, updates, deletions (`POST / PATCH / DELETE .../subgroups`)
- Photo transfers between main group and sub-groups (`POST .../photos/move`)
- Store name or city edits (`PATCH /v1/catalog/stores/:storeId`)
- Hard account deletion (`DELETE /v1/catalog/me`)

---

## 2. Endpoints Overview

| Screen | Endpoint | Method | Auth | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Screen 01** | `/v1/catalog/search/meta` | `GET` | Optional | Returns 6 standard category tiles with live counts, trending tags, and recent searches. |
| **Screen 02** | `/v1/catalog/search/suggest` | `GET` | Optional | Typeahead suggestions: Matching stores rank first (tagged `store`), then matching products (tagged `product`). |
| **Screen 03 & 04** | `/v1/catalog/search` | `GET` | Optional | Global search across all stores with 8 multi-select filters, dynamic sibling facet counts, sorting, and pagination. |
| **Screen 05** | `/v1/catalog/stores/:storeId/facets` | `GET` | Optional | "WHAT THIS STORE HAS" quick-filter chips for category, purity, and metal with live item counts. |
| **Screen 05 & 06** | `/v1/catalog/stores/:storeId/search` | `GET` | Optional | In-store search scoped strictly to `:storeId`. Dropped store/city fields. Displays `"X of Y items in this store"`. |

---

## 3. Pre-Search (Screen 01): `GET /v1/catalog/search/meta`

Fired when the user focuses or lands on the Search tab before typing a query.

### Request
```http
GET /v1/catalog/search/meta HTTP/1.1
Host: api.bullionare.com
Authorization: Bearer <ACCESS_TOKEN> (optional)
```

### Query Parameters
- `storeId` *(string, optional)*: If passed, returns category counts scoped to that specific store.

### Response `200 OK`
```json
{
  "trendingTags": [
    "bridal",
    "jhumka",
    "oxidised",
    "solitaire",
    "chain",
    "handmade"
  ],
  "recentSearches": [
    { "type": "query", "text": "temple necklace", "label": "3 stores" },
    { "type": "store", "name": "Meera Gold House", "label": "store" },
    { "type": "query", "text": "kada", "label": "1 result" }
  ],
  "categories": [
    { "key": "necklace", "label": "Necklace", "productCount": 142 },
    { "key": "ring", "label": "Ring", "productCount": 98 },
    { "key": "bangle", "label": "Bangle", "productCount": 65 },
    { "key": "earrings", "label": "Earrings", "productCount": 210 },
    { "key": "chain", "label": "Chain", "productCount": 44 },
    { "key": "pendant", "label": "Pendant", "productCount": 31 }
  ]
}
```

---

## 4. Typeahead & Instant Suggestions (Screen 02): `GET /v1/catalog/search/suggest`

Fired on every debounced keystroke (e.g. 200ms debounce) as the user types in the search bar.

### Request
```http
GET /v1/catalog/search/suggest?q=meera HTTP/1.1
Host: api.bullionare.com
```

### Query Parameters
- `q` *(string, required)*: The search string typed by the user.
- `storeId` *(string, optional)*: If searching inside a specific store, restricts product suggestions to that store and suppresses global store suggestions.

### Ranking Rule
1. **Stores rank first**: Tagged `"type": "store"`, showing store name, slug, city, and avatar.
2. **Products rank next**: Tagged `"type": "product"`, showing title, store name, city, net weight, purity, and thumbnail.

### Response `200 OK`
```json
{
  "query": "meera",
  "matches": [
    {
      "type": "store",
      "id": "6aa152360057ea754e57434e",
      "name": "Meera Gold House",
      "slug": "meera-gold",
      "city": "Mumbai",
      "storeImage": "https://api.bullionare.com/v1/catalog/storage/store-cover.webp"
    },
    {
      "type": "product",
      "id": "6aa152360057ea754e57435f",
      "collectionId": "6aa152360057ea754e57435f",
      "subGroupId": null,
      "title": "Royal Temple Meera Choker",
      "storeId": "6aa152360057ea754e57434e",
      "storeName": "Meera Gold House",
      "slug": "meera-gold",
      "city": "Mumbai",
      "netWeight": 28.5,
      "purity": "92",
      "thumbnailUrl": "https://api.bullionare.com/v1/catalog/storage/necklace.webp"
    }
  ]
}
```
*Note on product suggestions*: `storeId` and `slug` are directly provided on product matches so the client can navigate to the product's store profile or fetch collection details without needing a secondary store lookup.

---

## 5. Global Search & Results Grid (Screens 03 & 04): `GET /v1/catalog/search`

Full global search with 8 multi-select filters, disjunctive sibling facet counters, card grid, and summary line.

### Request
```http
GET /v1/catalog/search?q=necklace&category=necklace&metal=gold&purity=92,86&weight=10_25&sort=weight_asc&limit=20 HTTP/1.1
Host: api.bullionare.com
```

### Query Parameters
Both singular and plural parameter names are accepted interchangeably:
- `category` or `categories` *(string / csv)*: Multi-select categories: e.g. `necklace,bangle`.
- `metal` or `metals` *(string / csv)*: Multi-select metals: e.g. `gold,diamond`.
- `purity` or `purities` *(string / csv)*: Multi-select purities: e.g. `92,86,75,varied`.
- `weight` or `weights` *(string / csv)*: Multi-select weight bands: `under_10`, `10_25`, `25_50`, `over_50`.
- `size` or `sizes` *(string / csv)*: Multi-select size bands: `free_size`, `under_2`, `2_3`, `over_3`.
- `wastage` or `wastages` *(string / csv)*: Multi-select wastage bands: `under_8`, `8_12`, `over_12`.
- `store` or `stores` *(string / csv)*: Multi-select store slugs or 24-hex store IDs.
- `location` or `locations` *(string / csv)*: Multi-select city names: e.g. `Mumbai,Bangalore`.
- `q` *(string, optional)*: Text query matching title, tag, category, store name, or city.
- `sort` *(string, optional)*: Sort order:
  - `newest` *(default)*: Most recently added first.
  - `weight_asc`: Lowest net weight first.
  - `weight_desc`: Heaviest net weight first.
- `limit` *(integer, default 20, max 100)*: Items per page.
- `cursor` *(string, optional)*: Keyset pagination cursor from `nextCursor`.

### Item Identifiers & Navigation Contract
Every search item returns:
- `collectionId`: **The public Listing ID**. To view full product/collection details, call:
  `GET /v1/catalog/stores/:storeId/collections/:collectionId`
  *(Guaranteed 200 OK — resolves directly to the listing)*.
- `id`: Unique identifier for the search hit. Equal to `collectionId` for root collection items, or `${collectionId}:${subGroupId}` for precision sub-group variants.
- `subGroupId`: Sub-group MongoDB `_id` if the hit is a precision sub-group variant, or `null` if root. If present, the client UI can auto-scroll or highlight this variant inside the collection detail screen.

### Response `200 OK`
```json
{
  "summary": {
    "totalProducts": 14,
    "totalStores": 3,
    "countLine": "14 products across 3 stores"
  },
  "items": [
    {
      "id": "6aa152360057ea754e57435f",
      "collectionId": "6aa152360057ea754e57435f",
      "subGroupId": null,
      "title": "Royal Temple Antique Necklace",
      "thumbnailUrl": "https://api.bullionare.com/v1/catalog/storage/necklace.webp",
      "store": {
        "id": "6aa152360057ea754e57434e",
        "name": "Meera Gold House",
        "slug": "meera-gold",
        "city": "Mumbai"
      },
      "details": {
        "category": "necklace",
        "metalType": ["gold"],
        "netWeight": 22.5,
        "grossWeight": 24.5,
        "deduction": 2.0,
        "purity": "92",
        "wastage": 10,
        "size": "18 inch",
        "precisionTag": "92 Purity | 22.5g Net | 10% W | 18 inch"
      }
    }
  ],
  "facets": {
    "category": [
      { "value": "necklace", "label": "Necklace", "count": 14 },
      { "value": "ring", "label": "Ring", "count": 8 },
      { "value": "bangle", "label": "Bangle", "count": 5 },
      { "value": "earrings", "label": "Earrings", "count": 12 },
      { "value": "chain", "label": "Chain", "count": 2 },
      { "value": "pendant", "label": "Pendant", "count": 1 }
    ],
    "metal": [
      { "value": "gold", "label": "Gold", "count": 14 },
      { "value": "diamond", "label": "Diamond", "count": 3 },
      { "value": "silver", "label": "Silver", "count": 0 },
      { "value": "gemstone", "label": "Gemstone", "count": 1 }
    ],
    "purity": [
      { "value": "999", "label": "999 (24K)", "count": 0 },
      { "value": "92", "label": "92 (22K)", "count": 10 },
      { "value": "86", "label": "86 (20.6K)", "count": 4 },
      { "value": "82", "label": "82 (19.7K)", "count": 0 },
      { "value": "75", "label": "75 (18K)", "count": 2 },
      { "value": "varied", "label": "Varied", "count": 0 }
    ],
    "weight": [
      { "value": "under_10", "label": "Under 10g", "count": 1 },
      { "value": "10_25", "label": "10 - 25g", "count": 14 },
      { "value": "25_50", "label": "25 - 50g", "count": 6 },
      { "value": "over_50", "label": "Over 50g", "count": 2 }
    ],
    "size": [
      { "value": "free_size", "label": "Free size", "count": 0 },
      { "value": "under_2", "label": "Under 2\"", "count": 0 },
      { "value": "2_3", "label": "2\" - 3\"", "count": 0 },
      { "value": "over_3", "label": "Over 3\"", "count": 14 }
    ],
    "wastage": [
      { "value": "under_8", "label": "Under 8%", "count": 2 },
      { "value": "8_12", "label": "8 - 12%", "count": 11 },
      { "value": "over_12", "label": "Over 12%", "count": 1 }
    ],
    "store": [
      { "id": "6aa152360057ea754e57434e", "name": "Meera Gold House", "count": 10 },
      { "id": "6aa152360057ea754e57434f", "name": "Tanishq Bullion", "count": 4 }
    ],
    "location": [
      { "value": "Mumbai", "count": 10 },
      { "value": "Bangalore", "count": 4 }
    ]
  },
  "nextCursor": "eyJpZCI6IjZhYTE1MjM2MDA1N2VhNzU0ZTU3NDM1ZiIsIndlaWdodCI6MjIuNSwiY3JlYXRlZEF0IjoiMjAyNi0wOS0yMlQxMDozMDowMC4wMDBaIn0="
}
```

---

## 6. In-Store Header Chips (Screen 05): `GET /v1/catalog/stores/:storeId/facets`

Provides quick-filter summary chips at the top of the store screen under "WHAT THIS STORE HAS".

### Request
```http
GET /v1/catalog/stores/6aa152360057ea754e57434e/facets HTTP/1.1
Host: api.bullionare.com
```

### Response `200 OK`
```json
{
  "store": {
    "id": "6aa152360057ea754e57434e",
    "name": "Meera Gold House",
    "slug": "meera-gold",
    "city": "Mumbai",
    "totalProducts": 48
  },
  "summaryChips": [
    { "type": "category", "value": "necklace", "label": "Necklace 24" },
    { "type": "category", "value": "bangle", "label": "Bangle 16" },
    { "type": "category", "value": "ring", "label": "Ring 8" },
    { "type": "purity", "value": "92", "label": "92 purity 38" },
    { "type": "purity", "value": "75", "label": "75 purity 10" },
    { "type": "metal", "value": "gold", "label": "Gold 48" },
    { "type": "metal", "value": "diamond", "label": "Diamond 8" }
  ]
}
```

---

## 7. In-Store Search & Results Grid (Screens 05 & 06): `GET /v1/catalog/stores/:storeId/search`

Scoped search inside a single store.

### Differences from Global Search
1. **Count Line**: Shows `"X of Y items in this store"` (e.g. `"6 of 48 items in this store"`).
2. **Product Cards**: Store name and city are removed (`"store": null`) because the user is already inside the store.
3. **Filter Sheet**:
   - `Store` and `Location` filter sections disappear (6 filters remain).
   - Categories and purities that the store does **not** stock return with `count: 0` so the client can display them greyed-out rather than hiding them.

### Request
```http
GET /v1/catalog/stores/6aa152360057ea754e57434e/search?category=necklace HTTP/1.1
Host: api.bullionare.com
```

### Response `200 OK`
```json
{
  "summary": {
    "totalProducts": 24,
    "totalStores": 1,
    "countLine": "24 of 48 items in this store"
  },
  "items": [
    {
      "id": "6aa152360057ea754e57435f",
      "collectionId": "6aa152360057ea754e57435f",
      "subGroupId": null,
      "title": "Royal Temple Antique Necklace",
      "thumbnailUrl": "https://api.bullionare.com/v1/catalog/storage/necklace.webp",
      "store": null,
      "details": {
        "category": "necklace",
        "metalType": ["gold"],
        "netWeight": 22.5,
        "grossWeight": 24.5,
        "deduction": 2.0,
        "purity": "92",
        "wastage": 10,
        "size": "18 inch",
        "precisionTag": "92 Purity | 22.5g Net | 10% W | 18 inch"
      }
    }
  ],
  "facets": {
    "category": [
      { "value": "necklace", "label": "Necklace", "count": 24 },
      { "value": "ring", "label": "Ring", "count": 8 },
      { "value": "bangle", "label": "Bangle", "count": 16 },
      { "value": "earrings", "label": "Earrings", "count": 0 },
      { "value": "chain", "label": "Chain", "count": 0 },
      { "value": "pendant", "label": "Pendant", "count": 0 }
    ],
    "metal": [
      { "value": "gold", "label": "Gold", "count": 24 },
      { "value": "diamond", "label": "Diamond", "count": 4 },
      { "value": "silver", "label": "Silver", "count": 0 }
    ],
    "purity": [
      { "value": "999", "label": "999 (24K)", "count": 0 },
      { "value": "92", "label": "92 (22K)", "count": 20 },
      { "value": "86", "label": "86 (20.6K)", "count": 0 },
      { "value": "75", "label": "75 (18K)", "count": 4 }
    ],
    "weight": [
      { "value": "under_10", "label": "Under 10g", "count": 0 },
      { "value": "10_25", "label": "10 - 25g", "count": 18 },
      { "value": "25_50", "label": "25 - 50g", "count": 6 },
      { "value": "over_50", "label": "Over 50g", "count": 0 }
    ],
    "size": [
      { "value": "free_size", "label": "Free size", "count": 0 },
      { "value": "under_2", "label": "Under 2\"", "count": 0 },
      { "value": "2_3", "label": "2\" - 3\"", "count": 0 },
      { "value": "over_3", "label": "Over 3\"", "count": 24 }
    ],
    "wastage": [
      { "value": "under_8", "label": "Under 8%", "count": 4 },
      { "value": "8_12", "label": "8 - 12%", "count": 20 },
      { "value": "over_12", "label": "Over 12%", "count": 0 }
    ]
  },
  "nextCursor": null
}
```

---

## 8. Multi-Select & Sibling Filter Logic

### 8.1 Boolean Evaluation
- **Within the same filter**: Evaluated with **OR** (`$in`).
  - Example: `category=necklace,bangle` matches items that are either a necklace OR a bangle.
- **Across different filters**: Evaluated with **AND**.
  - Example: `category=necklace&purity=92` matches items that are necklaces AND have 92 purity.

### 8.2 Dynamic Sibling Facet Counting (No Dead Ends)
When calculating facet counts, the backend executes disjunctive aggregation facets:
- Each facet's counts are calculated by applying all currently selected filters **except its own**.
- If a user has checked `Purity: 92`, the purity facet still displays `{ "92": 10, "75": 2, "86": 4 }` instead of collapsing other purities to 0.
- This allows users to see what items exist in alternative options without returning an empty results grid.

---

## 9. Filter Bands Reference

### Weight Bands (`weight`)
| Band Key | Condition | UI Label |
| :--- | :--- | :--- |
| `under_10` | `netWeight < 10g` | Under 10g |
| `10_25` | `10g <= netWeight <= 25g` | 10 - 25g |
| `25_50` | `25g < netWeight <= 50g` | 25 - 50g |
| `over_50` | `netWeight > 50g` | Over 50g |

### Wastage Bands (`wastage`)
| Band Key | Condition | UI Label |
| :--- | :--- | :--- |
| `under_8` | `wastage < 8%` | Under 8% |
| `8_12` | `8% <= wastage <= 12%` | 8 - 12% |
| `over_12` | `wastage > 12%` | Over 12% |

### Size Bands (`size`)
| Band Key | Condition | UI Label |
| :--- | :--- | :--- |
| `free_size` | Made-to-fit / free size | Free size |
| `under_2` | `< 2 inches` (< 50.8 mm) | Under 2" |
| `2_3` | `2 - 3 inches` (50.8 - 76.2 mm) | 2" - 3" |
| `over_3` | `> 3 inches` (> 76.2 mm) | Over 3" |

### Purities (`purity`)
`999` (24K), `92` (22K), `86` (20.6K), `82` (19.7K), `75` (18K), `varied`.

### Standard Categories (`category`)
`necklace`, `ring`, `bangle`, `earrings`, `chain`, `pendant`. (Custom merchant categories are also supported and indexed dynamically).

### Standard Metals (`metal`)
`gold`, `silver`, `diamond`, `platinum`, `gemstone`.

---

## 10. Flutter / Dart Integration Guide

### 10.1 API Service Client
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class CatalogSearchApi {
  final String baseUrl;
  final String? accessToken;

  CatalogSearchApi({
    this.baseUrl = 'https://api.bullionare.com/v1/catalog',
    this.accessToken,
  });

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  /// Screen 01: Pre-search metadata (categories, trending tags, recents)
  Future<Map<String, dynamic>> getPreSearchMeta({String? storeId}) async {
    final uri = Uri.parse('$baseUrl/search/meta').replace(
      queryParameters: {
        if (storeId != null) 'storeId': storeId,
      },
    );
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  /// Screen 02: Typeahead instant suggestions
  Future<Map<String, dynamic>> suggest(String query, {String? storeId}) async {
    final uri = Uri.parse('$baseUrl/search/suggest').replace(
      queryParameters: {
        'q': query,
        if (storeId != null) 'storeId': storeId,
      },
    );
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  /// Screens 03 & 04: Global search with multi-select filters
  Future<Map<String, dynamic>> search({
    String? q,
    List<String>? categories,
    List<String>? metals,
    List<String>? purities,
    List<String>? weights,
    List<String>? sizes,
    List<String>? wastages,
    List<String>? stores,
    List<String>? locations,
    String sort = 'newest',
    int limit = 20,
    String? cursor,
  }) async {
    final qParams = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (categories != null && categories.isNotEmpty) 'category': categories.join(','),
      if (metals != null && metals.isNotEmpty) 'metal': metals.join(','),
      if (purities != null && purities.isNotEmpty) 'purity': purities.join(','),
      if (weights != null && weights.isNotEmpty) 'weight': weights.join(','),
      if (sizes != null && sizes.isNotEmpty) 'size': sizes.join(','),
      if (wastages != null && wastages.isNotEmpty) 'wastage': wastages.join(','),
      if (stores != null && stores.isNotEmpty) 'store': stores.join(','),
      if (locations != null && locations.isNotEmpty) 'location': locations.join(','),
      'sort': sort,
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: qParams);
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  /// Screen 05: Store header quick-filter chips
  Future<Map<String, dynamic>> getStoreFacets(String storeId) async {
    final res = await http.get(Uri.parse('$baseUrl/stores/$storeId/facets'), headers: _headers);
    return jsonDecode(res.body);
  }

  /// Screens 05 & 06: In-store scoped search
  Future<Map<String, dynamic>> storeSearch(
    String storeId, {
    String? q,
    List<String>? categories,
    List<String>? metals,
    List<String>? purities,
    List<String>? weights,
    List<String>? sizes,
    List<String>? wastages,
    String sort = 'newest',
    int limit = 20,
    String? cursor,
  }) async {
    final qParams = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (categories != null && categories.isNotEmpty) 'category': categories.join(','),
      if (metals != null && metals.isNotEmpty) 'metal': metals.join(','),
      if (purities != null && purities.isNotEmpty) 'purity': purities.join(','),
      if (weights != null && weights.isNotEmpty) 'weight': weights.join(','),
      if (sizes != null && sizes.isNotEmpty) 'size': sizes.join(','),
      if (wastages != null && wastages.isNotEmpty) 'wastage': wastages.join(','),
      'sort': sort,
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final uri = Uri.parse('$baseUrl/stores/$storeId/search').replace(queryParameters: qParams);
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }
}
```

### 10.2 Bottom Button Dynamic Label
In the Filter Sheet (Screen 04 and Screen 06), as the user toggles checkboxes, call the search endpoint with the updated filter set and read `response['summary']['totalProducts']`:
```dart
ElevatedButton(
  onPressed: () => Navigator.pop(context, activeFilters),
  child: Text('Show ${summary['totalProducts']} products'),
)
```

### 10.3 Product Card Click & Navigation
When a user taps any product card from search results or typeahead suggestions, navigate directly using `collectionId`:
```dart
void onProductTapped(BuildContext context, Map<String, dynamic> item) {
  // Global search hits have item['store']['id']; suggest hits have item['storeId']
  final storeId = item['store'] != null ? item['store']['id'] : item['storeId'];
  final collectionId = item['collectionId']; // Always the public Listing ID
  final subGroupId = item['subGroupId'];     // Null for root, or variant ID

  // Fetch full details via GET /v1/catalog/stores/$storeId/collections/$collectionId
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CollectionDetailScreen(
        storeId: storeId,
        collectionId: collectionId,
        initialSubGroupId: subGroupId, // Client can auto-scroll to this variant
      ),
    ),
  );
}
```
