# 06 — Import stubs

**Status:** Confirm  
**Index:** [README.md](./README.md)

---

## Ask

Keep import-request stubs as **HTTP 200** with empty `items` on **all**
environments. Avoid `404` / “disabled” so older clients stay quiet.

---

## FE today

Treats `404` / message containing `disabled` as empty (no error snackbar).

---

## Acceptance

- [ ] Stub endpoints return **200** + empty list on prod and test
- [ ] No `404` for “not implemented yet” stubs
