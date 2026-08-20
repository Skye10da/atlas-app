# WTR-LAB plugin

Novel source for [wtr-lab.com](https://wtr-lab.com) — an MTL (machine-translated)
novel aggregator. Ships as a **data-only** plugin on the bespoke `wtrlab`
template, which talks to the site's JSON API instead of scraping HTML.

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `filters.json` | Content cleaner tweaks (chapter bodies are clean plain text) |
| `permissions.json` | Rate-limit / politeness tuning (1 request/second) |
| `tests/fixtures/novel.html` | Recorded novel page (`__NEXT_DATA__`) for the metadata smoke test |
| `tests/fixtures/chapter.json` | Recorded `/api/reader/get` response for the chapter smoke test |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Notes

The template (`lib/core/content_engine/templates/wtrlab_template.dart`) drives
four endpoints:

- **Search** — `POST /api/search` with `{"text": "<query>"}`; results carry the
  `raw_id` and `slug` used to build `/en/novel/<raw_id>/<slug>` URLs.
- **Metadata** — the novel page's `#__NEXT_DATA__` script (the `og:` tags are
  polluted with "Read ... RAW English Translation - WTR-LAB" boilerplate).
  Prefers the translated `data.*` fields, falling back to `data.raw.*`.
  `status` is 0 = Ongoing, 1 = Completed (verified live — this is the opposite
  of what lightnovel-crawler assumes).
- **Chapter list** — `GET /api/chapters/<raw_id>` returns the whole list in one
  response; chapter URLs are `<novel-url>/chapter-<order>`.
- **Chapter content** — `POST /api/reader/get` (payload
  `{"translate":"web","language":"en","raw_id":...,"chapter_no":...,"retry":false,"force_retry":false}`).
  The response body is `arr:<iv>:<tag>:<ciphertext>`, AES-GCM encrypted with the
  site's hardcoded 32-byte key; decrypting yields a JSON array of paragraphs.
  Plain HTTP returns the **raw (Chinese)** text, and the site demands a
  Cloudflare Turnstile challenge when it can't see a browser session — so the
  reader POST is routed through the app's WebView transport, which serves it
  from a real browser context (passing the challenge) whenever one is
  available. The "ai" service that returns English additionally requires login
  (`{"code":1401,"error":"You are not logged in!"}`).

When the reader endpoint answers `requireTurnstile: true` the site needs a
fresh browser check before serving content; the template latches the origin as
session-invalid so the app's re-verify flow runs and then retries.

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
```