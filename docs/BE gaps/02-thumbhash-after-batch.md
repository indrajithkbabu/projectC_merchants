# 02 — Thumbhash persisted after batch create

**Status:** Confirm  
**Index:** [README.md](./README.md)

---

## Ask

Batch create (`POST …/products/batch`) and later GETs should keep client-supplied
(or server-computed) fields on each image:

```json
{
  "images": [
    {
      "imageId": "img_…",
      "url": "https://…",
      "thumbhash": "<non-null base64>",
      "width": 978,
      "height": 1280
    }
  ]
}
```

If the sign session already stored thumbhash/bytes, copy them onto product image
docs at commit time.

---

## FE today

Merges local ThumbHashes after upload for the current session only. Cold start /
other devices need server-persisted hashes.

---

## Acceptance

- [ ] Non-null `thumbhash` on images after batch when client sent one
- [ ] Width/height retained on GET product / store products / collection cover
