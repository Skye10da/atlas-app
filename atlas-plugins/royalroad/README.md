# Royal Road plugin

Novel source for [Royal Road](https://www.royalroad.com).

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `selectors.json` | CSS selectors for search and chapter content |
| `filters.json` | Content cleaner tweaks |
| `permissions.json` | Rate-limit / politeness tuning |
| `tests/fixtures/*.html` | Recorded pages for CI smoke tests |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Notes

Royal Road ships a bespoke template (`royalroad`) because its chapter index is
only fully available as a `window.chapters` JSON array inline in the fiction
page — a thing CSS selectors cannot express:

* **Chapter list** — prefers `window.chapters` (complete list, sorted by the
  array's `order` field, publish dates attached, hidden chapters dropped),
  falling back to the server-rendered `table#chapters` rows.
* **Metadata** — the `application/ld+json` Book schema supplies title,
  synopsis, author, rating and update date; cover, genres, status and chapter
  count come from the DOM.
* **Content** — paragraphs the site hides via inline `display: none` CSS
  (an anti-copy trick) are removed so they don't leak into the reader.
* **Search** — inherited from the generic `html` template via `search.path`
  (`/fictions/search`) + `search.queryParam` (`title`).

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
dart run tool/generate_plugin_catalog.dart   # refresh index.json checksums
dart run tool/registry_gen.dart              # refresh registry.json
```
