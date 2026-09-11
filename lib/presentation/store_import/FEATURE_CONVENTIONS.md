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
- Keep side effects in listeners (navigation + error snackbars).
- Keep external domain logic outside these presentation files.
- `StoreImportBloc` probes `GET /import-targets` **per listing** on start. Already-added / pending products are disabled; only importable ones are pre-selected. Destination is the intersection of requestable targets across the current selection. `POST /import-requests` runs only for selected importable listings.
- Own-store inbox: `ImportRequestsBloc` lists `incoming` + `outgoing` via `GET /stores/:id/import-requests`. UI tabs: **Incoming** / **Sent**. Incoming pending → Accept (`approved`) / Reject (`rejected`) only (API `decision` allowlist). Sent pending is wait-only.

## Route and Navigation Notes
- Maintain route mappings via centralized navigation route files.
- Use shared Cupertino-style transitions across this flow.
- Select → pending → approved; errors surface via snackbar listeners on select/pending.
- Own store profile inbox → `store_import_requests_route`.
- Pending/approved “Back to my store” / “View my store” use `CatalogSession.profile.ownStore` (real store id), not `MerchantStoreSession.asChannel`.

## Folder Scope
- `store_import_select_route.dart`, `store_import_pending_route.dart`, `store_import_approved_route.dart`, `store_import_requests_route.dart`: import flow routes.
