# 04 — Store wastage markup + product `wastage_pct`

**Status:** Confirm  
**Index:** [README.md](./README.md)

---

## Ask

```http
PATCH /v1/catalog/stores/:storeId/wastage-markup
```

```json
{ "wastageMarkup": 12.0 }
```

- Response / `GET /stores/:storeId` should expose `defaultWastageMarkup`.
- Prefer non-null `wastage_pct` on products when weight is set (Fine weight UX);
  FE shows Gross when wastage is null.
- Specs on collection detail are flat (`defaults` + per-product fields), not a
  nested `specifications` object — keep that stable.

---

## FE today

Account privacy → Store defaults UI wired; reads `defaultWastageMarkup` from
store GET.

---

## Acceptance

- [ ] wastage-markup PATCH returns store or new `defaultWastageMarkup`
- [ ] Store GET includes `defaultWastageMarkup`
- [ ] Product / collection detail keep flat `wastage_pct` when set
