# Notification webservice logic

## Device tokens (FCM)
- `PushNotificationService.initialize` — listeners only (no Bearer). Runtime
  notification permission is deferred until Activity exists.
- `requestRuntimePermissions` — after first frame / before `getToken`
  (Android 13+ shows POST_NOTIFICATIONS dialog).
- `PushNotificationService.onSignedIn` — permission → FCM `getToken` →
  `POST /devices/token` `{ token, platform }` with Bearer (OTP verify /
  session restore). Do **not** register before `accessToken` exists.
- FCM `onTokenRefresh` — re-`POST` only if signed in.
- `DELETE /devices/token` `{ token }` — before local logout clears the session
  (still needs Bearer).

## In-app Activity feed
- `ActivityRepository` → `GET /activity`, `GET /activity/unread-count`,
  `POST /activity/read` (`all: true` or `notificationIds`).
- UI: Stores home bell → `activity_route` (Instagram-style list + pinned
  follow-request banner). Opening the feed marks all read (clears badge).
- `product_liked` is feed-only (no FCM push per API).

## Notes
- Push payload deep-links are handled in `PushNotificationService`, not here.
- Upload bell mute uses `PATCH /stores/:id/follow` `{ notifyUploads }` via
  `StoreRepository` (same follow path as follow/unfollow).
  Client `PATCH notifyUploads: true` when follow becomes active so
  `new_upload` pushes are not muted by default.
- Android debug SHA-1/256 must be registered on the Firebase Android app
  (`firebase apps:android:sha:*`). APIs needed: FCM, FCM Registration,
  Firebase Installations.
- Android API key must **not** over-restrict `apiTargets` — a Firebase
  auto-created key that lists only some services can let Installations
  succeed while GMS `getToken` returns `FCM Registration failed`.
- `android:allowBackup="false"` + backup exclusions avoid shared FIDs
  across devices (`Invalid argument for the given fid`).
