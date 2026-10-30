# Store Import Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/store_import/`.

## Mandatory Update Rule
- If import selection, pending/approved flow, messaging, states, or requirements change, update this file in the same PR.

## UI Rules
- Use `ScreenWrapper` for every route in this flow.
- Use `AppPadding`, `AppTextStyles`, and `AppColors` for consistency.
- Reuse shared helper widgets for common controls/actions.

## Logic Ownership
- Store import screens own only import-related presentation and state-to-UI mapping.
- **Quick Import (API `quick-import-api.md`):**
  - Other store: long-press a photo → multi-select. Feed flags:
    `isAlreadyImported` → **In Your Store**; `LOCKED_TIER_MAX` → **Exclusive**
    (selection disabled + toast *Exclusive piece — cannot be re-imported*).
  - Import dock label uses in-memory split: unlocked = instant, locked = need
    approval (`visitorImportSelectionSplit`).
  - Import opens `add_product_compose_route` in import mode (prefill + local
    draft cache). Unlocked: stock editable. Source-locked: stock read-only
    (“follows source”); lock cannot be turned off; importers may lock their
    unlocked copy.
  - Send → `POST /v1/catalog/stores/:destinationStoreId/imports` via
    `QuickImportFlow` / `ImportRepository.submitBatchImport`. Results:
    `live` / `pending` / `already_imported` / `not_found`. Never treat
    `already_imported` as a hard failure. Live rows → shell My store;
    pending → toast with View → Import requests **Sent**.
  - Own-store **Source Deleted** ghost tiles live on store profile grid
    (blur + Remove → `StoreProfileProductsDeleted`), not in this folder.
- Keep side effects in listeners (navigation + error snackbars).
- Keep external domain logic outside these presentation files.
- Legacy toolbar download still opens `store_import_select_route`
  (`GET /import-targets` + older decision path). Prefer photo Quick Import
  for the batch API.
- Own-store inbox: Profile / Settings → `store_import_requests_route`.
  `ImportRequestsBloc` uses `GET …/import-requests?tab=received|sent`.
  UI tabs: **Received** / **Sent**. Received expands each batch into
  **one card per product** (deduped by created/source product id; newest
  batch wins when BE returns duplicate requests for the same Send). Each
  card has its own Approve / Decline. Decision body is `partial` with
  `approvedProductIds` / `declinedProductIds`. Sent also expands to
  **one card per product** (no cross-batch dedupe) so mixed
  approved/declined rows show their item status instead of a single
  batch `partially_approved` pill. **Cancel request** stays batch-level
  when `status == pending` (`DELETE …/import-requests/:id`, fallback
  `POST …/cancel`) and appears once on the first pending Sent row of
  that request. Cold load uses `ImportRequestsListShimmer`.
  - Own-store destination shelf: `importStatus: pending` → **Pending** tag;
    `declined` → **Declined by Partner** ghost + **Delete** (same delete path
    as Source Deleted). Collection badges use `productCount` (owner =
    live+pending+declined). Optional fields: `liveProductCount`,
    `pendingProductCount`, `declinedProductCount`.

## Route and Navigation Notes
- Maintain route mappings via centralized navigation route files.
- Use shared Cupertino-style transitions across this flow.
- Own store profile inbox → Settings / Profile → `store_import_requests_route`.
- Pending/approved “Back to my store” / “View my store” use
  `CatalogSession.profile.ownStore` (real store id).

## Folder Scope
- `quick_import_flow.dart`: selection → compose → batch POST.
- `store_import_select_route.dart`, `store_import_pending_route.dart`,
  `store_import_approved_route.dart`: legacy select flow.
- `store_import_requests_route.dart`: Received / Sent batches.

## ImportQA Logcat filter
- Debug-only tag: **`ImportQA`** (`lib/helper/import_qa.dart`).
- Android Studio / `flutter logs` search: `ImportQA`
- CLI: `adb logcat -s flutter:I | findstr /I ImportQA`
- Checkpoints: visitor source product stock/lock matrix, selection → compose,
  Send payload, Send result (`live`/`pending`/`already_imported`),
  Received per-item Approve/Decline (`Decision → partial/…`).

## Stock / lock import matrix (A = source, B = importer)

Setup
- A uploads 4 photos in one listing with:
  1. in + unlocked  
  2. in + locked  
  3. out + unlocked  
  4. out + locked  
- B follows A (locked rows are hidden until following).
- B Logcat filter: `ImportQA` (debug build).

| # | Case | B dock (select all 4) | After Send | On A Received | After A Approve | B My store |
|---|------|------------------------|------------|---------------|-----------------|------------|
| T1 | in unlocked | instant | `live` | — | — | unlocked, in |
| T2 | in locked | need approval | `pending` | Approve | live on B | locked + in (follows source stock) |
| T3 | out unlocked | instant | `live` | — | — | out (editable on compose unless source lock) |
| T4 | out locked | need approval | `pending` | Approve | live on B | locked + out |
| T5 | Decline locked | pending | `pending` | Decline | Declined on B (owner) until Delete | — |
| T6 | Re-import unlocked live | already / In Your Store | `already_imported` ok | — | — | no duplicate hard fail |
| T7 | Unfollow then reopen | locked hidden again | — | — | — | only unlocked visible |

Expect in `ImportQA`
- `Source products (visitor)` → 4 rows with `in/L=false`, `in/L=true`, `out/L=false`, `out/L=true` after follow.
- `Dock Import tap` → `instant=2 pending=2` when all 4 selected (not instant=4).
- `Resolved photos` → **product** ids (…1996/97/98/99), not collection listing id.
- `Send → POST` → `items=4` with per-id `srcL` / stock (never `items=1` + collection id).
- `Send result` → unlocked → `live`, locked → `pending` (not `notFound`).
- `Decision → approve|decline` on A.
- `Cancel → pending request` on B Sent (while still `pending`).

## Group collage → import ids
- Grid Group cards use listing id as `StoreProduct.id` and put each
  `CatalogProduct.id` in `photoAssetIds[i]` (plus `imageIsLocked` /
  `imageStockStatuses`).
- Quick Import resolves `cardId|imageIndex` → `sourceProductIdAt(index)` for
  `POST …/imports`. Do not send the collection listing id as
  `sourceProductId`.
