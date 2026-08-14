# NovelDrama plugin

Novel source for [noveldrama.org](https://noveldrama.org).

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `selectors.json` | CSS selectors for search, chapter list and chapter content |
| `filters.json` | Content cleaner tweaks (ad blocks, chapter nav) |
| `permissions.json` | Rate-limit / politeness tuning |
| `tests/fixtures/*.html` | Recorded pages for CI smoke tests |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Notes

NovelDrama is a novelfull-family clone (same `#rating[data-novel-id]` novel-id
fingerprint and `data-chapter-item` template-wrapped chapter archive), so it
ships as a **data-only** plugin on top of the existing `novelfull` template —
no code change, only a `selectors.json` pointing at this site's markup:

* **Search** — `/search?keyword=` with results in `#list-page .row`.
* **Chapter list** — the complete archive is fetched from the site's own
  `/ajax/chapter-archive?novelId=...` endpoint, which returns template-wrapped
  `<li data-chapter-item>` items (visible to the DOM parser).
* **Chapter content** — body in `#chapter` with the title in `.chr-title`.
* **Metadata** — the og:novel tags and `.col-info-desc` info rows are pulled
  by the `novelfull` template's shared metadata extraction.

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
dart run tool/generate_plugin_catalog.dart   # refresh index.json checksums
```