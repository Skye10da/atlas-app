# Atlas

<div align="center">

![Atlas Banner](https://raw.githubusercontent.com/Skye10da/atlas-app/main/assets/banner.png)

**An AI-native, offline-first reading platform and web novel ecosystem built with Flutter.**

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20MVVM-success)](#architecture)
[![Tests](https://img.shields.io/badge/Tests-738%20Passing-brightgreen)](#testing--verification)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20macOS%20%7C%20Android%20%7C%20iOS%20%7C%20Linux-blue)](#supported-platforms)
[![License](https://img.shields.io/badge/License-MIT-purple)](#license)

</div>

---

## 🌟 Overview

**Atlas** is a modern, cross-platform reader engineered specifically for power readers, web novel enthusiasts, and digital bibliophiles. Built with Flutter, Atlas bridges the gap between traditional offline ebook readers (EPUB, TXT, Markdown) and modern digital web serials with built-in AI translation, game-lit status card rendering, smart karaoke TTS narration, and an embedded content crawler.

---

## ✨ Implemented Features

### 📖 1. Next-Gen Reading Engine
- **Dual Reading Layouts**:
  - **Continuous Scroll Mode**: High-performance vertical scrolling with boundary bounce protection, smooth physics, and dynamic chapter-crossing listeners.
  - **Paged Book Mode**: Paginated view with tactile page-turning mechanics and boundary feedback.
- **Deep Typography Controls**:
  - Dynamic font size, line height (proportional paragraph leading), letter spacing, and font weight customization.
  - **Drop Caps**: Elegant decorative typographic drop caps for chapter openings.
  - **Preset Margins**: Narrow, Normal, and Wide presets for optimal eye-travel across mobile, tablet, and desktop screens.
  - **Text Alignment**: Left-aligned, Centered, and Justified reading modes.
- **Reading Themes**:
  - Paper, Dark, Sepia, OLED True Black, Slate, Solarized, Rose, and custom palette presets with high-contrast, eye-friendly color calculation.
- **Dynamic Font Catalog**:
  - In-app Google Fonts browser and download manager.
  - Live preview, asynchronous font caching, and local storage management without restarting the application.
- **Exact Position Memory**:
  - One-shot character-offset position restoration ensuring you resume reading down to the exact sentence across app restarts.

### 🎮 2. Content Engine & LitRPG System Cards
- **Interactive Block Cards (`BlockCardWidget`)**:
  - Intelligent AST parser that identifies progression fantasy, GameLit, and LitRPG status windows, stat blocks, skill notifications, and item descriptions.
  - Renders inline interactive system cards seamlessly interleaved with prose without breaking text selection or scroll physics.
- **Dialogue & Quote Intelligence**:
  - Automatic quote detection (supporting straight `"` and typographic `“”` double quotes) with automatic italicization for realistic dialogue presentation.

### 🤖 3. AI Translation & WTR Integration
- **Multi-Engine AI Translation**:
  - Direct integration with **OpenAI** (GPT-4o, GPT-4o-mini), **Anthropic Claude** (Claude 3.5 Sonnet, Claude 3 Haiku), **Google Gemini** (Gemini 1.5 Pro, Gemini 1.5 Flash), **DeepSeek** (DeepSeek-Chat, DeepSeek-Coder), **Groq** (Llama 3.3 70B), and custom OpenAI-compatible REST endpoints.
- **WTR Translation Pipeline**:
  - Seamless support for **Web**, **WebPlus**, and **AI+** translation services.
  - Fallback pipeline with automatic retry, error recovery, and graceful degradation to raw text when offline or unconfigured.
- **Smart Glossary & Term Replacement**:
  - In-memory and persistent translation glossaries that map untranslated or mistranslated source terms (e.g. CJK names, cultivation ranks, skill terminology).
  - Character and noun substitution markers (`※n⛬`) preserving grammatical context across automated translation passes.
  - User-level term preference overrides that take precedence over generic dictionaries.

### 🎙️ 4. Karaoke Narration & Text-to-Speech (TTS)
- **Sentence-Level Speech Highlighting**:
  - Animated karaoke-style background tint that smoothly fades in on the active sentence being read aloud.
- **Smart Scroll Tracking**:
  - Automatic viewport coordination that auto-scrolls to keep the currently spoken sentence centered in the reader's view.
  - "Jump to Narration" floating indicator when the reader manually scrolls away from the audio position.
- **Floating Audio Controls**:
  - Mini-player overlay and expandable bottom sheet controls for Play/Pause, Next/Previous Sentence, Speed (0.5x - 3.0x), Pitch, and Voice selection.
  - Resumes speech from exact sentence offsets.

### 📚 5. Library Management & Bookshelf
- **Reactive MVVM Architecture**:
  - Powered by `LibraryViewModel` and immutable `LibraryState`.
- **Multi-Dimensional Filtering & Sorting**:
  - Filter by Category (All, Novels, Books, Fanfiction, etc.).
  - Dynamic Genre tag filtration with real-time book count resolution.
  - Sorting by **Recently Read**, **Title**, **Author**, **Date Added**, and **Reading Progress**.
  - Real-time instant search across local book titles and author metadata.
- **Multiple Layout Views**:
  - Visual Grid layout with cover caching, Detailed List view, and Compact Shelf view.
- **Multi-Format Ingestion**:
  - Import local **EPUB**, **TXT**, and **Markdown** documents.
  - Import web novels via direct URL or search query.

### 🌐 6. Embedded Browser & Content Acquisition
- **Integrated Web Browser**:
  - In-app tabbed browsing with URL bar, forward/backward navigation, bookmarks, and visit history.
  - Automatic duplicate collapse in browsing history.
- **Source Search & Crawlers**:
  - Built-in search across supported novel sites and sources.
  - Automatic chapter list crawling and metadata extraction.
  - Background chapter update scheduler with system notifications when new chapters are published.

### ✍️ 7. Annotations, Notes & Reader Tools
- **Unified Text Selection**:
  - Continuous selection across prose spans while respecting card boundaries.
- **Multi-Color Highlighting**:
  - 5-color highlight palette (Yellow, Green, Blue, Pink, Purple) with overlap detection and one-tap eraser.
- **Integrated Note-Taking**:
  - Attach contextual notes directly to selections and sentences.
- **Word Lookup & Dictionaries**:
  - Built-in dictionary sheet for instant definition lookups.
  - One-tap "Set as Term" to instantly create novel glossary entries.
  - Quick Web Search shortcut for unfamiliar references and lore.
- **Export Capabilities**:
  - Export reading progress, chapters, and books to TXT, EPUB, or clean printable formats.

---

## 🔮 Roadmap: Upcoming Features (In Development)

The following features are scheduled on the active development roadmap:

```
[Phase 4: Synchronization]  ──►  [Phase 5: Neural Audio]  ──►  [Phase 6: Advanced PDF & Analytics]
```

### ☁️ Cloud Sync & Multi-Device Continuity (Phase 4)
- [ ] **WebDAV & Self-Hosted Sync**: Bi-directional synchronization of reading progress, bookmarks, highlights, and notes via WebDAV (Nextcloud, Koofr, custom servers).
- [ ] **End-to-End Encrypted Cloud Backup**: Encrypted snapshots of library metadata, custom themes, and personal glossaries.
- [ ] **Cross-Device Hand-Off**: Seamlessly transition reading from desktop (Windows/macOS) to mobile (Android/iOS) with real-time position sync.

### 🎧 Local Neural TTS & Offline Voices (Phase 5)
- [ ] **On-Device Kokoro & Piper TTS**: Offline ONNX-based neural voice synthesis for ultra-realistic natural reading without relying on system TTS or cloud APIs.
- [ ] **Multi-Voice Character Assignment**: Automatic speaker attribution that assigns distinct character voices to dialogue vs. narration based on quotation parsing.
- [ ] **Background Audio Service**: Media notification integration with lock-screen scrubber and Bluetooth headphone controls.

### 📄 Advanced PDF Engine & Dual-Page Spread (Phase 6)
- [ ] **Reflowable PDF Mode**: Intelligent text extraction and reconstruction turning fixed-layout PDFs into responsive, readable flow documents.
- [ ] **Dual-Page Spread for Desktops & Tablets**: Side-by-side two-page reading layout with realistic page-flip simulations for large displays.
- [ ] **Pencil & Stylus Annotations**: Direct vector handwriting, margin scribbles, and freeform drawing support for tablet users.

### 📊 Reading Statistics & Gamification (Phase 7)
- [ ] **Reading Heatmaps & Streaks**: GitHub-style activity grid documenting daily reading duration, words read, and reading consistency.
- [ ] **Speed Reading & WPM Tracker**: Live Words-Per-Minute measurement, estimated time-to-finish per chapter/book, and RSVP (Rapid Serial Visual Presentation) speed-reading mode.
- [ ] **Milestone Badges**: Unlockable achievements celebrating finished volumes, reading milestones, and vocabulary expansion.

### 🧩 Plugin & Extension SDK (Phase 8)
- [ ] **Community Source Extensions**: A sandboxed JavaScript/Dart extension runtime (inspired by Mihon/Tachiyomi) allowing community developers to write scrapers and adapters for any web fiction portal.
- [ ] **Custom Theme & CSS Injection**: Allow users to author and share custom reader styling, borders, and CSS effects.

---

## 🏛️ Architecture & Tech Stack

Atlas is engineered according to **Clean Architecture** principles and **Feature-Driven Development**:

```
lib/
├── core/                               # Cross-cutting foundational infrastructure
│   ├── content_acquisition/            # Sources, crawlers, and adapters
│   ├── content_engine/                 # Block cards, task schedulers, AST parsers
│   ├── database/                       # Drift ORM, SQLite migrations, and tables
│   ├── design_system/                  # Design tokens, typography, atomic components
│   ├── router/                         # Declarative routing with go_router
│   ├── services/                       # Platform bridges and system capabilities
│   └── theme/                          # Dynamic theming & font catalogs
│
├── library/                            # Library & Bookshelf Module
│   ├── domain/                         # Book entities, value objects, repository contracts
│   ├── infrastructure/                 # Drift SQLite implementations & stream providers
│   └── presentation/                   # Screens, LibraryViewModel, and shelf widgets
│
├── reader/                             # Reader & Narration Engine
│   ├── domain/                         # Reader entities, annotations, highlights, spans
│   ├── presentation/                   # ChapterView, ChapterSpanBuilder, NarrationCoordinator
│   └── speech/                         # TTS engine, sentence splitter, playback controller
│
├── settings/                           # User Settings & Preferences
│   ├── domain/                         # ReadingPreferences, ThemePreferences, AI config
│   ├── infrastructure/                 # Persistent storage (shared_preferences)
│   └── presentation/                   # Setting screens & font management
│
└── wtr/                                # Web Translation & AI Engine
    ├── domain/                         # Translation models, providers, glossaries
    ├── infrastructure/                 # OpenAI, Anthropic, Gemini, DeepSeek clients
    └── presentation/                   # Translation selector & status tracking
```

### Core Technologies
| Area | Library / Technology | Purpose |
|---|---|---|
| **Framework** | Flutter 3.x (Dart 3.x) | Native multi-platform client UI |
| **State Management** | Riverpod 2.x (`StateNotifier`, `FutureProvider`, `StreamProvider`) | Predictable, compile-safe reactive state |
| **Local Database** | Drift (SQLite) | High-performance offline persistence & reactive streams |
| **Routing** | `go_router` | Declarative deep linking and screen transitions |
| **Ebook Parsing** | `epub_plus`, custom TXT/MD parsers | Multi-format book decoding |
| **Speech (TTS)** | `flutter_tts` + custom Audio Coordinators | Cross-platform text-to-speech with sentence sync |
| **AI Integrations** | Native HTTP streaming REST clients | OpenAI, Anthropic, Gemini, Groq, DeepSeek |
| **Testing** | `flutter_test` | Unit, widget, and integration coverage (738+ tests) |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>=3.22.0` (Channel stable)
- **Dart SDK**: `>=3.4.0`
- **Platform Toolchains**:
  - **Windows**: Visual Studio 2022 with "Desktop development with C++"
  - **Android**: Android Studio with SDK 34+ and NDK
  - **macOS / iOS**: Xcode 15+ and CocoaPods

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Skye10da/atlas-app.git
   cd atlas-app
   ```

2. **Install project dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Code Generation** (Drift database, Riverpod code gen):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the Application**:
   ```bash
   # Run on Desktop (Windows)
   flutter run -d windows

   # Run on Desktop (macOS)
   flutter run -d macos

   # Run on Android
   flutter run -d android

   # Run on iOS Simulator
   flutter run -d ios
   ```

---

## 🧪 Testing & Verification

Atlas maintains strict code quality standards, enforced through automated static analysis and a comprehensive test suite.

```bash
# Run strict static analysis
dart analyze lib test

# Run the complete test suite (738+ tests)
flutter test

# Run a specific domain test suite
flutter test test/reader/
flutter test test/library/
flutter test test/wtr/
```

- **Analyzer Quality**: 0 errors, 0 warnings, 0 lints.
- **Logging Rule**: Atlas strictly uses `package:logger` for debugging; `print` and `debugPrint` are disallowed in production code.

---

## 📱 Supported Platforms

| Platform | Support Status | Notes |
|---|:---:|---|
| **Windows** | 🟢 Tier 1 | First-class desktop support with keyboard shortcuts & window controls |
| **Android** | 🟢 Tier 1 | Optimized touch gestures, system bar integration, back navigation |
| **macOS** | 🟢 Tier 1 | Native menu bar support, trackpad gestures |
| **iOS** | 🟢 Tier 1 | Full support with Cupertino edge sheets & smooth swipe gestures |
| **Linux** | 🟡 Tier 2 | Desktop support via GTK |

---

## 📜 Development Standards

This project adheres to the **Atlas Blueprint** — an engineering operating system defining:
- **Zero-Warning Policy**: Code must pass `dart analyze lib` without any issues before merging.
- **Separation of Concerns**: Pure domain layer without UI dependencies, thin view models, and decoupled presentation widgets.
- **Fail-Soft Error Handling**: Network services, translation backends, and scrapers must handle failures gracefully without crashing or trapping UI state.

---

## 📄 License

Atlas is licensed under the [MIT License](LICENSE).
