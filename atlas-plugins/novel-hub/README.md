# Novel Hub

Source plugin for **Novel Hub** (https://live.mangabooth.com/novelreader) — the
official Madara demo, running the WordPress "Madara" manga/novel theme with its
`madara-child-novel` child theme.

This plugin is the reference example of the generic `html` template's
Madara/WordPress-manga support:

- **Novel id** — read off the novel page from `#manga-chapters-holder`'s
  `data-id` attribute (`#madara-chapters-holder` as a fallback for older Madara
  versions).
- **Chapter archive** — POSTed to `wp-admin/admin-ajax.php` with the Madara
  form contract `action=manga_get_chapters&manga=<id>`, and the `<li>` list is
  unwrapped from the JSON `data.content` field. Configured entirely in
  `selectors.json` (`ajaxArchive.method`, `.form`, `.responseField`,
  `.novelIdSelector`, `.ajaxBase`); no bespoke template involved.
- **Search** — the WordPress `?s=` endpoint with `post_type=wp-manga` so only
  manga/novel posts are returned.
- **Metadata** — child-theme `.summary_content` blocks (author, genre links,
  status) with classic-Madara `.post-content_item` fallbacks, plus the
  `manga-excerpt` description. Genre links are collected as a list, one genre
  per `<a>`.

## Files

| File                | Purpose                                             |
| ------------------- | --------------------------------------------------- |
| `plugin.json`       | Manifest: `templateId: "html"`, transport `http`    |
| `selectors.json`    | Search, chapter list + POST archive, content, meta  |
| `filters.json`      | Extra strip selectors for the chapter body          |
| `permissions.json`  | Rate limits and offline-cache policy                |
| `tests/`            | Recorded fixtures + expectations for the validator  |