# Collection `createdAt` — Backend Request (Frontend Ready)

**Audience:** Catalog backend  
**Base path:** `/v1/catalog`  
**Priority:** Needed for store-profile **Single** view date pills (Today / Yesterday / date)  
**Date observed:** 2026-10-13 (prod `api.bullionare.com`)  
**Frontend status:** Already implemented — **no app release required** once this field ships

---

## Summary

Store profile **Single** view groups products by upload day (Telegram-style pills:
**Today**, **Yesterday**, **October 12**).

Mobile already parses and maps `createdAt` on collection **list** and **detail**.
Prod responses currently **omit** the field, so the app falls back to the MongoDB
ObjectId timestamp in `id`. That fallback is approximate; the real upload /
create time should come from the API.

**Ask:** Add `createdAt` to collection list items and collection detail. Prefer
ISO-8601 UTC. No other response shape changes.

---

## Endpoints that must include `createdAt`

| Method | Path | Where |
|--------|------|--------|
| `GET` | `/stores/:storeId/collections` | Each object in `items[]` |
| `GET` | `/stores/:storeId/collections/:listingId` | Top-level collection body |

Optional (nice to have, same field name / format):

| Method | Path | Notes |
|--------|------|--------|
| `POST` | `/stores/:storeId/collections` | Create `201` body |
| `PATCH` | `/stores/:storeId/collections/:listingId` | If full collection is returned |

---

## Field contract (matches current Flutter parser)

| Key | Required | Type | Notes |
|-----|----------|------|--------|
| `createdAt` | **Yes** (for correct dates) | string \| number | Preferred key |

Also accepted by the client (aliases — do **not** rely on these as primary):

| Alias | Notes |
|-------|--------|
| `created_at` | Snake_case fallback |
| `uploadedAt` | Alternate name fallback |

### Preferred format (recommended)

ISO-8601 UTC string (what `DateTime.tryParse` accepts):

```json
"createdAt": "2026-10-12T07:56:29.000Z"
```

### Also accepted

| Format | Example | Notes |
|--------|---------|--------|
| Epoch **milliseconds** | `1791798389000` | JSON number |
| Epoch **seconds** | `1791798389` | JSON number (`< 1e11` treated as seconds) |
| ISO string without `Z` | `"2026-10-12T07:56:29"` | Parsed then localized on device |

**Do not send** empty string `""` — omit the field or send a valid value.

---

## Semantics

- `createdAt` = when the **collection (product listing) was first created / published**
  (upload day for the product card), not last photo append, not last metadata edit.
- Timezone: store as UTC; client converts to local for day buckets.
- Day pills use the **calendar date in the viewer’s local timezone** derived from
  this timestamp (time-of-day is not shown on the card).

---

## Gap today (prod sample)

### List — `GET /stores/:storeId/collections`

Observed `200` item shape (truncated) — **no date field**:

```json
{
  "items": [
    {
      "id": "6accac75eb13cb7b30519058",
      "name": "ring",
      "tag": "",
      "description": "",
      "revision": 1,
      "photoCount": 4,
      "viewCount": 2,
      "cover": { "...": "..." },
      "kind": "original",
      "permissions": { "edit": true, "delete": true }
    }
  ],
  "nextCursor": null
}
```

### Detail — `GET /stores/:storeId/collections/:listingId`

Same omission on the top-level body (photos, specs, `viewCount`, etc. present;
**no** `createdAt`).

---

## Desired response (additive only)

### List item

```json
{
  "id": "6accac75eb13cb7b30519058",
  "name": "ring",
  "createdAt": "2026-10-12T07:56:29.000Z",
  "revision": 1,
  "photoCount": 4,
  "viewCount": 2,
  "cover": { "...": "..." },
  "kind": "original",
  "permissions": { "edit": true, "delete": true }
}
```

### Detail

```json
{
  "id": "6accac75eb13cb7b30519058",
  "name": "ring",
  "createdAt": "2026-10-12T07:56:29.000Z",
  "revision": 1,
  "photoCount": 4,
  "photos": [ "..."],
  "kind": "original",
  "permissions": { "edit": true, "delete": true }
}
```

Existing fields stay unchanged. This is a **backward-compatible additive** field.

---

## Frontend behavior (already shipped in app code)

1. Parse `createdAt` \| `created_at` \| `uploadedAt` via `parseCatalogDateTime`
   (`lib/models/catalog/collection_models.dart`).
2. Map onto `StoreProduct.createdAt` in `CatalogUiMapper.summaryToProduct` /
   `detailToProduct`.
3. If missing → fall back to Mongo ObjectId time from collection `id`
   (`resolveCollectionCreatedAt`).
4. Single view date pills: **Today** / **Yesterday** / **October 12** from that
   day (no per-card clock time).

Once `createdAt` is present on list (primary path for the grid), the ObjectId
fallback is unused for those items.

---

## Acceptance checklist

- [ ] `GET .../collections` each `items[]` element includes `createdAt`
- [ ] `GET .../collections/:listingId` includes top-level `createdAt`
- [ ] Value is create/publish time of the listing (stable; not bumped on photo append)
- [ ] Preferred format: ISO-8601 UTC string
- [ ] Existing clients keep working (field is additive)
- [ ] Smoke: Single view on store profile shows correct day for a listing created
      yesterday / last week (not always “Today”)

---

## Out of scope

- Per-photo `createdAt` (not required for product-level day pills)
- Changing sort order of the collections list
- Frontend changes (parser + UI already handle the field)
