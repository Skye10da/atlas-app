# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- GitHub Actions workflow building Android, Windows, iOS, macOS, and Web on push/PR/tag.
- App icon and launcher assets for all platforms.

### Fixed
- "Failed to load books" after the schema v6→v7 upgrade: the migration backfill used camelCase column names (`itemType`/`sourceName`) that don't match SQLite's snake_case columns, breaking the database open.
- Mvlempyr imports were saved as `book` instead of `novel` because `getMetadata` did not set the novel category.

### Changed
- `flutter analyze` clean (4 pre-existing `avoid_dynamic_calls` infos only) and `flutter test` 29/29 passing.
