# Plan — Landing Page Upgrade: Smart Download + Marketing Polish

## Goal

Upgrade the Flutter Web landing page (`/`, `lib/marketing/`) so it:

1. **Converts like a product page, not a changelog reader** — a marketing-driven
   narrative (audience → problem → proof → feature storytelling → CTA) instead
   of today's flat feature grid.
2. **Downloads the right build automatically** — the download section detects
   the visitor's OS *and* CPU architecture and hands them the correct release
   asset on one click, no platform hunting, no dead-end release page.

Two constraints honored throughout:

- All glass surfaces reuse `GlassCapsule` / `GlassLens`
  (`lib/core/design_system/molecules/glass_surfaces.dart`) — no hand-rolled
  `BackdropFilter` (see `docs/plans/reader_glass_pills_plan.md` rationale).
- Project standards: zero analyzer warnings, MVVM/Clean layering, logs via
  `package:logger` only, tests mirrored under `test/`.

---

## Current state inventory

| Piece | File | Today | Gap |
|---|---|---|---|
| Landing screen | `lib/marketing/presentation/screens/landing_screen.dart` | Hero → Features → Screenshots → Release notes → Download CTA in a `ListView`; anchor scroll | No social proof, no story sections, no FAQ, CTA only in 2 places |
| Release feed | `lib/marketing/domain/services/github_release_service.dart` + `latestReleaseProvider` | Live latest-release fetch, curated fallback | Fine as-is; used by everything below |
| Asset matching | `github_release.dart` `assetForPlatform()` | Naive name-contains matching; needles `android`/`ios`/`desktop` — `"desktop"` never matches `atlas-v1.0.8+8-windows.zip` | **Broken matcher**; no architecture awareness |
| Download UX | `landing_download_cta.dart` | Primary button opens the GitHub releases page; 3 platform pill buttons guess assets | Visitor always ends up on the releases page and self-selects |
| CI artifacts | `.github/workflows/release.yml` + `tool/generate_manifest.py` | `atlas-<tag>-android.apk` (universal), `atlas-<tag>-windows.zip` (x64), `manifest.json`. No macOS/Linux jobs | Nothing for Apple-Silicon/macOS, Linux, Android ABIs; naming has no arch token |
| SEO | `web/index.html` | Flutter stub ("A new Flutter project.") | No title/description, no OG/Twitter cards, no JSON-LD, no `noscript` — near-invisible to crawlers |
| Tests | `test/marketing/…` | 3 files (screen, service, entity) | No device-detection / resolver / smart-CTA tests |

---

## Phase 1 — Smart download (highest value, do first)

### 1.0 Canonical asset naming contract

Publish every artifact as:

```
atlas-<version>-<platform>[-<arch>].<ext>
```

| Platform | Arch tokens | CI source |
|---|---|---|
| `android` | `arm64-v8a`, `armeabi-v7a`, `x86_64`, or none (= universal) | existing `build-android` job, optionally `--split-per-abi` |
| `windows` | `x64`, `arm64` | existing job (x64) + future ARM64 job |
| `macos` | `arm64`, `x64` | **new `build-macos` job** (`macos-latest`, `flutter build macos --release`, zip with `ditto -c -k --sequesterRsrc`) |
| `linux` | `x64`, `arm64` | optional tier-2 job (tar.gz) |
| `ios` | — | no side-loadable artifact; deep link to the App Store |

Rules:

- `tool/generate_manifest.py` already keys artifacts by filename suffix — extend
  `PLATFORM_SUFFIXES` to `-<platform>[-<arch>].apk|.zip|.tar.gz` so the release
  `manifest.json` (which the landing page can also fetch for SHA-256 badges)
  stays truthful. Note: today's `-android.apk`/`-windows.zip` suffix map must
  keep matching old tags for the in-app updater.
- CI gap worth fixing while here: `release.yml:99` reads `$BUILD_NUMBER` /
  `$BUILD_NAME` but never derives `BUILD_NUMBER` from the tag — the version
  step fails or mislabels. Extract both from `$TAG`.

### 1.1 Device profiling service

New: `lib/marketing/domain/services/device_profile.dart`
(+ provider in `landing_providers.dart`).

```dart
enum DeviceOs { windows, macos, linux, android, ios, other }
enum DeviceArch { x64, arm64, unknown }

class DeviceProfile {
  final DeviceOs os;
  final DeviceArch arch;
  final String osVersion; // display only ("Windows 11", "macOS 15")
  bool get isDetectable => os != DeviceOs.other;
}

class DeviceProfileService {
  Future<DeviceProfile> detect();            // memoized
  static DeviceProfile fallback();           // os: other, arch: unknown
}
```

Detection strategy (web-only code path; keep it behind
`kIsWeb` so the module still compiles/analyzes on desktop targets):

1. **UA-CH first** (Chromium: Chrome/Edge/Opera/Brave) —
   `navigator.userAgentData.getHighEntropyValues(
   ['platform','platformVersion','architecture','bitness','model'])`.
   Gives authoritative `platform` + `architecture` (`arm` + bitness 64 → arm64).
   Use `package:web` interop (no `dart:html`).
2. **UA-string fallback** (Safari, Firefox, all Apple devices):
   `navigator.userAgent` / `navigator.platform` patterns —
   `Windows NT`, `Macintosh|Mac OS X`, `Android`, `iPhone|iPad|Mobile Safari`,
   `Linux x86_64|CrOS`. ARM-Windows fires UA-CH; note Safari has no arch API,
   so macOS arch heuristic: `x86_64` token → x64, Apple-Silicon Macs omit it →
   default `arm64` for macOS/Safari (Apple no longer ships Intel Macs).
3. **`defaultTargetPlatform`** from `dart:ui` as last-resort OS sanity check.
4. Never throw: any detection error falls back to `DeviceProfile.fallback()`.

### 1.2 Smart asset resolver

New: `lib/marketing/domain/services/release_asset_resolver.dart` — pure logic,
exhaustively unit-testable.

```dart
class ResolvedDownload {
  final String label;        // "Atlas 1.0.8 for Windows (x64)"
  final String downloadUrl;  // resolved asset, or release page when unresolved
  final bool isExactMatch;   // false → we could only guess (link to releases page)
}

ResolvedDownload resolve({
  required GitHubRelease release,
  required DeviceProfile profile,
  // @visibleForTesting: injectable glob table so slug changes are test data, not code
});
```

Match order: exact `platform-arch` token pair → platform token with arch-less
name (universal APK / arch-agnostic zip) → `null` → fall back to the release
**releases page** with `isExactMatch: false` so the UI can say
"See all assets" instead of promising a wrong file.

Remove `assetForPlatform('ios' | 'desktop')` usages; the resolver owns all
switching. If the layout diverges (split-per-abi vs universal), the resolver
deals entirely in the naming contract from 1.0.

### 1.3 Download UX on the page

`landing_download_cta.dart` rewrite:

- **Primary button = one click, right file.** On build, it renders the resolved
  state: `Download for Windows (x64) · 84 MB` — `size` comes from
  `GitHubReleaseAsset.size` → humanized MB. While the release lookup is in
  flight, render the shimmer glass capsule (no "Unknown platform for you").
- **Trigger = real browser download, not navigation.** Dismissal via an
  invisible anchor element with `href = asset.browserDownloadUrl` +
  `download` attribute through `package:web` (`url_launcher`'s external mode
  navigates; we want the file dialog without leaving the page).
- **Never auto-download on page load.** Auto-detect *and* auto-select; the
  click is still the user's affirmative. One deliberate exception, opt-in via
  the URL contract: `/download` (top-level route) triggers the resolved
  download immediately after a 1–2s "Resolved your device… downloading"
  interstitial — for social-inline CTAs ("grab it here: atlas.app/download").
- **Secondary grid** keeps manual entry points for every platform/arch pair the
  release actually ships, each pre-checked with detected active state ("this
  is your device"), plus "All releases" link. Buttons that resolve to nothing
  show release-page fallback with honest copy.
- **Trust row under the CTA**: size, SHA-256 (from `manifest.json` when present),
  "v1.0.8 · published <relative date>", MIT license link. Small, but converts.
- States: resolved / in-flight (release fetch) / unresolved (fallback) /
  detection failed (secondary grid highlighted) — all four are testable.

### 1.4 What keeps animated

Detect once per session, memoized (a `FutureProvider.family` keyed by release
tag is unnecessary; plain `FutureProvider` + `AsyncValue` thread through the
CTA). Respect reduced-motion: no pulsing capsules under
`MediaQuery.disableAnimationsOf`.

---

## Phase 2 — Marketing structure & visual upgrade

### 2.1 Message strategy (the strategy behind the pixels)

- **Positioning**: "The reading platform that actually understands what you
  read — EPUBs, PDFs, and thousands of web-novel chapters, offline, private,
  translated on demand." Sharp single line, ownership of *understanding*.
- **Audience segments → which sections talk to them**:
  | Segment | Hook section | Proof |
  |---|---|---|
  | Power readers collecting EPUBs | Hero + typography feature shot | exact resume, focus mode |
  | Web-novel serial bingers | web-novel story section, system cards | source search, chapter updates |
  | LitRPG / progression readers | Block-card demo shot | GameLit status cards |
  | Privacy-conscious | "Local-first" feature + SHA trust row | MIT, no account required |
- **Narrative arc on the page**: promise (hero) → problem (one em-dash line
  under features: fragmented libraries vs one shelf) → proof (
  screenshots story) → depth (system cards, narration) → objection head-off
  (comparison table + FAQ) → action (download, second CTA) → peace of mind
  (footer).
- Keep hero copy `landingHeroHeadline` ("Read widely. Know deeply.") — it
  works; tune subhead to name concrete capabilities for SEO.

### 2.2 New / rebuilt sections (in scroll order)

1. **LandingHero (refresh)** — CF keep composition (already glass + version
   pill). Add: detected-device micro-copy under the primary button
   ("We detected Windows · x64") from Phase 1; secondary "See how it works ↓"
   ghost button; a **live reader mock** (real Atlas screenshot inside a tilted
   glass device frame with the ambient gradient) so the hero sells visually
   in <2s of LCP. Materialize with the strongest release screenshot asset,
   curated fallback asset otherwise.
2. **Social-proof strip (new, thin)** — version, downloads-to-date (best-effort:
   GitHub release asset count sum if exposed, else omit), star count, "738+
   tests pass", "MIT & offline-first". Static row under hero; high
   credibility-per-pixel.
3. **LandingFeatures (upgrade)** — today's icon grid survives for depth, but
   pair it with a **3-step "How it works"** ribbon (Import sources → Read &
   learn → Sync/export) as the first thing after hero.
4. **Story sections (new — the core upgrade)**: alternating text/image blocks
   replacing the flat screenshot strip:
   - *Every source, one shelf* (library grid shot)
   - *AI that knows the story* (chapter context + chat shot)
   - *System windows for LitRPG* (BlockCardWidget shot)
   - *Read with your ears* (narration karaoke highlight shot)
   Each: kicker label, headline, 2-sentence body, one annotation arrow list.
   Source images: release screenshot assets (existing behavior), with curated
   fixture assets (`assets/marketing/*.png`) so the page never ships empty.
   Screenshots section pivots into this gallery; captions still come from
   asset names humanized.
5. **Comparison table (new)** vs "plain EPUB readers / cloud reading apps /
   other FOSS readers", rows: offline-first, book *and* serial support, AI
   chapter context, translation pipeline, TTS narration, price ("Free & MIT").
   Honest, restrained copy (no "others suck" framing).
6. **LandingReleaseNotes (keep, tighten)** — stays as the freshness/frequency
   signal; add a "What's new in this build" three-bullet extraction from
   `release.body` (first three headings/bullets parsed — body is markdown we
   already render).
7. **FAQ accordion (new)** — 6 real questions: Where do I download?
   Requires account? My data? Platforms? Web version? AI keys cost?
   Anchors too, reused for objection-handling. Uses `AppSheet`-family
   expansion styling.
8. **Roadmap teaser (new, small)** — "Coming: cloud sync · neural voices ·
   dual-page PDF" from the README roadmap; converts on intent and sets the
   rhythm of improve-visible-fast.
9. **LandingDownloadCta (Phase 1)** moves to the end of story flow; footer
   stays.

### 2.3 Visual system

- All glass via `GlassCapsule`; blur 24 solo / 16–20 over images & text per the
  house rules; `strong: true` only on CTA capsules; **no new decorations**.
- Type ramp: keep Inter; hero 54 clamp → `MediaQuery` responsive sizes down to
  34 on small viewports; section kickers 12/700/uppercase.
- Motion: subtle, `disableAnimationsOf` respected; sections adopt an eased
  340ms slide-up reveal on first scroll into view (house `_PageGlanceReveal`
  behavior), never remount children.
- Colors: respect the current light/dark gradient backgrounds; keep the page
  theme-consistent with the app by reusing design tokens
  (`AppSpacing`, `ColorScheme`) — no new ad-hoc hexes beyond the existing
  background constants.
- Responsive: max content width 920 (hero) / 1080 (story sections); convert
  `LandingAppBar` desktop row into a glass hamburger → sheet under 720px;
  story grid collapses to single column under 860px.

---

## Phase 3 — Discoverability & analytics (the traffic engine)

### 3.1 SEO & meta in `web/index.html`

Crawlability on canvas-Flutter is best-effort at head level:

- `<title>Atlas — the AI-native reading platform</title>`, meta description with
  the positioning line, canonical URL (convention: `https://atlas-app.dev` —
  replace with the real domain when deployed).
- OG + Twitter cards (`og:image` from favicon-sized banner 1200×630,
  `og:type: website`, `og:url`).
- JSON-LD `SoftwareApplication` (name, OS list, offers: free, MIT,
  `downloadUrl` pointing at latest release) + `FAQPage` once Phase 2.2.7 exists.
- `<noscript>` block with hero text + primary download link (crawlers and
  no-JS visitors get the pitch) — cheapest high-quality trick available.
- Update flutter web app title strings so install prompts look right.

### 3.2 Analytics

- Event taxonomy: `landing_view`, `download_click {os, arch, ref, version}`,
  `platform_button_click {platform}`, `release_link_click`, `faq_open {id}`.
  Provider: Plausible/Umami or GA — Plausible's script tag fits the no-cookie
  ethos; decision deferred, taxonomy is the contract.
- UTM all outbound GitHub links (`?source=landing-hero` etc.) so release-page
  traffic attribution is clean.
- Local, privacy-respecting: no PII, keys out of the repo (`--dart-define` lake:
  `ANALYTICS_SCRIPT_URL`).

---

## Phase 4 — Verification (evidence, per Atlas rules)

New tests (mirror under `test/marketing/…`):

1. `device_profile_test.dart` — UA-string matrix (each OS + Apple-silicon
   heuristic), detect-never-throws, memoization.
2. `release_asset_resolver_test.dart` — exact priority, universal fallback,
   unresolved→release-page, naming-contract fixtures (windows-x64, android
   universal vs split, macos-arm64), old-tag backward compat.
3. `landing_download_cta_test.dart` — resolved label text, size humanization,
   secondary-grid "your device" highlight, all four states, anchor `download`
   attribute present (via a test hook exposing the resolved URL).
4. `landing_screen_test.dart` update — new sections exist, anchors still
   resolve, `/download` route interstitial fires exactly once.
5. `site_meta` smoke: assert index.html (parsed fixture) contains the required
   OG keys + JSON-LD.

Verification commands (must be green before merge):

```
flutter analyze --no-fatal-infos      # zero warnings gate
flutter test test/marketing
flutter test                          # full suite, no regressions
flutter build web --release           # ship artifact proof
flutter build windows --debug         # module still compiles for desktop targets
```

Demo: `flutter run -d chrome` → DevTools device styles — verify detection on
(1) Chrome/Windows UA-CH (2) Safari desktop (3) Safari iPhone emulation
(4) Firefox → fallback states.

## Phasing / cut lines

- **Ship batch 1** (this plan's phases 1 + 4): smart download end-to-end.
- **Ship batch 2** (phases 2 + 3): page marketing polish + SEO.
- **Follow-up tickets, out of scope here**: macOS/Linux/ARM64 CI build jobs
  surface as resolver work only when their artifacts appear; localized landing
  (l10n) — landing content is now duplicated-strings-only, extracted into
  `landing_content.dart` so future locales are cheap; screenshot PR pipeline
  (auto-capture release screenshots into the release workflow) — content
  vending, not the landing surface itself.

## Risks

- **Asset prediction vs reality**: users can rename/release-drop assets or
  attach new platforms — every guess degrades to the releases page
  (`isExactMatch: false`) rather than a dead link. Mitigation is in the
  contract, and CI's `if-no-files-found: error` keeps the feed honest.
- **Detection drift**: UA-UA-CH deprecation pattern means the settled matrix
  heuristics will need future upkeep — detection is confined to one service
  file with the fixtures in tests, not sprinkled through widgets.
- **Canvas SEO**: Flutter web is canvaskit; words live in shaders. `noscript`
  + rich `head` metadata is the honest best-high-value workaround; if real
  indexability of the *content* becomes a priority later, that's an SSR or
  static pre-render migration, tracked separately.
- **Windows-ARM vs x64**: today the only Windows artifact is x64 (runs under
  emulation for Apple *and* Windows-on-ARM users), so resolver defaults to
  x64 + display note. Per the contract, when an ARM artifact shows up it
  auto-wins on arm detection.
- **Over-marketing the `0` state**: while no macOS/Linux artifacts exist, the
  secondary grid shows the platform pill taps release page instead of fake
  APks — detection still says "macOS detected; release page" honestly.

## Open questions (decide at kickoff)

1. Deployment root + canonical domain (affects OG URLs, sitemap/robots).
2. Analytics provider decision (Plausible vs GA) — taxonomy already fixed.
3. Split-per-abi Android persists (3 assets) vs universal-APK — affects
   resolver fixture set and CI build time (~3× zip size).
4. App Store vs TestFlight availability for the iOS pin (resolver today links
   to releases page with honest "coming soon" already? or kill the iOS button
   now?).
