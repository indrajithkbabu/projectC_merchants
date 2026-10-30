# 10 — Store `followStatus` naming

**Status:** Confirm / Document  
**Index:** [README.md](./README.md)

---

## Ask

Docs / payloads may use `active` vs `following`. FE maps both → following.
Prefer one canonical value in docs and responses.

---

## FE today

Maps `active` and `following` → following UI state.

---

## Acceptance

- [ ] Docs and GET store agree on one canonical value
- [ ] Or both aliases stay documented forever
