# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
