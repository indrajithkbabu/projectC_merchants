# View counting (`POST /views`)

| Method | Path | Notes |
| :--- | :--- | :--- |
| POST | `/views` | Batch beacon, 1–50 items; auth required |

Item `type`: `photo` (alias `asset`), `collection`, `subgroup`.  
`id`: Mongo ObjectId of the photo / listing / subgroup.

Client rules (see `ViewBeacon`):
- Enqueue only after ≥1s dwell on a visible photo.
- Session-dedupe keys; flush every ~4s or on app background.
- Fire-and-forget; do not retry storms on failure.
