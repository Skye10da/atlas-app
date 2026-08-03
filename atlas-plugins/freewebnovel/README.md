# FreeWebNovel plugin

Novel source for [freewebnovel.com](https://freewebnovel.com).

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `selectors.json` | CSS selectors for search, chapter list and chapter content |
| `filters.json` | Content cleaner tweaks (reader chrome) |
| `permissions.json` | Rate-limit / politeness tuning |
| `tests/fixtures/*.html` | Recorded pages for CI smoke tests |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Notes

This plugin is **data-only**: it uses the generic `html` template and runs on
existing app builds with no code changes. Everything the site needs is
expressed in `selectors.json`:

* **Search** — `search.path` (`/search`) + `search.queryParam` (`keyword`)
  drive the site's real search endpoint; the results card selector picks the
  title link and cover.
* **Chapter list** — chapters are paginated at 40 per page in `#idData`, so
  `chapterList.maxPages` walks `?page=N` and the engine merges + dedupes the
  pages into one list. Out-of-range pages are clamped to the last page, which
  terminates the walk early.
* **Content** — the body lives in `.m-read`; the reader title bar (`.top`) and
  nav/settings chrome (`.ul-list7`) are stripped via `filters.json`.

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
dart run tool/generate_plugin_catalog.dart   # refresh index.json checksums
dart run tool/registry_gen.dart              # refresh registry.json
```
