# Profile switching — BE gaps & FE alignment

Reviewed against BE profile/login response + installation-identity update.

## Chat (deferred — out of profile/login scope)

| Topic | Status |
| --- | --- |
| Per-profile chat unread counts on switcher rows | Deferred to chat contract. FE must **not** present mock unread as server data. |
| Chat sender label (`Name · Store`) | Deferred to chat contract. |

## Closed — no further BE work

| # | Topic | Resolution |
| --- | --- | --- |
| 2 | Personal handle | No personal username/slug. FE shows name + **Personal** label; hide `@handle`. |
| 3 | Create-store auto-switch | FE: `POST /stores` then `PATCH /me/active-profile`. |
| 4 | Accept-invite auto-switch | Intentional. Refresh profiles; do not auto-select. |
| 5 | SMS invitations | Deferred. Show **Invited** / pending only. |
| 6 | People-directory search | Device contacts + manual phone only. |
| 7 | `/contacts` vs `/invitations` | Prefer invitations + `GET …/staff`; contacts is compatibility alias (also invitation-based). |
| 8 | Installation `deviceId` | BE enforced. FE persists + sends JSON + matching header. |
| 9 | Store-deletion bootstrap example | Docs corrected; FE reconciles from response. |

## Invite indicator (non-chat)

Use `invitationSummary.pendingCount` / `hasPending` (and `pendingInvitations[]`) for the red invitation dot. Do not use chat unread for that indicator until the chat API exists.

## FE checklist (implemented)

- [x] Hide personal derived `@handle`; show Personal label
- [x] Invitation dot from `invitationSummary` / pending list only
- [x] No mock unread badges on switcher profile rows
- [x] `PROFILE_ACCESS_REMOVED`: refresh bootstrap without stale header; do not force Personal over a still-valid active profile
- [x] Map `DEVICE_ID_REQUIRED` / `INVALID_DEVICE_ID` / `DEVICE_ID_MISMATCH` (+ related profile codes)
- [x] Create store with Personal header; select after create
- [x] Accept invite → refresh only
- [x] Staff invites via `POST …/invitations`; list via `GET …/staff`
