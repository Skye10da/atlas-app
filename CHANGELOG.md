# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.7] - 2026-09-08

### Added
- **Headless WebView transport pool** — `HeadlessWebViewPool` (`lib/browser/domain/services/headless_webview_pool.dart:1`) with per-origin pooling (`scheme://host[:port]`), LRU idle eviction at capacity, coalesced pending creations (`Completer`), memory-aware caps (<2 GB→1, <3 GB→2 view, from `/proc/meminfo`), and `HeadlessWebViewPool.single` test seam; paired with `HeadlessWebEngine` (`lib/browser/infrastructure/engines/headless_web_engine.dart:1`) — a `BrowserWebEngine` implementation for off-screen challenge solving without a visible `SilentWebViewHost`.
- **Transport hardening layer** — new modules under `lib/core/content_engine/transport/`:
  - `browser_header_utils.dart` — canonical browser header map (Sec-CH-UA, Accept-Language, etc.) for session-consistent requests.
  - `challenge_detector.dart` — Cloudflare / bot-challenge fingerprinting (title/body heuristics + status-code checks) driving escalation to the session-refresh flow.
  - `cronet_version_provider.dart` — Cronet/Chrome version discovery for realistic UA rotation.
  - `native_client_factory.dart` — factory that builds `cronet_http` / `cupertino_http` native clients per platform with unified header injection.
- **Reading analytics & goals persistence** — new Drift tables `discover_cache`, `reading_goals`, `reading_sessions` (`lib/core/database/tables/`), plus `ReadingAnalyticsEntity` / `ReadingAnalyticsReport` (`lib/discover/domain/entities/reading_analytics_entity.dart:1`). `ReadingAnalyticsService` (`lib/discover/infrastructure/services/reading_analytics_service.dart:9`) now tracks per-book sessions, computes 7-day + 30-day activity, time-of-day breakdown, genre stats, format ratio, streak, and pace clamping.
- **Discover intelligence** — `DiscoverSettingsStore` (persisted filter/sort prefs), `OpdsTrendingService` + `RecommendationEngine` (`lib/discover/infrastructure/services/`) for curated/OPDS trending aggregation; UI surfaced via `ReadingAnalyticsProviders`, `ReadingAnalyticsScreen`, `TrendingListScreen`, `ForYouSection`, `QuickStatsRow`, `WeeklyGoalDiscoverCard`, `TrendingBookActionSheet` (`lib/discover/presentation/`).
- **Discover dashboard maturity** (since 1.0.6) — full dashboard (`DiscoverDashboardData`, `DriftDiscoverRepository`, `TrendingService`) with `DiscoverHeader`, `NowReadingHeroCard`, `GenreCarouselSection`, `CuratedSourcesSection`, `TrendingSection`, `WeeklyActivityChart`, `EcosystemQuickGrid`, `StatsSummaryFooter` (`lib/discover/`), backed by five new plugin selector patches (`mvlempyr`, `noveldrama`, `novel-hub`, `readnovelfull`, `royalroad`, `wtrlab` selectors + `filters.json` tuned for FreeWebNovel).
- **Architecture remediation: MVVM library** (`d67afec`) — `LibraryViewModel` + immutable `LibraryState` (`lib/library/presentation/view_models/`), `LibraryBackupService` (`lib/library/application/library_backup_service.dart:1`), `BookProviders` / `ChapterDownloadProvider` / `ChapterExpansionProvider` / `NovelActionsController`; library screens (`library_screen.dart`, `book_details_screen.dart`, `novel_details_screen.dart`, `source_browser_screen.dart`, `source_search_screen.dart`) rewritten to `ConsumerWidget`/`HookConsumerWidget` with zero `setState`.
- **Block card / GameLit system-card pipeline** — `BlockCardDetector`, `BlockCardModel`, `StatSheetParser` and rules `BracketedLineRule` / `CharmSystemRule` / `PlayerPanelRule` (`lib/core/content_engine/block_card/`) with themed `BlockCardWidget` / `BlockCardTheme` (`lib/reader/presentation/widgets/block_card_theme.dart:1`) rendering inline interactive cards without breaking selection/scroll.
- **Content-acquisition hardening** — `ChapterUpdateService` (`lib/core/content_acquisition/application/chapter_update_service.dart:1`) with periodic stale-cache sweep, `BookIdNormalizer` for canonical book keys, `DownloadManager` priority/dedup/backoff/cancel improvements; `EpubUrlSource` direct-URL guard.
- **Design-system & accessibility** — `BookBadge`, `ConfirmDeleteDialog`, `MilestoneCelebrationDialog` atoms/molecules; `AppSheet` adaptive breakpoint overhaul (`lib/core/design_system/organisms/app_sheet.dart`), `AppContextMenu`, `CoverPaletteService` for dynamic cover palettes, `SplashScreen`.
- **Import robustness** — `EpubHtmlConverter` (HTML→Markdown fidelity), `TextImportService` (adaptive chapter splitting), resilient `EpubImportService` / `OpenedFileImportService` with best-effort cover/outline extraction.
- **Reader feature completeness** — `BookSearchService` / `BookSearchSheet`, `ReadingPreset` presets, `AnnotationsStorageService`, `ChapterPositionResolver`, `PagerBoundary` / `ChapterPager` / `PagedPageView`, `FootnoteSheet`, `NoteEditorSheet`, `QuoteShareCardSheet` (12-variant share card), `ReaderAnnotationsSheet`, `ReaderImageWidget`, `RealFlipReaderLayout` + `PdfFlipbookView`, `PdfBottomNav`, `ReaderSettingsPreviewCard`, `WtrAiTranslateService` / `AiChatClients` (OpenAI, Anthropic, Gemini, DeepSeek, Groq + custom endpoint streaming).
- **Android packaging** — `split-per-abi`, R8 full-mode + `proguard-rules.pro`, on-demand Google Fonts (removes 20+ bundled TTFs), `permission_handler_android:13.0.1` pin for `compileSdk 37` breakage.

### Changed
- **Web transport architecture overhaul** (`0959923`) — `HttpTransport`, `CookieTransport`, `CachedTransport`, `WebviewTransport`, `WebviewFetchResult`, `Transport` interface and `SilentWebViewService`/`WebViewPageFetcher` rewritten around `HeadlessWebViewPool`; session headers now flow via `NativeClientFactory` + `BrowserHeaderUtils`; `CachedTransport` gains `WebViewFetchResult` metadata propagation.
- **Reader layout precision** (`0959923` + `92d010e`) — `ChapterView` (`lib/reader/presentation/widgets/chapter_view.dart:1`), `ContinuousReaderLayout`, `PagedReaderLayout` (`2887` lines reflow), `PagedPageView`, `RealFlipReaderLayout` refactored for pixel-accurate pagination, boundary bounce protection, and indexed position memory (`scrollable_positioned_list`). Chrome refactored to `ReaderChromeProvider` / `ReaderChromeBar` overlay with `ReaderBarSurface` and command palette.
- **Library UI refinement** — `LibraryScreen` (790-line rebuild), `BookDetailsScreen`, `ImportUrlDialog` (2266-line wizard), `BookCard` / `BookshelfGrid/List/Scattered`, `ChapterGroupedList` now driven by `LibraryViewModel` selectors; `DriftLibraryRepository` + `DriftReaderRepository` gain progress-aware queries.
- **Discover-provider polish** — `DiscoverProviders`, `DriftDiscoverRepository`, `TrendingService`, and all `WeeklyActivityChart` / `NowReadingHeroCard` etc. updated to consume the new analytics tables; `AppRouter` routes for `reading_analytics` / `trending_list`.
- **Browser shell** — `BrowserScreen` (1796-line glass shell rebuild), `SourceImmersiveScreen` added, `AppSessionRefreshBridge` session-refresh UX, `SilentWebViewHost` widget deleted in favor of pooled headless engines.
- **Plugin selectors** — `freewebnovel/selectors.json` + `filters.json`, all `atlas-plugins/*/selectors.json` version-bumped to `1.0.1` + strip site boilerplate from titles.
- **Theming & fonts** — `google_fonts` removed in favor of `FontCatalogService` / `FontDownloader` on-demand catalog (`assets/data/google_fonts_catalog.json`); `Inter` / `Open Sans` / `Playfair Display` retained as base fonts; `GeneratedPluginRegistrant` (macOS/Windows/Linux) regenerated.
- **Code style** — `dart format` tall-style applied repo-wide (`cb16860`), `analysis_options.yaml` strict lints tightened; `CLAUDE.md` Zero-`setState` Declarative State Architecture rule documented.

### Fixed
- Escalate Cloudflare bot challenges to the session-refresh flow (`bf57b2a`) — `ChallengeDetector` now correctly routes `cf_clearance` failures through `SilentWebViewService` → `SessionRefreshScreen` instead of failing silently.
- Strip site boilerplate from titles (`a4782de`) and normalize `atlas-plugins` JSON to LF via `.gitattributes` (`53e4570`).
- `HttpTransport` header forwarding and `CookieTransport` persistence edge cases; `DownloadManager` cancellation race.
- Reader shimmer (`ChapterShimmer`) and span-builder (`ChapterSpanBuilder`) off-by-one and highlight-boundary clipping.
- `QuoteShareCardSheet` snapshot race and `ReaderContent` reflow jitter on font-size change.

### Performance & Tooling
- APK size: R8 + `isMinifyEnabled`/`isShrinkResources` + `split { abi { enable true }}` in `android/app/build.gradle.kts:11` plus on-demand fonts — reduces fat APK by ~40 % vs 1.0.6.
- CI: `analysis_files` + `dart_fix` pre-commit gate (`CLAUDE.md`) now enforced; `flutter_driver` `driver_main.dart` UI-automation entrypoint retained.
- Test suite: 26 new tests (`headless_webview_pool_test`, `browser_header_utils_test`, `challenge_detector_test`, `native_client_factory_test`, `reading_analytics_service_test`, `trending_and_import_test`, plus block-card / normalizer / wtr AI suites) — total now 738+ passing.

## [1.0.6] - 2026-08-16

### Fixed
- Re-download chapters when the WTR translation service changes (`dabde0e`) and strip site boilerplate from titles; bump family plugins to 1.0.1.
- Silence experimental coroutine deprecation on Windows for VS 2026 (`61033e4`) and use `engine.binaryMessenger` for macOS file-open channel (`46efeed`).

## [1.0.5] - 2026-08-14

### Added
- **In-app browser** — a full browser shell built on `flutter_inappwebview`:
  - Engine seam (`BrowserWebEngine` / `InappWebviewEngine`) with a glass shell: tab strip, start page, address bar, and bookmark/history sheets.
  - Persistent browser history, bookmarks, and tabs (drift-backed repositories).
  - Dedicated **Web** shell tab; the source browser remapped to it.
  - Find-in-page, reading-theme dark-mode injection, and a JS selection bridge powering an in-page context menu (Copy, Listen, Look up, Search, Select all) for web text and PDFs.
  - **Epub grab**: download EPUBs from the browser straight into the library, plus a novel **Add to Library** detection pill on compatible pages.
- **Browser session persistence & refresh** — per-origin cookie snapshots (`browser_sessions.json`) re-seeded through a silent background web view after a restart, and a dedicated session-refresh screen for Cloudflare-protected sites.
- **WTR-Lab (wtr-lab.com) source** — search, metadata, chapter list, and encrypted chapter content via the site's JSON API (AES-GCM decryption) as a data-only plugin.
- **WTR-Lab translation services** — per-novel selector for **Web / WebPlus / AI** translation on the novel details page.
  - **AI translation requires a one-time WTR-Lab sign-in** (GitHub/Discord OAuth) in an app WebView; credentials stay on wtr-lab.com and the session reuses the app's existing WebView-cookie browser-session storage.
  - Explicit auth states (not signed in / signing in / signed in / expired / failed) with an actionable prompt instead of silently falling back; expired sessions are detected at startup and from the API's `1401` not-logged-in response.
- **Plugin engine generalization** — `HtmlTemplate` generalized to drive data-only plugins and the bespoke `NovelfullTemplate` retired; new sources shipped as signed plugins: **NovelDrama**, **AllNovelFull**, and **Novel-Hub**.

### Changed
- Transports reworked so browser-style requests carry session headers and rich metadata (`WebViewTransport`, `CookieTransport`, `CachedTransport`, `StealthTransport`, …).
- Reader and chapter-download failures now surface per-source user messages (e.g. WTR sign-in prompts) instead of a generic failure string.
- New dependencies: `flutter_inappwebview` and `pointycastle`.

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
