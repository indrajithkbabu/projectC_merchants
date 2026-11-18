# Phase 1 chat API and realtime reference

## Shared contract

Base: `/v1/catalog/chat`. All routes require Bearer access token, completed Personal name and `X-Catalog-Profile: personal:<userId>` or `store:<storeId>`. Send `X-Catalog-Device-Id` for the installation bound at login (16-128 letters/digits/underscore/hyphen); session-bound omission is supported, mismatches are rejected. Body content type is JSON except photo upload (`multipart/form-data`, one `photo` file). All responses use `Cache-Control: no-store`. Photos are binary WebP. There are no 204 responses in this module. Query defaults: `limit=20`, maximum 50. Cursors are encrypted and bound to person/profile/resource/view; never manufacture or reuse across views.

Every write consumes a fixed-window profile write budget, with separate upload/contact/outreach budgets. Retries may consume budget too. Follow `Retry-After` on 429. Read requests also have a 600/minute profile budget. Operation IDs are 16-128 ASCII letters/digits/underscore/hyphen; UUIDs are accepted. IDs deduplicate discussion creation and message sending across retries. Reusing an ID with another payload returns 409. Creation retries return the same 201 result rather than a second object.

Phase 1 has no family, notes, mentions, edits/deletes or message search. Unknown endpoints return 404 NOT_FOUND. Direct API misuse does not enable later features. Ordinary messages are append-only; exceptional audited operator takedown is separate.

Daily customer-outreach budgets count committed introductory sends across the whole sending store (shared by its staff), reset at midnight Asia/Kolkata, and do not charge accepted-chat lookups or idempotent message retries. Other per-minute/hour windows use elapsed epoch buckets. Request expiry/cooldown are elapsed 30/90-day intervals from the introductory send.

## Endpoint index

| Method | Path | Success | Purpose |
| --- | --- | --- | --- |
| GET | `/v1/catalog/chat/capabilities` | 200 | Feature flags, profile context and engineering limits |
| GET | `/v1/catalog/chat/ready` | 200 | Chat operational readiness; 503 until every required component is configured |
| GET | `/v1/catalog/chat/settings` | 200 | Read Personal outreach preference |
| PATCH | `/v1/catalog/chat/settings` | 200 | Allow followed stores to bypass an initial request |
| POST | `/v1/catalog/chat/relationships` | 200 | Get or create unique relationship; registered recipients only |
| GET | `/v1/catalog/chat/relationships` | 200 | Inbox, requests or archived relationships; cursor is bound to view/profile |
| GET | `/v1/catalog/chat/relationships/:relationshipId` | 200 | Relationship detail without hidden customer phone |
| PATCH | `/v1/catalog/chat/relationships/:relationshipId/preferences` | 200 | Personal mute/archive; does not change colleagues |
| PUT | `/v1/catalog/chat/relationships/:relationshipId/block` | 200 | Block relationship communication |
| DELETE | `/v1/catalog/chat/relationships/:relationshipId/block` | 200 | Remove only own block |
| PUT | `/v1/catalog/chat/relationships/:relationshipId/contact` | 200 | Explicitly share customer phone |
| DELETE | `/v1/catalog/chat/relationships/:relationshipId/contact` | 200 | Withdraw phone from live contact field |
| POST | `/v1/catalog/chat/relationships/:relationshipId/request/accept` | 200 | accept customer message request |
| POST | `/v1/catalog/chat/relationships/:relationshipId/request/decline` | 200 | decline customer message request |
| POST | `/v1/catalog/chat/relationships/:relationshipId/request/retry` | 200 | Renew outreach after 90 days from prior send |
| POST | `/v1/catalog/chat/relationships/:relationshipId/discussions` | 201 | Atomically start a discussion with its required opening text; one or up to 20 same-store products |
| GET | `/v1/catalog/chat/relationships/:relationshipId/discussions` | 200 | List permitted discussions; pending customer sees introductory discussion only |
| GET | `/v1/catalog/chat/discussions/:discussionId` | 200 | Discussion, own-store handler, unanswered status and unread count |
| PATCH | `/v1/catalog/chat/discussions/:discussionId` | 200 | Rename or explicitly close/reopen discussion |
| POST | `/v1/catalog/chat/discussions/:discussionId/messages` | 201 | Append public text/photo/reply; acknowledge only after commit |
| GET | `/v1/catalog/chat/discussions/:discussionId/messages` | 200 | Newest-first bounded message history |
| POST | `/v1/catalog/chat/discussions/:discussionId/receipt` | 200 | Monotonic delivered/read acknowledgement for selected viewing side |
| POST | `/v1/catalog/chat/discussions/:discussionId/takeover` | 200 | Explicitly claim store-side responsibility |
| GET | `/v1/catalog/chat/work` | 200 | Store-side unanswered open discussions; no timed escalation |
| POST | `/v1/catalog/chat/discussions/:discussionId/photos` | 201 | Upload one JPEG/PNG/WebP; normalize, encrypt, bind to actor; no public plaintext URL |
| GET | `/v1/catalog/chat/photos/:photoId` | 200 | Authenticated no-store WebP response; ciphertext never returned |
| GET | `/v1/catalog/chat/sync` | 200 | Durable oldest-first event recovery; retain cursor even on an empty final page |

## GET /v1/catalog/chat/capabilities

Feature flags, profile context and engineering limits. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.


### Request example

`GET /v1/catalog/chat/capabilities`

No request body.

### Success example and variants

```json
{
  "enabled": true,
  "writesEnabled": true,
  "phase": 1,
  "profileContextVersion": 2,
  "features": {
    "customerStore": true,
    "storeStore": true,
    "text": true,
    "photos": true,
    "replies": true,
    "handlers": true,
    "multiProductEnquiry": true,
    "family": false,
    "notes": false,
    "mentions": false,
    "edits": false,
    "search": false
  },
  "limits": {
    "textCharacters": 4000,
    "productsPerDiscussion": 20,
    "photoBytes": 8388608,
    "photoPixels": 20000000,
    "photosPerMessage": 4,
    "pageSizeMax": 50,
    "messagesPerMinute": 60,
    "uploadsPerHour": 60,
    "contactsPerHour": 20,
    "outreachPerDay": 10,
    "mediaConcurrency": 4
  }
}
```

Disabled deployments still return this shape with enabled/writesEnabled false; inspect enabled before any feature flag. Missing active media key makes photos false. Limits reflect deployment configuration, not fixed constants.

### Endpoint errors

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "INTERNAL_ERROR"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/ready

Chat operational readiness; 503 until every required component is configured. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.


### Request example

`GET /v1/catalog/chat/ready`

No request body.

### Success example and variants

```json
{
  "database": true,
  "indexes": true,
  "media": true,
  "storage": true,
  "push": true,
  "worker": true,
  "realtime": true,
  "dispatch": true
}
```

Success is 200 when all checks are true; otherwise 503 with the same checks-object shape (false checks), not the error envelope. Dependency readiness failures and authenticated middleware errors remain distinguishable.
```json
{
  "database": true,
  "indexes": true,
  "media": true,
  "storage": true,
  "push": true,
  "worker": true,
  "realtime": false,
  "dispatch": false
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_DISABLED",
    "message": "CHAT_DISABLED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/settings

Read Personal outreach preference. **Authority:** Personal only. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.


### Request example

`GET /v1/catalog/chat/settings`

No request body.

### Success example and variants

```json
{
  "allowFollowedStores": false
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "PERSONAL_PROFILE_REQUIRED",
    "message": "PERSONAL_PROFILE_REQUIRED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 403 | PERSONAL_PROFILE_REQUIRED | Store attempted Personal setting change | Use Personal |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## PATCH /v1/catalog/chat/settings

Allow followed stores to bypass an initial request. **Authority:** Personal only. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| allowFollowedStores | boolean | yes | {} |

### Request example

`PATCH /v1/catalog/chat/settings`

```json
{
  "allowFollowedStores": false
}
```

### Success example and variants

```json
{
  "allowFollowedStores": false
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "PERSONAL_PROFILE_REQUIRED",
    "message": "PERSONAL_PROFILE_REQUIRED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 403 | PERSONAL_PROFILE_REQUIRED | Store attempted Personal setting change | Use Personal |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/relationships

Get or create unique relationship; registered recipients only. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| targetStoreId | string | no | {"rules":[{"name":"hex","args":{"options":{"byteAligned":false,"prefix":false}}},{"name":"length","args":{"limit":24}}]} |
| customerPhone | string | no | {"rules":[{"name":"max","args":{"limit":30}}]} |

Field combinations: [{"rel":"xor","peers":["targetStoreId","customerPhone"]}].

### Request example

`POST /v1/catalog/chat/relationships`

```json
{
  "targetStoreId": "507f1f77bcf86cd799439012"
}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

Relationship variants: active, pending, declined or effectively expired; blocked and disabled are independent. A fresh pending draft without introductory text is not exposed in the customer request inbox. A customer deliberately initiating the relationship activates it unless blocked. Store contact uses either targetStoreId or customerPhone; never both. Phone is international + format.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_ACCOUNT_DELETED",
    "message": "CHAT_ACCOUNT_DELETED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 404 | CUSTOMER_NOT_REGISTERED | Phone has no verified Catly user | Ask recipient to register; no account/SMS is created |
| 400 | INVALID_PHONE | Not a valid international phone starting + | Correct number |
| 403 | STORE_PROFILE_REQUIRED | Personal attempted a store-only operation | Switch explicitly; never retarget pending work |
| 404 | STORE_NOT_FOUND | Target store unavailable | Refresh store selection |
| 400 | CHAT_SELF_RELATIONSHIP | Target equals acting profile | Choose another profile |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/relationships

Inbox, requests or archived relationships; cursor is bound to view/profile. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.

### Query fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| cursor | string | no | {"rules":[{"name":"max","args":{"limit":3000}}]} |
| limit | number | no | {"default":20,"rules":[{"name":"integer"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":50}}]} |
| view | string | no | {"default":"inbox","allowed":["inbox","requests","archived"]} |

### Request example

`GET /v1/catalog/chat/relationships?limit=20`

No request body.

### Success example and variants

```json
{
  "items": [
    {
      "id": "507f1f77bcf86cd799439011",
      "sides": [
        {
          "id": "personal:507f1f77bcf86cd799439011",
          "name": "Ananya",
          "isViewerSide": true
        },
        {
          "id": "store:507f1f77bcf86cd799439012",
          "name": "Krishna Jewellers",
          "isViewerSide": false
        }
      ],
      "state": "active",
      "blocked": false,
      "blockedByViewer": false,
      "disabled": false,
      "sharedCustomerPhone": null,
      "requestSentAt": null,
      "nextRequestAt": null,
      "muted": false,
      "archived": false,
      "lastActivityAt": "2026-11-10T10:00:00.000Z",
      "unreadCount": 0,
      "lastMessage": null
    }
  ],
  "nextCursor": null
}
```

Lists may be empty. Pagination is a bounded scan; filtered inbox/work pages may be empty with a next cursor. Continue until the cursor is null. Sync instead uses `hasMore` and retains its last cursor even when no more events exist.

Relationship variants: active, pending, declined or effectively expired; blocked and disabled are independent. A fresh pending draft without introductory text is not exposed in the customer request inbox. A customer deliberately initiating the relationship activates it unless blocked. Store contact uses either targetStoreId or customerPhone; never both. Phone is international + format.

### Endpoint errors

```json
{
  "error": {
    "code": "INVALID_CURSOR",
    "message": "INVALID_CURSOR"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_CURSOR | Invalid/tampered/wrong-view/profile cursor | Discard cursor and reload that list |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/relationships/:relationshipId

Relationship detail without hidden customer phone. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).


### Request example

`GET /v1/catalog/chat/relationships/507f1f77bcf86cd799439011`

No request body.

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

Relationship variants: active, pending, declined or effectively expired; blocked and disabled are independent. A fresh pending draft without introductory text is not exposed in the customer request inbox. A customer deliberately initiating the relationship activates it unless blocked. Store contact uses either targetStoreId or customerPhone; never both. Phone is international + format.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_NOT_FOUND",
    "message": "CHAT_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## PATCH /v1/catalog/chat/relationships/:relationshipId/preferences

Personal mute/archive; does not change colleagues. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| muted | boolean | no | {} |
| archived | boolean | no | {} |

### Request example

`PATCH /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/preferences`

```json
{
  "muted": true
}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": true,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_NOT_FOUND",
    "message": "CHAT_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## PUT /v1/catalog/chat/relationships/:relationshipId/block

Block relationship communication. **Authority:** Original customer or selected store owner. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`PUT /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/block`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": true,
  "blockedByViewer": true,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "OWNER_REQUIRED",
    "message": "OWNER_REQUIRED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | OWNER_REQUIRED | Staff attempted store-wide block | Ask owner; do not elevate locally |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## DELETE /v1/catalog/chat/relationships/:relationshipId/block

Remove only own block. **Authority:** Original customer or selected store owner. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`DELETE /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/block`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "OWNER_REQUIRED",
    "message": "OWNER_REQUIRED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | OWNER_REQUIRED | Staff attempted store-wide block | Ask owner; do not elevate locally |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## PUT /v1/catalog/chat/relationships/:relationshipId/contact

Explicitly share customer phone. **Authority:** Original Personal customer. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`PUT /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/contact`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": "+919876543210",
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

Only the original Personal customer may share/withdraw their current verified phone. Withdrawal removes the live field; it cannot recall a number somebody already saw or explicitly typed in a message. Account deletion removes the live field.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_ACCOUNT_DELETED",
    "message": "CHAT_ACCOUNT_DELETED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_CUSTOMER_REQUIRED | Operation requires original Personal customer | Use original customer context |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## DELETE /v1/catalog/chat/relationships/:relationshipId/contact

Withdraw phone from live contact field. **Authority:** Original Personal customer. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`DELETE /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/contact`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

Only the original Personal customer may share/withdraw their current verified phone. Withdrawal removes the live field; it cannot recall a number somebody already saw or explicitly typed in a message. Account deletion removes the live field.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_ACCOUNT_DELETED",
    "message": "CHAT_ACCOUNT_DELETED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_CUSTOMER_REQUIRED | Operation requires original Personal customer | Use original customer context |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/relationships/:relationshipId/request/accept

accept customer message request. **Authority:** Original Personal customer. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`POST /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/request/accept`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "active",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": null,
  "nextRequestAt": null,
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_ACCOUNT_DELETED",
    "message": "CHAT_ACCOUNT_DELETED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_CUSTOMER_REQUIRED | Operation requires original Personal customer | Use original customer context |
| 409 | CHAT_REQUEST_NOT_PENDING | Expired/decided/inapplicable request or no introductory message | Refresh current request state |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/relationships/:relationshipId/request/decline

decline customer message request. **Authority:** Original Personal customer. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`POST /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/request/decline`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "declined",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": "2026-11-10T10:00:00.000Z",
  "nextRequestAt": "2027-02-08T10:00:00.000Z",
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_ACCOUNT_DELETED",
    "message": "CHAT_ACCOUNT_DELETED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_CUSTOMER_REQUIRED | Operation requires original Personal customer | Use original customer context |
| 409 | CHAT_REQUEST_NOT_PENDING | Expired/decided/inapplicable request or no introductory message | Refresh current request state |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/relationships/:relationshipId/request/retry

Renew outreach after 90 days from prior send. **Authority:** Selected store. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`POST /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/request/retry`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439011",
  "sides": [
    {
      "id": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    {
      "id": "store:507f1f77bcf86cd799439012",
      "name": "Krishna Jewellers",
      "isViewerSide": false
    }
  ],
  "state": "pending",
  "blocked": false,
  "blockedByViewer": false,
  "disabled": false,
  "sharedCustomerPhone": null,
  "requestSentAt": "2026-11-10T10:00:00.000Z",
  "nextRequestAt": "2027-02-08T10:00:00.000Z",
  "muted": false,
  "archived": false,
  "lastActivityAt": "2026-11-10T10:00:00.000Z",
  "unreadCount": 0,
  "lastMessage": null
}
```

The old request timestamp is retained for cooldown until the next introductory send. A renewed empty request is pending, not immediately expired; repeated renewal does not discard its draft discussion. Sending the new introduction starts its new 30/90-day clocks.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_ACCOUNT_DELETED",
    "message": "CHAT_ACCOUNT_DELETED"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | STORE_PROFILE_REQUIRED | Personal attempted a store-only operation | Switch explicitly; never retarget pending work |
| 409 | CHAT_REQUEST_COOLDOWN | Less than 90 days from previous request send | Wait until nextRequestAt; block still overrides |
| 409 | CHAT_REQUEST_NOT_PENDING | Expired/decided/inapplicable request or no introductory message | Refresh current request state |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/relationships/:relationshipId/discussions

Atomically start a discussion with its required opening text; one or up to 20 same-store products. **Authority:** Authenticated selected profile. **Success:** 201.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| operationId | string | yes | {"rules":[{"name":"pattern","args":{"regex":"/^[A-Za-z0-9_-]{16,128}$/"}}]} |
| title | string | no | {"rules":[{"name":"trim","args":{"enabled":true}},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":120}}]} |
| productId | string | no | {"rules":[{"name":"hex","args":{"options":{"byteAligned":false,"prefix":false}}},{"name":"length","args":{"limit":24}}]} |
| productIds | array | no | {"rules":[{"name":"unique"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":20}}],"items":[{"type":"string","flags":{"presence":"required"},"rules":[{"name":"hex","args":{"options":{"byteAligned":false,"prefix":false}}},{"name":"length","args":{"limit":24}}]}]} |
| firstMessage | string | yes | {"rules":[{"name":"trim","args":{"enabled":true}},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":4000}}]} |

Field combinations: [{"rel":"oxor","peers":["productId","productIds"]}].

### Request example

`POST /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/discussions`

```json
{
  "operationId": "discussion_example_01",
  "title": "Ring enquiry",
  "firstMessage": "Are these pieces available?"
}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439013",
  "relationshipId": "507f1f77bcf86cd799439011",
  "title": "Ring enquiry",
  "status": "open",
  "closedBy": null,
  "closedAt": null,
  "product": null,
  "products": [],
  "liveProductAvailable": null,
  "handlerUserId": null,
  "canTakeover": false,
  "unanswered": false,
  "unreadCount": 0,
  "lastMessage": {
    "id": "507f1f77bcf86cd799439014",
    "discussionId": "507f1f77bcf86cd799439013",
    "relationshipId": "507f1f77bcf86cd799439011",
    "author": {
      "userId": "507f1f77bcf86cd799439011",
      "sideId": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    "body": "Are these pieces available?",
    "photos": [],
    "createdAt": "2026-11-10T10:00:00.000Z",
    "removed": false,
    "otherSideReceipt": {
      "delivered": false,
      "read": false
    },
    "reply": null
  },
  "createdAt": "2026-11-10T10:00:00.000Z"
}
```

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

### Endpoint errors

```json
{
  "error": {
    "code": "MESSAGE_EMPTY",
    "message": "MESSAGE_EMPTY"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |
| 409 | IDEMPOTENCY_CONFLICT | Operation ID reused for different content/destination | Restore original payload or deliberately create a new operation |
| 404 | PRODUCT_NOT_FOUND | Product absent/deleted/pending/declined/wrong counterpart | Choose a permitted live product |
| 400 | PRODUCT_STORE_MISMATCH | Selected enquiry products belong to different stores | Send a separate enquiry to each store |
| 403 | STORE_PRIVATE | Actor lacks private catalogue access | Obtain approval independently of chat |
| 403 | LOCKED_PRODUCT | Actor lacks locked product access | Request catalogue approval |
| 400 | MESSAGE_EMPTY | Introductory text empty | Supply text |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/relationships/:relationshipId/discussions

List permitted discussions; pending customer sees introductory discussion only. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: relationshipId (24 hexadecimal ObjectId characters).

### Query fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| cursor | string | no | {"rules":[{"name":"max","args":{"limit":3000}}]} |
| limit | number | no | {"default":20,"rules":[{"name":"integer"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":50}}]} |
| status | string | no | {"allowed":["open","closed"]} |

### Request example

`GET /v1/catalog/chat/relationships/507f1f77bcf86cd799439011/discussions?limit=20`

No request body.

### Success example and variants

```json
{
  "items": [
    {
      "id": "507f1f77bcf86cd799439013",
      "relationshipId": "507f1f77bcf86cd799439011",
      "title": "Ring enquiry",
      "status": "open",
      "closedBy": null,
      "closedAt": null,
      "product": null,
      "products": [],
      "liveProductAvailable": null,
      "handlerUserId": null,
      "canTakeover": false,
      "unanswered": false,
      "unreadCount": 0,
      "lastMessage": {
        "id": "507f1f77bcf86cd799439014",
        "discussionId": "507f1f77bcf86cd799439013",
        "relationshipId": "507f1f77bcf86cd799439011",
        "author": {
          "userId": "507f1f77bcf86cd799439011",
          "sideId": "personal:507f1f77bcf86cd799439011",
          "name": "Ananya",
          "isViewerSide": true
        },
        "body": "Is this available?",
        "photos": [],
        "createdAt": "2026-11-10T10:00:00.000Z",
        "removed": false,
        "otherSideReceipt": {
          "delivered": false,
          "read": false
        },
        "reply": null
      },
      "createdAt": "2026-11-10T10:00:00.000Z"
    }
  ],
  "nextCursor": null
}
```

Lists may be empty. Pagination is a bounded scan; filtered inbox/work pages may be empty with a next cursor. Continue until the cursor is null. Sync instead uses `hasMore` and retains its last cursor even when no more events exist.

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_NOT_FOUND",
    "message": "CHAT_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 400 | INVALID_CURSOR | Invalid/tampered/wrong-view/profile cursor | Discard cursor and reload that list |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/discussions/:discussionId

Discussion, own-store handler, unanswered status and unread count. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: discussionId (24 hexadecimal ObjectId characters).


### Request example

`GET /v1/catalog/chat/discussions/507f1f77bcf86cd799439013`

No request body.

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439013",
  "relationshipId": "507f1f77bcf86cd799439011",
  "title": "Ring enquiry",
  "status": "open",
  "closedBy": null,
  "closedAt": null,
  "product": null,
  "products": [],
  "liveProductAvailable": null,
  "handlerUserId": null,
  "canTakeover": false,
  "unanswered": false,
  "unreadCount": 0,
  "lastMessage": {
    "id": "507f1f77bcf86cd799439014",
    "discussionId": "507f1f77bcf86cd799439013",
    "relationshipId": "507f1f77bcf86cd799439011",
    "author": {
      "userId": "507f1f77bcf86cd799439011",
      "sideId": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    "body": "Is this available?",
    "photos": [],
    "createdAt": "2026-11-10T10:00:00.000Z",
    "removed": false,
    "otherSideReceipt": {
      "delivered": false,
      "read": false
    },
    "reply": null
  },
  "createdAt": "2026-11-10T10:00:00.000Z"
}
```

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_NOT_FOUND",
    "message": "CHAT_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## PATCH /v1/catalog/chat/discussions/:discussionId

Rename or explicitly close/reopen discussion. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: discussionId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| title | string | no | {"rules":[{"name":"trim","args":{"enabled":true}},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":120}}]} |
| status | string | no | {"allowed":["open","closed"]} |

### Request example

`PATCH /v1/catalog/chat/discussions/507f1f77bcf86cd799439013`

```json
{
  "status": "closed"
}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439013",
  "relationshipId": "507f1f77bcf86cd799439011",
  "title": "Ring enquiry",
  "status": "closed",
  "closedBy": "507f1f77bcf86cd799439011",
  "closedAt": "2026-11-10T10:00:00.000Z",
  "product": null,
  "products": [],
  "liveProductAvailable": null,
  "handlerUserId": null,
  "canTakeover": false,
  "unanswered": false,
  "unreadCount": 0,
  "lastMessage": {
    "id": "507f1f77bcf86cd799439014",
    "discussionId": "507f1f77bcf86cd799439013",
    "relationshipId": "507f1f77bcf86cd799439011",
    "author": {
      "userId": "507f1f77bcf86cd799439011",
      "sideId": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    "body": "Is this available?",
    "photos": [],
    "createdAt": "2026-11-10T10:00:00.000Z",
    "removed": false,
    "otherSideReceipt": {
      "delivered": false,
      "read": false
    },
    "reply": null
  },
  "createdAt": "2026-11-10T10:00:00.000Z"
}
```

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_REQUEST_PENDING",
    "message": "CHAT_REQUEST_PENDING"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/discussions/:discussionId/messages

Append public text/photo/reply; acknowledge only after commit. **Authority:** Authenticated selected profile. **Success:** 201.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: discussionId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| operationId | string | yes | {"rules":[{"name":"pattern","args":{"regex":"/^[A-Za-z0-9_-]{16,128}$/"}}]} |
| text | string | no | {"allowed":[""],"rules":[{"name":"trim","args":{"enabled":true}},{"name":"max","args":{"limit":4000}}]} |
| photoIds | array | no | {"rules":[{"name":"unique"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":4}}],"items":[{"type":"string","flags":{"presence":"required"},"rules":[{"name":"hex","args":{"options":{"byteAligned":false,"prefix":false}}},{"name":"length","args":{"limit":24}}]}]} |
| replyToId | string | no | {"rules":[{"name":"hex","args":{"options":{"byteAligned":false,"prefix":false}}},{"name":"length","args":{"limit":24}}]} |

At least nonblank text or one photoId is required; duplicate photo IDs are rejected. Unknown fields (including visibility, author/profile overrides and quantity) are rejected.

### Request example

`POST /v1/catalog/chat/discussions/507f1f77bcf86cd799439013/messages`

```json
{
  "operationId": "message_example_01",
  "text": "Is this available?"
}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439014",
  "discussionId": "507f1f77bcf86cd799439013",
  "relationshipId": "507f1f77bcf86cd799439011",
  "author": {
    "userId": "507f1f77bcf86cd799439011",
    "sideId": "personal:507f1f77bcf86cd799439011",
    "name": "Ananya",
    "isViewerSide": true
  },
  "body": "Is this available?",
  "photos": [],
  "createdAt": "2026-11-10T10:00:00.000Z",
  "removed": false,
  "otherSideReceipt": {
    "delivered": false,
    "read": false
  },
  "reply": null
}
```

Messages may contain photo references, an authorized reply, or a removed marker with null body and empty photos. Outgoing otherSideReceipt is an aggregate; incoming messages have null. There is no raw internal sequence or customer/staff phone field. Normal delivery does not mark read.

### Endpoint errors

```json
{
  "error": {
    "code": "REPLY_NOT_FOUND",
    "message": "REPLY_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |
| 409 | DISCUSSION_CLOSED | Sending/uploading while closed | Customer/store explicitly reopens first |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |
| 400 | MESSAGE_EMPTY | Introductory text empty | Supply text |
| 409 | IDEMPOTENCY_CONFLICT | Operation ID reused for different content/destination | Restore original payload or deliberately create a new operation |
| 409 | PHOTO_UNAVAILABLE | Wrong actor/discussion, expired, consumed, unfinished or cleanup-leased upload | Upload again for original actor/discussion |
| 404 | REPLY_NOT_FOUND | Referenced message not in this discussion | Choose a permitted message |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/discussions/:discussionId/messages

Newest-first bounded message history. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: discussionId (24 hexadecimal ObjectId characters).

### Query fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| cursor | string | no | {"rules":[{"name":"max","args":{"limit":3000}}]} |
| limit | number | no | {"default":20,"rules":[{"name":"integer"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":50}}]} |

### Request example

`GET /v1/catalog/chat/discussions/507f1f77bcf86cd799439013/messages?limit=20`

No request body.

### Success example and variants

```json
{
  "items": [
    {
      "id": "507f1f77bcf86cd799439014",
      "discussionId": "507f1f77bcf86cd799439013",
      "relationshipId": "507f1f77bcf86cd799439011",
      "author": {
        "userId": "507f1f77bcf86cd799439011",
        "sideId": "personal:507f1f77bcf86cd799439011",
        "name": "Ananya",
        "isViewerSide": true
      },
      "body": "Is this available?",
      "photos": [],
      "createdAt": "2026-11-10T10:00:00.000Z",
      "removed": false,
      "otherSideReceipt": {
        "delivered": false,
        "read": false
      },
      "reply": null
    }
  ],
  "nextCursor": null
}
```

Lists may be empty. Pagination is a bounded scan; filtered inbox/work pages may be empty with a next cursor. Continue until the cursor is null. Sync instead uses `hasMore` and retains its last cursor even when no more events exist.

Messages may contain photo references, an authorized reply, or a removed marker with null body and empty photos. Outgoing otherSideReceipt is an aggregate; incoming messages have null. There is no raw internal sequence or customer/staff phone field. Normal delivery does not mark read.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_NOT_FOUND",
    "message": "CHAT_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 400 | INVALID_CURSOR | Invalid/tampered/wrong-view/profile cursor | Discard cursor and reload that list |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/discussions/:discussionId/receipt

Monotonic delivered/read acknowledgement for selected viewing side. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: discussionId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| messageId | string | yes | {"rules":[{"name":"hex","args":{"options":{"byteAligned":false,"prefix":false}}},{"name":"length","args":{"limit":24}}]} |
| state | string | yes | {"allowed":["delivered","read"]} |

### Request example

`POST /v1/catalog/chat/discussions/507f1f77bcf86cd799439013/receipt`

```json
{
  "messageId": "507f1f77bcf86cd799439013",
  "state": "read"
}
```

### Success example and variants

```json
{
  "success": true
}
```

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_REQUEST_PENDING",
    "message": "CHAT_REQUEST_PENDING"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 404 | MESSAGE_NOT_FOUND | Receipt target not in this discussion | Refresh history |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/discussions/:discussionId/takeover

Explicitly claim store-side responsibility. **Authority:** Selected store member. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: discussionId (24 hexadecimal ObjectId characters).

### Body fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |

### Request example

`POST /v1/catalog/chat/discussions/507f1f77bcf86cd799439013/takeover`

```json
{}
```

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439013",
  "relationshipId": "507f1f77bcf86cd799439011",
  "title": "Ring enquiry",
  "status": "open",
  "closedBy": null,
  "closedAt": null,
  "product": null,
  "products": [],
  "liveProductAvailable": null,
  "handlerUserId": "507f1f77bcf86cd799439012",
  "canTakeover": false,
  "unanswered": false,
  "unreadCount": 0,
  "lastMessage": {
    "id": "507f1f77bcf86cd799439014",
    "discussionId": "507f1f77bcf86cd799439013",
    "relationshipId": "507f1f77bcf86cd799439011",
    "author": {
      "userId": "507f1f77bcf86cd799439011",
      "sideId": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": true
    },
    "body": "Is this available?",
    "photos": [],
    "createdAt": "2026-11-10T10:00:00.000Z",
    "removed": false,
    "otherSideReceipt": {
      "delivered": false,
      "read": false
    },
    "reply": null
  },
  "createdAt": "2026-11-10T10:00:00.000Z"
}
```

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_REQUEST_PENDING",
    "message": "CHAT_REQUEST_PENDING"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 403 | STORE_PROFILE_REQUIRED | Personal attempted a store-only operation | Switch explicitly; never retarget pending work |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/work

Store-side unanswered open discussions; no timed escalation. **Authority:** Selected store member. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.

### Query fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| cursor | string | no | {"rules":[{"name":"max","args":{"limit":3000}}]} |
| limit | number | no | {"default":20,"rules":[{"name":"integer"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":50}}]} |

### Request example

`GET /v1/catalog/chat/work?limit=20`

No request body.

### Success example and variants

```json
{
  "items": [
    {
      "id": "507f1f77bcf86cd799439013",
      "relationshipId": "507f1f77bcf86cd799439011",
      "title": "Ring enquiry",
      "status": "open",
      "closedBy": null,
      "closedAt": null,
      "product": null,
      "products": [],
      "liveProductAvailable": null,
      "handlerUserId": "507f1f77bcf86cd799439012",
      "canTakeover": false,
      "unanswered": true,
      "unreadCount": 0,
      "lastMessage": {
        "id": "507f1f77bcf86cd799439014",
        "discussionId": "507f1f77bcf86cd799439013",
        "relationshipId": "507f1f77bcf86cd799439011",
        "author": {
          "userId": "507f1f77bcf86cd799439011",
          "sideId": "personal:507f1f77bcf86cd799439011",
          "name": "Ananya",
          "isViewerSide": true
        },
        "body": "Is this available?",
        "photos": [],
        "createdAt": "2026-11-10T10:00:00.000Z",
        "removed": false,
        "otherSideReceipt": {
          "delivered": false,
          "read": false
        },
        "reply": null
      },
      "createdAt": "2026-11-10T10:00:00.000Z"
    }
  ],
  "nextCursor": null
}
```

Lists may be empty. Pagination is a bounded scan; filtered inbox/work pages may be empty with a next cursor. Continue until the cursor is null. Sync instead uses `hasMore` and retains its last cursor even when no more events exist.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_NOT_FOUND",
    "message": "CHAT_NOT_FOUND"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_CURSOR | Invalid/tampered/wrong-view/profile cursor | Discard cursor and reload that list |
| 403 | STORE_PROFILE_REQUIRED | Personal attempted a store-only operation | Switch explicitly; never retarget pending work |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## POST /v1/catalog/chat/discussions/:discussionId/photos

Upload one JPEG/PNG/WebP; normalize, encrypt, bind to actor; no public plaintext URL. **Authority:** Authenticated selected profile. **Success:** 201.

Headers: Authorization and explicit profile above; let the multipart client supply its boundary. Path parameters: discussionId (24 hexadecimal ObjectId characters).


### Request example

`POST /v1/catalog/chat/discussions/507f1f77bcf86cd799439013/photos`

Multipart field `photo`: a local JPEG/PNG/WebP file, at most 8 MiB by default. No additional form fields.

### Success example and variants

```json
{
  "id": "507f1f77bcf86cd799439015",
  "width": 1080,
  "height": 1080,
  "bytes": 125000,
  "expiresAt": "2026-11-11T10:00:00.000Z",
  "url": "/v1/catalog/chat/photos/507f1f77bcf86cd799439015"
}
```

Discussion variants include general/product-linked, open/closed, own-store handler/unanswered, unread count and lastMessage (nullable). Product snapshots contain authorized descriptive fields, never catalogue storage URLs; liveProductAvailable may become false. P1 does not copy a permanent product photo into the card. Fetch live media only through authorized catalogue access, or use explicitly shared chat photos.

Normalize JPEG/PNG/WebP to WebP, remove metadata, limit pixels/dimensions and encrypt before object storage. Unattached uploads expire after 24 hours and are cleaned up; only original user/profile/discussion can attach once. Attachment consumption and message commit are atomic. An upload timeout has no operation-id guarantee: retrying may create another unattached photo, which cleanup handles.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_MEDIA_BUSY",
    "message": "CHAT_MEDIA_BUSY"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 503 | CHAT_READ_ONLY | Writes disabled for rollout/recovery | Keep reads; do not spin retries |
| 409 | CHAT_CONFLICT | Unique/write conflict escaped retry | Fetch state and retry same operation deliberately |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 503 | CHAT_MEDIA_UNAVAILABLE | Object storage/integrity failure | Retry authorized retrieval/upload later |
| 409 | PHOTO_UNAVAILABLE | Wrong actor/discussion, expired, consumed, unfinished or cleanup-leased upload | Upload again for original actor/discussion |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 403 | CHAT_BLOCKED | Either side blocks communication | Show blocked state; only own block can be removed |
| 409 | CHAT_ACCOUNT_DELETED | Original customer or participating store deleted | Show historical read-only view |
| 409 | DISCUSSION_CLOSED | Sending/uploading while closed | Customer/store explicitly reopens first |
| 409 | CHAT_REQUEST_PENDING | Conversation not accepted or introductory allowance used | Accept/await acceptance; do not send photos |
| 400 | INVALID_CHAT_PHOTO | Invalid JPEG/PNG/WebP, multipart, dimensions or size | Use one valid photo within advertised limits |
| 503 | CHAT_MEDIA_NOT_CONFIGURED | Required encryption key version missing | Wait for operator configuration; never use a public fallback |
| 503 | CHAT_MEDIA_BUSY | Per-process photo processing capacity reached | Respect Retry-After and retry with backoff |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/photos/:photoId

Authenticated no-store WebP response; ciphertext never returned. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: photoId (24 hexadecimal ObjectId characters).


### Request example

`GET /v1/catalog/chat/photos/507f1f77bcf86cd799439015`

No request body.

### Success example and variants

`200 Content-Type: image/webp`, `Cache-Control: private, no-store`; binary normalized image bytes, not JSON or a permanent URL.

### Endpoint errors

```json
{
  "error": {
    "code": "CHAT_MEDIA_BUSY",
    "message": "CHAT_MEDIA_BUSY"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | INVALID_ID | Malformed path ObjectId | Use actual resource ID |
| 404 | PHOTO_NOT_FOUND | Photo missing, removed, unshared or inaccessible | Show unavailable image |
| 404 | DISCUSSION_NOT_FOUND | Missing/unavailable discussion or request-only restriction | Refresh permitted discussions |
| 404 | CHAT_NOT_FOUND | Not a relationship participant or missing relationship | Refresh own list; do not probe other IDs |
| 503 | CHAT_MEDIA_NOT_CONFIGURED | Required encryption key version missing | Wait for operator configuration; never use a public fallback |
| 503 | CHAT_MEDIA_UNAVAILABLE | Object storage/integrity failure | Retry authorized retrieval/upload later |
| 503 | CHAT_MEDIA_BUSY | Per-process photo processing capacity reached | Respect Retry-After and retry with backoff |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## GET /v1/catalog/chat/sync

Durable oldest-first event recovery; retain cursor even on an empty final page. **Authority:** Authenticated selected profile. **Success:** 200.

Headers: Authorization and explicit profile above; Content-Type application/json for bodies. Path parameters: none.

### Query fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| cursor | string | no | {"rules":[{"name":"max","args":{"limit":3000}}]} |
| limit | number | no | {"default":20,"rules":[{"name":"integer"},{"name":"min","args":{"limit":1}},{"name":"max","args":{"limit":50}}]} |

### Request example

`GET /v1/catalog/chat/sync?limit=20`

No request body.

### Success example and variants

```json
{
  "items": [
    {
      "id": "507f1f77bcf86cd799439014",
      "type": "message.created",
      "relationshipId": "507f1f77bcf86cd799439011",
      "discussionId": "507f1f77bcf86cd799439013",
      "profileId": "personal:507f1f77bcf86cd799439011",
      "occurredAt": "2026-11-10T10:00:00.000Z",
      "message": {
        "id": "507f1f77bcf86cd799439014",
        "discussionId": "507f1f77bcf86cd799439013",
        "relationshipId": "507f1f77bcf86cd799439011",
        "author": {
          "userId": "507f1f77bcf86cd799439011",
          "sideId": "personal:507f1f77bcf86cd799439011",
          "name": "Ananya",
          "isViewerSide": true
        },
        "body": "Is this available?",
        "photos": [],
        "createdAt": "2026-11-10T10:00:00.000Z",
        "removed": false,
        "otherSideReceipt": {
          "delivered": false,
          "read": false
        },
        "reply": null
      }
    }
  ],
  "hasMore": false,
  "cursor": "<opaque-encrypted-cursor>"
}
```

Lists may be empty. Pagination is a bounded scan; filtered inbox/work pages may be empty with a next cursor. Continue until the cursor is null. Sync instead uses `hasMore` and retains its last cursor even when no more events exist.

### Endpoint errors

```json
{
  "error": {
    "code": "INVALID_CURSOR",
    "message": "INVALID_CURSOR"
  }
}
```

| HTTP | Application code | Trigger | Client action |
| --- | --- | --- | --- |
| 401 | AUTH_REQUIRED | Person missing/unverified/deleted or no Bearer token | Sign in again |
| 401 | INVALID_ACCESS_TOKEN | Invalid/expired access JWT | Refresh once or sign in |
| 401 | SESSION_REVOKED | No active session in token family | Sign in again |
| 403 | DEVICE_ID_MISMATCH | Installation differs from session binding | Use the bound installation or sign in on this device |
| 403 | PROFILE_ACCESS_REMOVED | Store/profile no longer available | Remove local access; choose a valid profile |
| 400 | INVALID_PROFILE_ID | Malformed/unavailable Personal selector | Use bootstrap profile IDs |
| 400 | INVALID_DEVICE_ID | Invalid installation format | Correct installation ID |
| 403 | PROFILE_REQUIRED | Personal name not completed | Complete name through Catalog /me |
| 409 | PROFILE_CONTEXT_REQUIRED | Explicit profile header omitted | Select profile; never infer first store |
| 403 | MEMBERSHIP_REQUIRED | Store membership lost during request | Refresh profiles and disable queued store actions |
| 429 | RATE_LIMITED | Fixed-window read/write/outreach/upload budget exceeded | Respect Retry-After response header |
| 503 | CATALOG_NOT_READY | Database/index setup incomplete | Retry after operational recovery |
| 500 | INTERNAL_ERROR | Unexpected dependency failure | Treat mutation outcome as uncertain; retry original operation ID |
| 503 | CHAT_DISABLED | Feature flag off | Hide chat; retain upgrade-compatible state |
| 400 | VALIDATION_ERROR | Body/query field or combination rejected | Correct error.details fields |
| 400 | INVALID_CURSOR | Invalid/tampered/wrong-view/profile cursor | Discard cursor and reload that list |

**Profile effects and retry:** the header fixes the actor. Switching does not retarget this operation. Only message/discussion operation IDs deduplicate creation; receipt $max, block sets and same-outcome decisions are idempotent. Recheck state before retrying other uncertain mutations. Authorization is revalidated on every call.

## Socket.IO contract

Namespace `/v1/catalog/chat`; Engine.IO transport path remains `/socket.io`. WebSocket transport is enabled by the existing server. No guest access. Handshake auth:

```json
{
  "token": "<accessToken>",
  "profileId": "store:507f1f77bcf86cd799439012",
  "deviceId": "installation_flutter_01"
}
```

Connection errors use Socket.IO connect_error with `message: Chat connection rejected` and `data.code` from Catalog authentication/profile checks; an unexpected dependency error uses INTERNAL_ERROR. JWT expiry disconnects the namespace. Refresh and reconnect with the selected original profile. A namespace disconnect does not require logging out every other profile/device.

| Direction/event | Payload / ack | Behavior |
| --- | --- | --- |
| Client chat.watch | `{discussionId}`; ack `{success:true,discussionId,expiresAt}` | Authorizes before watching; up to 20 IDs, 120 watch attempts/minute; foreground lease lasts 45 seconds. Renew every 30 seconds while actually viewing. |
| Client chat.unwatch | `{discussionId}`; ack `{success:true}` | Drop watch when leaving/backgrounding. |
| Server chat.event | Event below | Actor-specific live update; deduplicate by event ID and message ID; replay may repeat it. |
| Server chat.access_revoked | `{code}` | Drop inaccessible profile state and reconnect only after valid bootstrap. |

Watch ack errors use `{error:{code,message}}` for INVALID_ID, DISCUSSION_NOT_FOUND, CHAT_NOT_FOUND, CHAT_WATCH_LIMIT, RATE_LIMITED and authentication/profile loss. There is no socket send/read/typing command in P1: durable mutations and receipts use HTTP. Watching/receiving is not reading.

```json
{
  "id": "507f1f77bcf86cd799439014",
  "type": "message.created",
  "relationshipId": "507f1f77bcf86cd799439011",
  "discussionId": "507f1f77bcf86cd799439013",
  "profileId": "store:507f1f77bcf86cd799439012",
  "occurredAt": "2026-11-10T10:00:00.000Z",
  "message": {
    "id": "507f1f77bcf86cd799439014",
    "discussionId": "507f1f77bcf86cd799439013",
    "relationshipId": "507f1f77bcf86cd799439011",
    "author": {
      "userId": "507f1f77bcf86cd799439011",
      "sideId": "personal:507f1f77bcf86cd799439011",
      "name": "Ananya",
      "isViewerSide": false
    },
    "body": "Is this available?",
    "photos": [],
    "createdAt": "2026-11-10T10:00:00.000Z",
    "removed": false,
    "otherSideReceipt": null,
    "reply": null
  }
}
```

Event types: relationship.updated, discussion.updated, message.created, receipt.updated, profile.invalidated, message.removed. The first four and message.removed include relationshipId and nullable discussionId; message events include the current authorized message. profile.invalidated contains only id/type/profileId/occurredAt and tells eligible remaining clients to refresh; revoked sockets instead receive access_revoked and disconnect. No private fields or arbitrary author overrides are accepted. Events invalidate local views; re-fetch affected discussion/list when no complete object is included. GET /sync recovers durable events with the same authorization and encrypted profile-bound cursor.

Delivery is at least once across retries, not exactly once at external push providers. Stable event IDs support client deduplication. Pending customer requests do not reveal unsent draft discussions/events. Store receipt is any authorized staff reader, not all staff. Offline sockets recover through HTTP; Redis Pub/Sub is not the history store.
