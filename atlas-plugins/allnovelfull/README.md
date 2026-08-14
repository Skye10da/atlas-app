# AllNovelFull plugin

Novel source for [allnovelfull.net](https://allnovelfull.net) — the "All Novel
Full" mirror of the novel-reading engine shared with NovelFull / ReadNovelFull
(the site has since been rebranded to NOVGO but keeps the same URL scheme).

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

The site runs the same Yii engine as NovelFull, so it ships as a **data-only**
plugin on the generic `html` template:

- **Chapter archive** — one GET to `/ajax-chapter-option?novelId=<id>` returns a
  `<select>` of `<option value="/novel/chapter-N.html">`, declared via
  `chapterList.ajaxPath` + `ajaxArchive` (`select > option[value]`,
  `url: "@value"`). The novel id is read off the novel page
  (`#rating[data-novel-id]`).
- **Metadata** — the `.col-info-desc .info` rows (`Author:`, `Genre:`,
  `Status:`) via the `metadata` info-row fields, description from `.desc-text`.
- **Search** — `/search?keyword=`. The site currently renders its search
  results client-side via an AJAX endpoint, so the server-rendered results list
  can be empty; the endpoint and markup follow the standard novelfull-family
  layout.

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
```
