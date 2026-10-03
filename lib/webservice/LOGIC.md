# Webservice layer

## Purpose
Shared Catalog API networking for the Flutter app. All feature BLoCs talk to
repositories; repositories call request classes; request classes use
`CatalogApiClient` (`http` for JSON and multipart collection create).

## Layout
- `catalog_api_client.dart` — JSON + multipart, auth header, refresh-once retry
- `catalog_api_exception.dart` — typed API/transport errors (incl. `failedPhotos`)
- `catalog_error_mapper.dart` — maps codes → user-friendly UI messages
- `auth/`, `profile/`, `store/`, `collection/`, `import/` — domain pairs

## Rules
1. Flavor `baseUrl` already includes `/v1/catalog`.
2. Paths live in `lib/resources/endpoints.dart`.
3. UI never shows raw exception text, API `message`, or error codes; use
   `CatalogErrorMapper.toUserMessage` (code → friendly copy only).
4. Never refresh on OTP `INVALID_OTP`.
5. Serialize refresh (single in-flight) inside `CatalogApiClient`.
6. Debug logs via `AppLog` only in debug mode.
7. Every call logs full URL, sanitized body, and response. Tokens/OTP are redacted.
8. Collection photos use the **direct S3** pipeline (`/uploads/presign` staging
   keys + S3 PUT of compressed bytes + JSON commit/append with
   `clientRequestId` / `Idempotency-Key`). Multipart create/update remains as a
   legacy fallback. Removals still use `.../photos/delete`.
9. `failedPhotos` UI copy must use mapped codes — never server `message` strings.

## Scaling
Add a new domain folder (`request` + `repository` + models) and register it in
`ServiceLocator.configureDependencies()`. Keep BLoCs free of HTTP details.
