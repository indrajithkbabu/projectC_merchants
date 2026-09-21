# Profile webservice logic

## Endpoints
- `GET /me` (includes `profileImage` / `profileImageUrl`)
- `PATCH /me` JSON `{firstName, lastName?}` or multipart with optional `profileImage`
- `POST /me/profile-image` multipart `profileImage` (replace avatar)
- `DELETE /me/profile-image`
- `POST /me/onboarding/skip-store` `{}`
- `DELETE /me` → delete catalog account (Bearer access token; typically 204)

## Notes
- Signup can attach an avatar on the same `PATCH /me` as names.
- Later avatar edits use `POST` / `DELETE` profile-image endpoints.
- Successful name patch usually moves onboarding to `store_optional`.
- Skip store marks onboarding `complete` without creating a store.
- Account delete clears local session after the API call; UI resets `AuthBloc`
  via `AuthLoggedOut` and lands on `auth_phone_route`.
