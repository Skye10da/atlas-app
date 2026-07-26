# Atlas

An AI-native reading platform built with Flutter. Offline-first, beautiful, and fast.

## Features

- **Reader Engine** — continuous scroll mode with chapter navigation, bookmarks, reading progress tracking, and theming
- **Library Management** — import EPUB files, grid/browse your collection, book details view
- **Reading Settings** — font size, font family, bright/dark/sepia themes, screen brightness, keep-awake
- **Search** — full-text search across books and chapters
- **Bookmarks** — save and navigate reading positions
- **Cross-Platform** — Android, iOS, Windows, macOS, Linux, Web
- **Offline-First** — all content stored locally via drift (SQLite)

## Architecture

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x |
| State Management | Riverpod 2.x |
| Local Database | drift (SQLite) |
| Routing | go_router |
| Code Generation | freezed, riverpod_generator |
| Theming | Material 3 + flex_color_picker |
| EPUB Parsing | epub_plus |
| Animation | flutter_animate |

### Project Structure

```
lib/
├── core/           — Shared infrastructure (database, error handling, design system, services)
├── library/        — Library & book management (domain → infrastructure → presentation)
├── reader/         — Reader engine (domain → infrastructure → presentation)
├── search/         — Full-text search (domain → infrastructure → presentation)
└── settings/       — Reading settings (domain → infrastructure → presentation)
```

Follows Domain-Driven Design with feature-first modules. Each domain has its own entities, repository interfaces, infrastructure implementations, and presentation layer.

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run code generation (drift, freezed, riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run on Windows
flutter run -d windows

# Run on Android
flutter run -d android

# Analyze
flutter analyze

# Test
flutter test
```

## Development

This project is governed by the [Atlas Blueprint](https://github.com/anomalyco/atlas-blueprint) — an Engineering Operating System that defines architecture, standards, and workflows.
