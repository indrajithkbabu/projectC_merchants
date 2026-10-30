# BE verify — test scenarios + logs

Backend said the gaps in `BACKEND_HANDOFF.md` and `PRODUCT_DETAILS_BACKEND.md`
are fixed. Use these flows to confirm. **Do not change product logic** — only
observe UI + filtered logs.

---

## Log filter

| Tool | Filter |
|------|--------|
| Android Studio Logcat | `BeVerify` |
| `flutter logs` / terminal | `BeVerify` |
| Chrome / DevTools console | `BeVerify` |

Debug builds only (`kDebugMode`). Lines look like:

```text
[BeVerify] ==== 1 GET /products/:id ====
[BeVerify] PASS liked+wishlisted present | liked=true wishlisted=false
[BeVerify] FAIL wishlist product:null still present | …
```

**PASS** = BE looks good for that check. **FAIL** = still broken / fallback.
**INFO** = expected alternate path (e.g. collection id → product 404 → collection).

Paste a `BeVerify` slice when reporting results.

---

## Prep

1. Run a **debug** build (release strips these prints).
2. Sign in (JWT required for liked/wishlisted / wishlist / availability / wastage).
3. Have: own store with ≥1 multi-photo listing, ≥1 single product, another
   account (or second device) for like → activity.

---

## Scenario A — Authed `liked` + `wishlisted` (handoff §1)

**Flow**
1. Sign in as viewer.
2. Open a product you have **not** wishlisted (heart off).
3. Open a product you **have** wishlisted (if any).
4. Thumbs-up a product, leave, reopen — thumbs-up should stay on from GET.

**Expect UI**
- Thumbs-up matches prior public like.
- Heart matches wishlist without needing a separate wishlist fetch flash.

**Expect logs**
```text
[BeVerify] ==== 1 GET /products/:id ====
[BeVerify] PASS liked+wishlisted present | liked=… wishlisted=…
[BeVerify] PASS details hydrate from product GET | …
```

**Fail if**
```text
[BeVerify] FAIL liked+wishlisted missing on authed GET
[BeVerify] FAIL wishlisted omitted — using cache fallback
```

---

## Scenario B — Collection id vs product id (details §1)

**Flow**
1. From store grid, open a **multi-photo collection** card (listing id =
   collection id).
2. Details should still open (FE falls back).

**Expect logs**
```text
[BeVerify] INFO GET product miss | code=PRODUCT_NOT_FOUND …
[BeVerify] INFO product GET → collection fallback | …
[BeVerify] ==== PD collection detail ====
```

No crash; photos/specs load from collection detail.

---

## Scenario C — Thumbhash after batch create (handoff §2)

**Flow**
1. Own store → add products → publish/batch create with photos.
2. Watch logs during upload finish.
3. Cold reopen store profile / product details (kill app optional).

**Expect logs (ideal)**
```text
[BeVerify] ==== 2 batch thumbhash ====
[BeVerify] PASS thumbhash from server batch response
```

On later GET product/collection:
```text
[BeVerify] PASS product images thumbhash | YES=N NULL=0
```
or collection detail `thumbhashNULL=0`.

**Fail if**
```text
[BeVerify] FAIL thumbhash missing on batch response — FE merged local
[BeVerify] FAIL … GAP_THUMBHASH_NULL
```
(Local merge still makes Instant UI work; cold start / other devices need server.)

---

## Scenario D — Availability PATCH product ids (handoff §3 / details §2)

**Flow**
1. Own store → open multi-photo listing → overflow → Availability.
2. Toggle lock and/or stock → save.
3. Back to store grid — chrome should match.
4. Reopen details — lock/stock still correct.

**Expect logs**
```text
[BeVerify] ==== 3 Availability UI ====
[BeVerify] PASS availability uses embedded product ids (not collection id)
[BeVerify] ==== 3 PATCH /products/:id availability ====
[BeVerify] PASS availability PATCH | stock=… locked=…
[BeVerify] PASS availability applied locally | … pop updated=true
```

**Fail if** PATCH uses collection id → `PRODUCT_NOT_FOUND`, or grid reverts.

**Optional:** Re-fetch collection; if collection-level `is_locked` still false
while products are locked, note it (nice-to-have; FE ORs product locks).

---

## Scenario E — Store wastage markup (handoff §3b)

**Flow**
1. Account → privacy / store defaults → set wastage % → save.
2. Re-open store defaults (or GET store path that shows markup).

**Expect logs**
```text
[BeVerify] ==== 3b PATCH wastage-markup ====
[BeVerify] PASS wastage-markup | defaultWastageMarkup=12.0
```

**Fail if** `defaultWastageMarkup` missing on response.

---

## Scenario F — Activity `product_liked` (handoff §4a)

**Flow**
1. Account B likes a product on Account A’s store (public thumbs-up).
2. Account A opens Activity.
3. Tap the like row → own store focuses that product.

**Expect logs** (when feed parses)
```text
[BeVerify] PASS 4a product_liked | entity=… actor=… msg=true/false
```

**Fail if** `product_liked incomplete` (missing entity/actor).  
Wishlist must **not** create activity.

---

## Scenario G — Import stubs (handoff §4b)

**Flow**
1. Open Import requests (incoming/outgoing) on own store.

**Expect logs**
```text
[BeVerify] PASS 4b import stubs | direction=incoming items=0 (HTTP 200 path)
```

**Fail if**
```text
[BeVerify] FAIL 4b import stubs still 404/disabled
```
(FE still shows empty; BE should return 200 + `items: []`.)

---

## Scenario H — Wishlist sets `product` (handoff §5 — former blocker)

**Flow**
1. Sign in → open product → tap **heart** (wishlist — not thumbs-up).
2. Heart again (idempotent).
3. Open Wishlist screen — item appears.
4. Remove heart → add again.

**Expect logs**
```text
[BeVerify] ==== 5 POST /wishlist/products/:id ====
[BeVerify] PASS wishlist path POST | wishlisted=true already=false …
```
Second tap:
```text
[BeVerify] PASS wishlist idempotent 409 | alreadyWishlisted …
```
or `already=true` on 200.

**Fail if**
```text
[BeVerify] FAIL wishlist product:null still present
```
(That is the old Mongo `user_1_product_1` / `product: null` bug.)

---

## Scenario I — Specs / wastage_pct (details §3)

**Flow**
1. Open product with weight + wastage set by merchant.
2. Open product with weight but wastage unset.

**Expect logs** on GET
```text
[BeVerify] INFO wastage_pct | 4   // or numeric
[BeVerify] INFO wastage_pct | null (Fine→Gross)
```

UI: Fine line when wastage present; Gross when null.

---

## Quick checklist

| # | Scenario | Pass signal in `BeVerify` |
|---|----------|---------------------------|
| 1 | liked + wishlisted on GET | `PASS liked+wishlisted present` |
| 2 | Thumbhash persisted | `PASS thumbhash from server` / `NULL=0` |
| 3a | Availability PATCH | `PASS availability PATCH` + grid sync |
| 3b | Wastage markup | `PASS wastage-markup` |
| 4a | product_liked | `PASS 4a product_liked` |
| 4b | Import stubs | `PASS 4b import stubs` (200) |
| 5 | Wishlist product field | `PASS wishlist path POST` (no product:null) |

When done, paste filtered `BeVerify` output per scenario (A–H) and mark Pass/Fail.
