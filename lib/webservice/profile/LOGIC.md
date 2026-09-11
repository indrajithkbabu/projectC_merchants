# Profile webservice logic

## Endpoints
- `GET /me`
- `PATCH /me` `{firstName, lastName?}`
- `POST /me/onboarding/skip-store` `{}`
- `DELETE /me` → delete catalog account (Bearer access token; typically 204)

## Notes
- Profile photo is local-only UX; Catalog API does not accept avatars.
- Successful name patch usually moves onboarding to `store_optional`.
- Skip store marks onboarding `complete` without creating a store.
- Account delete clears local session after the API call; UI resets `AuthBloc`
  via `AuthLoggedOut` and lands on `auth_phone_route`.
