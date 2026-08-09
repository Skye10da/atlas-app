# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-08-09

### Added
- **Reader annotations** — highlight and take notes directly in your books:
  - In-memory annotation store (`ReaderAnnotationsController`) keyed per book/chapter — the same chapter can carry multiple non-overlapping highlights, notes are edited, erased, and navigated from a notes panel.
  - **Chapter reader context menus** (long-press selection): **Highlight…** (color picker), **Erase highlight**, **Add note**, **Listen**, and **Look up** (renamed from "Define"), on both the continuous and paged layouts.
  - **PDF reader context menu** (via pdfrx `customizeContextMenuItems`): Highlight…, Erase highlight, Add note, Listen, and Look up — highlighted passages are layered on the page and a **Notes** tab lists saved notes, jumping to their page on tap.
- **Read-aloud for dictionary lookups**: a speaker button in the word-lookup sheet reads the word, its first definition, and an example sentence aloud in the word's language.
  - The TTS driver now sets the system language (`setLanguage`) per request, and `resolveVoiceIdForLanguage` picks a matching per-language voice from the installed-voice catalog (Chinese prefers a mainland/TW regional voice when available).
- **OS file import (“Open with Atlas”)**: EPUB/PDF/Atlas packages handed to the app by the OS are imported — Windows shell associations plus Android/iOS/macOS document types and channels, single-instance forwarding on Windows (a second launch forwards the file to the running window and exits), deterministic cold/warm delivery, and temporary sandbox copies are deleted after import.
- **Interactive PDF importing**: the first page is rendered to a cover (`cover.png`) and the PDF outline becomes chapter rows, so PDF books get cover art and a navigable chapter list on the details screen.
- **PDF viewer**: render-only, page-based navigation using pdfrx/PDFium, with Search, Outline, Markers, Pages, and Notes panels, night mode, and external links opened via `url_launcher`. PDFs opened via book route resume at the saved page and can be jumped to from tapped outline chapters.
- Reactive library shelf — `watchBooks` reflects imports, progress updates, and removals automatically.
- **Novel export**: chapters exported to a reader-friendly EPUB or an `.atlas` source-link package (with cover and source metadata), plus a chapter-position resolver for indexed navigation.
- Bundled typography: EB Garamond, Inter, and JetBrains Mono font families.

### Changed
- PDF rendering dependency moved from `pdfx` to `pdfrx` (PDFium), and `url_launcher` added for PDF external links.
- Reader selection actions refined alongside the speech subsystem: `SpeechDriver.configure` gained an optional language; existing "Listen" context actions and narration are unaffected.
- Word-lookup sheet header gained the read-aloud control and now auto-stops speech when closed or when its language changes.

### Fixed
- PDF search header overflow during the slide-in animation (ClipRect + overflow-safety).
- Selection in the PDF viewer uses the pdfrx page-text-range so highlights/lookups target the right span.
- Book-details chapter navigation now treats PDFs as page targets instead of text chapters; the reader waits for the resolved format before mounting, so a PDF is never briefly built as a chapter reader.
- Import failure modes hardened around cover/outline extraction (best-effort, never fails the import).

## [1.0.3] - 2026-08-04

### Added
- **Narration / Text-to-Speech (Listen-to-read)** with an Apple Music–style Now Playing experience:
  - `SpeechEngine` with session building, sentence splitting, word-boundary tracking, a narratable sentence queue, and a playback controller; powered by a `flutter_tts` driver with installed-voice discovery and a persistent voice cache.
  - Speech persistence & recovery: `RecoveryStore` (resume position across restarts) and `SharedPrefsRecoveryStore`.
  - Now Playing UI (shared `NowPlayingSheet`): cover art, karaoke-style lyrics, queue progress, and transport controls — shown as a draggable sheet on mobile and in the desktop right side panel (`NowPlayingPanel`, replacing the reader panel).
  - Persistent narration mini player that stays visible while scrolling during playback, plus an inline speed control (0.5×–2×) shared across every surface.
  - Live karaoke highlight: the current spoken word is highlighted in the chapter text as narration progresses (`activeWordBoundaryProvider`).
  - Narration settings (voice, rate, pitch) moved into the Now Playing sheet behind a discreet toggle.
  - Background audio support: Android `audio_service` foreground service + `MediaButtonReceiver` and iOS `UIBackgroundModes: audio`.
- Reader bottom navigation redesigned: battery pinned to the bottom-right as a compact pill, the **Listen** button now occupies the battery’s former slot, and the progress bar + battery share a single bottom line.
- New dependencies: `flutter_tts` and `audio_service`.

### Changed
- Narratable content is threaded with book title/cover through the bottom nav, Now Playing, and mini player; speech settings apply live while the engine is running.
- Desktop right side panel now toggles between the reader panels and the Now Playing narration panel (click-outside / Escape dismisses whichever is open).
- Draggable bottom sheet drag handling corrected to apply each frame’s delta against current height instead of a fixed drag-start height (previously discarded most movement).
- `main.dart` bootstrap now also boots the Speech subsystem (audio_service, voice cache, driver validation).

### Fixed
- Now Playing UI layout overflows on short desktop windows (fill-then-scroll cover sizing).
- Deactivated-widget crash in the chapter view by creating the highlight controller eagerly in `initState`.
- Narration voice picker assertion when the persisted voice is not among installed voices; narrow-panel overflow in the settings tab.

### Added
- **Content Acquisition Engine (Phase 1/2)** — unified download and import pipeline:
  - `DownloadManager`: concurrent worker pool with `DownloadPriority`, deduplication by book+chapter key, retry with backoff, cancel support, and `queued → downloading → done/failed` state reporting.
  - `PrefetchEngine` adapted to the new manager; `CacheManager`/`DocumentCache` gained an injectable `basePath` (testable) and `bookIds()`.
  - `ContentAcquisitionEngine` now holds a single shared `CacheManager`/`DownloadManager`, exposes `resumeDownloads()` (re-enqueues queued/downloading/discovered chapters across restarts), and downloads covers through the `ImagePipeline` (content-addressed sha256 dedupe) instead of raw HTTP.
- **Content pipeline (Phase 2)** — rich, versioned document delivery:
  - `ContentPipelineOrchestrator`: source discovery via a live `SourceRegistry`, transport → clean → normalize → post-normalize (version + sha256 checksum) → index → cache → deliver stages; persists `AtlasDocument` JSON through `DocumentCache`.
  - `ImagePipeline`: content-addressed image storage (sha256 key, extension inference, dedupe, header forwarding).
  - `TaskScheduler`: periodic maintenance tasks (resume downloads, plugin refresh, stale-cache cleanup) with overlap protection; bootstrapped in `main.dart`.
  - `Transport` interface extended with `fetchBytes`; implemented by `HttpTransport`, `CachedTransport`, `StealthTransport` (throttle + rotating User-Agent), `OfflineTransport` (bytes-served cache).
  - `RichSource` interface: rich sources deliver structured `AtlasDocument`s; `PluginSource` implements it and reuses `getChapter` to avoid double-fetching.
- **Indexing (Phase 3)** — in-memory, DB-agnostic chapter indexing:
  - `Tokenizer`: lowercase, possessive-stripping, stopword-aware term splitter shared by all indexers.
  - `SearchIndexer`: inverted term index with per-term block positions, term-count ranking, AND semantics (`SearchHit.matchesAll`), and replace-on-reindex.
  - `DictionaryIndexer`: per-document term-frequency / vocabulary / keyword surfaces for auto-glossaries and word-study.
  - `CharacterExtractor`: heuristic proper-noun detection (mid-sentence capitalized repeats) emitting `character`/`place` `Annotation`s.
  - `ContentIndexer` facade merges annotations onto delivered documents; wired into the orchestrator's post-normalize stage and exposed as a shared `contentIndexerProvider` so the index survives across pipeline runs.
- **Plugin distribution (Phase 4)** — end-to-end remote plugin lifecycle:
  - `PluginUpdater` with checksum-verified installs, version comparison, and atomic writes; `PluginRepository` loads manifests, filters, permissions, and selectors; `GithubPluginSource` and catalog-based discovery.
  - `atlas-plugins/` distribution directory with signed `index.json` catalog, validated by `tool/plugin_validator.dart`.
  - `searchableSourceProvider`/`sourceRegistryProvider`-driven dynamic source resolution.

### Changed
- Provider wiring: `documentCacheProvider`, `imagePipelineProvider`, `pipelineOrchestratorProvider`, `taskSchedulerProvider`, `contentIndexerProvider`, and the engine provider all registered; app bootstrap starts plugin discovery and the task scheduler post-frame.
- `PluginSource` implements `RichSource`; `getChapter` delegates to `getDocument`.
- `flutter analyze` clean and **188 tests passing** (up from 29 at v1.0.0), covering acquisition, pipeline, image handling, scheduling, transports, indexing, and plugin distribution.

### Fixed
- Re-indexing a document in `SearchIndexer` no longer leaks the document's old terms into the inverted index.

## [1.0.0] - 2026-08-01

### Added
- Book vs Novel classification: imports are categorized as `book` (file/ebook content: EPUB, TXT, Markdown from file, link, or source) or `novel` (web-serialized content via link through adapters like Mvlempyr).
  - New `books.item_type` column with schema v7 migration; existing Mvlempyr books backfilled to `novel`.
  - Split entry points in the library app bar: **Import Book** (device file / link) and **Add Novel** (link).
  - Category-aware routing: `/book/:id` for books, `/novel/:id` for novels (details, reader, and search results).
  - Import engine returns an `ImportOutcome` and persists category-appropriate format (`epub`/`text`/`markdown` vs `web`).
- Draggable bottom sheets across all six sheets (library sort, chapter index, word lookup, reader settings, etc.).
- Reader chrome refactored into shared widgets (chrome bar, edge regions, key events, chapter chrome pieces).
- `popOrGoToLibrary` fallback: popping at the root navigates to the library instead of throwing.
- GitHub Actions workflow building Android, Windows, iOS, and macOS on push/PR/tag.
- App icon and launcher assets for all platforms.

### Fixed
- "Failed to load books" after the schema v6→v7 upgrade: the migration backfill used camelCase column names (`itemType`/`sourceName`) that don't match SQLite's snake_case columns, breaking the database open.
- Mvlempyr imports were saved as `book` instead of `novel` because `getMetadata` did not set the novel category.

### Changed
- `flutter analyze` clean (4 pre-existing `avoid_dynamic_calls` infos only) and `flutter test` 29/29 passing.
