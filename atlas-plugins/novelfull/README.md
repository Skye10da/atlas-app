# NovelFull plugin

Novel source for [novelfull.net](https://novelfull.net).

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `selectors.json` | CSS selectors for search, chapter list and chapter content |
| `filters.json` | Content cleaner tweaks (ad blocks) |
| `permissions.json` | Rate-limit / politeness tuning |
| `tests/fixtures/*.html` | Recorded pages for CI smoke tests |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Notes

The template (`novelfull`) differs from the generic `html` template in three
ways:

* **Pagination** — chapter lists are paginated at ~100 entries per page, so
  the template walks every page and merges them into a single ascending list
  (deduped by URL, ordered by the chapter number in the URL).
* **Search** — the site's search form submits to `/search?keyword=`, which the
  generic template's WordPress-style `?s=` cannot drive.
* **Metadata** — author, genres and status are pulled from the novel info
  panel, and the synopsis from `.desc-text` (the `og:description` on this site
  is boilerplate).

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
dart run tool/generate_plugin_catalog.dart   # refresh index.json checksums
dart run tool/registry_gen.dart              # refresh registry.json
```
