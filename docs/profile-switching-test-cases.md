# Profile switching — test cases

**Filter / tag:** `@profile_switching`

Use two physical devices (or two emulators) where noted as **Device A** / **Device B**. Same person phone can only be on one OTP session per device install; for multi-person flows use two accounts (two phone numbers).

---

## A. Installation identity & login

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-01 | `@profile_switching` | Fresh install OTP | Clear app data → OTP verify | Stable `deviceId` persisted; verify sends JSON `deviceId` + matching `X-Catalog-Device-Id`; 200 bootstrap with Personal active |
| PS-02 | `@profile_switching` | Logout keeps device id | Sign out → sign in again on same install | Same installation id reused; not regenerated |
| PS-03 | `@profile_switching` | New install restores Personal | Device B fresh install, same phone OTP | New device id; bootstrap Personal (no Device A’s store selection) |
| PS-04 | `@profile_switching` | Returning install restores selection | Device A: select owned store → kill app → reopen | Active profile restored to that store |
| PS-05 | `@profile_switching` | DEVICE_ID_REQUIRED path | (Dev only) omit device id | 400 + user-facing install identity message; challenge not consumed |
| PS-06 | `@profile_switching` | Name required onboarding | New user without name | Complete name before protected actions; then shell |

---

## B. Shell / Personal UI

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-10 | `@profile_switching` | Unified tabs | Any signed-in user | Tabs: Stores · Message · Wishlist · Profile (no Settings tab) |
| PS-11 | `@profile_switching` | Personal profile chrome | Active Personal → Profile | Name, **Personal** badge (no derived `@handle`), Edit profile / Share profile, hamburger |
| PS-12 | `@profile_switching` | Personal hamburger | ☰ on Personal | Create a store (if quota), Log out, Cancel |
| PS-13 | `@profile_switching` | Nav avatar = active | Personal active | Profile tab avatar = personal photo/initials |

---

## C. Switcher

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-20 | `@profile_switching` | Open from chevron | Tap name + chevron on Profile | Switcher lists Personal + selectable stores + pending invites + Create a store (when allowed) |
| PS-21 | `@profile_switching` | Open via long-press | Long-press Profile tab from Stores/Message/Wishlist | Same switcher; stay on current tab until select |
| PS-22 | `@profile_switching` | Select store | Tap inactive owned/staff store | Switch moment (~500ms); Profile becomes that store; nav avatar updates; chats subtitle `as {store}` |
| PS-23 | `@profile_switching` | Select Personal | From store → Personal | Switch moment; Personal UI; chats scoped personal |
| PS-24 | `@profile_switching` | Invite red dot | Pending invite exists | Red dot on Profile header / tab from `invitationSummary` only (not mock chat unread) |
| PS-25 | `@profile_switching` | No unread badges on rows | Open switcher with invites/stores | Profile rows show check/circle only; no numeric unread badge from mock |

---

## D. Create store

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-30 | `@profile_switching` | Create from hamburger | Personal ☰ → Create a store → name → Create | `POST /stores` with Personal header; then `PATCH …/active-profile` `store:<id>`; Profile as Owner; toast `{name} created` |
| PS-31 | `@profile_switching` | Create from switcher | Switcher → Create a store | Same two-step; if was on staff store, switches toward Personal then create |
| PS-32 | `@profile_switching` | Select fails after create | Simulate select failure after 201 create | Store exists once; retry select or refresh profiles — **do not** create again |
| PS-33 | `@profile_switching` | Ten-store cap | Own 10 stores | Create CTA hidden / `OWNED_STORE_LIMIT_REACHED`; staff memberships do not consume slots |
| PS-34 | `@profile_switching` | Owner chrome after create | Land on new store Profile | Owner badge; **Edit store** + **Staff** buttons |

---

## E. Staff invites (owner + invitee)

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-40 | `@profile_switching` | Staff list order | Owner → Staff | Add staff first; Owner · You; Staff; Invited |
| PS-41 | `@profile_switching` | Invite via contacts | Add staff → select phones → Add | Prefer `POST …/invitations`; toast **Invitations pending** (no SMS claim); rows show Invited |
| PS-42 | `@profile_switching` | Manual phone when no permission | Deny contacts → enter E.164 manually | Invite still works |
| PS-43 | `@profile_switching` | Join invite | Invitee switcher → Join | Accept API; refresh profiles; **no** auto-switch; toast You joined …; store selectable as Staff |
| PS-44 | `@profile_switching` | Decline invite | Switcher → X | Decline; row gone; owner staff list drops invite |
| PS-45 | `@profile_switching` | Late signup | Invite unregistered phone → that phone OTP signup → open switcher | Pending invite discoverable; Join required before access |
| PS-46 | `@profile_switching` | Remove staff | Owner → staff row → Remove | Membership deleted; invitee loses store from switcher |
| PS-47 | `@profile_switching` | Revoke invite | Owner → Invited row → revoke | Invite cancelled; invitee pending disappears |

---

## F. Leave / delete / access removed

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-50 | `@profile_switching` | Staff leave | Staff ☰ → Leave {store} → confirm | Dialog warning; leave; Personal (or valid bootstrap); toast You left {store}; store gone from switcher |
| PS-51 | `@profile_switching` | Owner cannot leave | Owner ☰ | No Leave; has Delete store |
| PS-52 | `@profile_switching` | Owner delete | Owner ☰ → Delete → confirm | Bootstrap Personal; deleted store absent; ownership slot freed; toast |
| PS-53 | `@profile_switching` | Access removed while on that store | Owner removes staff while staff Device B is on that store → staff triggers next request | `PROFILE_ACCESS_REMOVED` → refresh without stale header; land Personal; toast |
| PS-54 | `@profile_switching` | Queued fail ≠ wipe other profile | Device B on Store B; stale request for removed Store A fails | Stay on Store B; do **not** force Personal |
| PS-55 | `@profile_switching` | Owner stays after removing other | Owner removes staff | Owner remains on own store context |

---

## G. Permissions & chats (mock)

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-60 | `@profile_switching` | Staff cannot manage | Act as Staff | No Edit store / Staff CTAs; ☰ only Leave; no delete store |
| PS-61 | `@profile_switching` | Owner manage | Act as Owner | Edit store, Staff, Delete; manage gated by permissions |
| PS-62 | `@profile_switching` | Personal cannot upload | Personal Profile / product flows | No store upload/import as Personal |
| PS-63 | `@profile_switching` | Message scope Personal | Personal → Message | Subtitle `as {personal name}`; personal-scoped mock inbox |
| PS-64 | `@profile_switching` | Message scope store | Switch to store → Message | Subtitle `as {store}`; store-scoped mock inbox |

---

## H. Two-device matrix (required)

| ID | Tag | Case | Device A | Device B | Expected |
|----|-----|------|----------|----------|----------|
| PS-70 | `@profile_switching` | Independent selection | Same phone; select Store X | Same phone; select Personal | Each install keeps its own active profile after relaunch |
| PS-71 | `@profile_switching` | Owner + staff phones | Owner invites B’s phone | B accepts Join | B gets Staff profile; A staff list shows Staff (not Invited) |
| PS-72 | `@profile_switching` | Remove while B active | Owner removes B | B was on that store | B next call → access removed recovery → Personal; A unaffected |
| PS-73 | `@profile_switching` | Delete store multi-device | Owner deletes store on A | B was staff of that store | Store gone from both switchers; B recovers to Personal; A Personal with slot freed |
| PS-74 | `@profile_switching` | Create on A only | Create store + select on A | B same person | B still Personal until B selects the new store |
| PS-75 | `@profile_switching` | Concurrent invite decisions | — | Accept on B then open A owner staff | A refresh shows Staff; repeating accept on B → `INVITATION_NOT_PENDING` friendly message + refresh |

---

## I. Regression smoke

| ID | Tag | Case | Steps | Expected |
|----|-----|------|-------|----------|
| PS-80 | `@profile_switching` | Stores / Wishlist | Browse home, open Wishlist as Personal and as store | Lists load; no crash; profile header on account-scoped calls |
| PS-81 | `@profile_switching` | Owner upload | As Owner, upload/import product | Works; destination = active store |
| PS-82 | `@profile_switching` | Settings reachable | Owner ☰ → Settings | Full settings (Appearance, logout, etc.) |
| PS-83 | `@profile_switching` | Shell back | Non-Stores tab → system back | Returns to Stores; double-back exits |
| PS-84 | `@profile_switching` | Bootstrap omit header | `GET /me`, `GET /me/profiles`, `PATCH /me/active-profile` | No stale `X-Catalog-Profile` on these |

---

## Notes for QA

- Tag every case with `@profile_switching` in the test runner / sheet filter.
- **Debug log filter:** in a **debug** build, filter Run / logcat for `@profile_switching`. Each line includes a case id (`PS-01`, `PS-22/70`, …). Release APKs omit these traces.
- Prefer application `error.code` over message text when asserting failures.
- Chat unread / sender composition are **out of scope** until chat BE lands — do not fail profile cases on mock unread badges.
- SMS invite delivery is deferred — assert **Invited / Invitations pending**, never “SMS sent”.
