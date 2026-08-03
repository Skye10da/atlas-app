# ReadNovelFull plugin

Novel source for [ReadNovelFull](https://readnovelfull.com).

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `selectors.json` | CSS selectors for search, chapter list and chapter content |
| `filters.json` | Content cleaner tweaks |
| `permissions.json` | Rate-limit / politeness tuning |
| `tests/fixtures/*.html` | Recorded pages for CI smoke tests |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Notes

ReadNovelFull runs the same Yii novel engine as NovelFull, so it reuses the
`novelfull` template as a **data-only plugin** — no Dart code of its own. It
only differs from novelfull.net in a few places the template already models:

* **Chapter list** — the novel page renders only a ~30-chapter preview with no
  pagination bar; the full 200+ chapter archive must be pulled from the site's
  own endpoint `GET /ajax/chapter-archive?novelId=<id>` (the `<id>` comes from
  `#rating[data-novel-id]` on the novel page). The response is a list-shaped
  `ul.list-chapter` fragment, which is why the template's `ajaxPath` mode parses
  it with the same `chapterList.item` selector (`ul.list-chapter li`).
* **Search** — the server-rendered page lives at `/novel-list/search` with a
  `keyword` query param, driven via `search.path` + `search.queryParam`.
* **Metadata** — og: tags are emitted with `name=` instead of `property=`, the
  info rows are `li` elements rather than `div`s, and the genre label is the
  singular `Genre:`; the template handles all three variants.
* **Content** — the chapter body is `#chr-content`, titled by `.chr-title`.

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
dart run tool/generate_plugin_catalog.dart   # refresh index.json checksums
dart run tool/registry_gen.dart              # refresh registry.json
```
