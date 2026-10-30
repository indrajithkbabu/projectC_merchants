# 12 — Collection `createdAt`

**Status:** Confirm  
**Index:** [README.md](./README.md)  
**Detail history:** `lib/webservice/collection/COLLECTION_CREATED_AT_BACKEND.md`

---

## Ask

Needed for store-profile **Single** view day pills (Today / Yesterday / date).
FE already parses the field; prod often omits it → ObjectId-timestamp fallback.

| Method | Path | Where |
|--------|------|--------|
| `GET` | `/stores/:storeId/collections` | Each `items[]` |
| `GET` | `/stores/:storeId/collections/:listingId` | Top-level body |

Preferred: `"createdAt": "2026-10-12T07:56:29.000Z"` (create/publish time of the
listing — stable; not bumped on photo append).

Aliases accepted by FE: `created_at`, `uploadedAt`.

---

## FE today

Parser + day pills shipped; ObjectId time used when field missing.

---

## Acceptance

- [ ] List items include `createdAt`
- [ ] Detail includes top-level `createdAt`
- [ ] Value is create/publish time (not last photo append)
