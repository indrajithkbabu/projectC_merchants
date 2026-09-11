# Auth webservice logic

## Endpoints
- `POST /auth/otp/request` → challenge id + resend cooldown (default 60s)
- `POST /auth/otp/verify` → profile + tokens (phone + challengeId + 6-digit code string)
- `POST /auth/refresh` → rotated token pair (serialized)
- `POST /auth/logout` → revoke family (204)

## Flow
1. Phone screen requests OTP; `AuthBloc` stores `challengeId`.
2. Production OTP: Indian mobile only (`+91`, 10 digits, first digit 6–9). Non-India country changes are rejected; map `UNSUPPORTED_PHONE_COUNTRY`.
3. OTP verify persists tokens via `CatalogSession` / `SessionStorage`.
4. Navigation uses `profile.onboarding`:
   - `name_required` → profile setup
   - `store_optional` → store setup
   - `complete` → store listing
5. Cold start: `AuthSessionRestoreRequested` → restore tokens → `GET /me`.
6. Account delete (`DELETE /me` from store listing): clear session → `AuthLoggedOut` → `auth_phone_route`.

## Errors
Mapped through `CatalogErrorMapper` only (friendly copy by `error.code`). Never show raw API messages or code strings in the UI.
