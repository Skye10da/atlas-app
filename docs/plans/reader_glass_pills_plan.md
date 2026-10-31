# Plan — Glass Effect for Reader Pills

## Goal
Give the reader's floating pill chrome the same "liquid glass" language as the
shell nav (vibrancy + specular rim + spring droplet), while preserving:
- The existing per-item persistence (`ReaderChromeStyle{ translucent, frosted }`
  in `reading_preferences.dart`) — reader chrome gets a `glass` style value.
- The reader's interactive contract: taps on empty pill space **fall through to
  the page underneath** (already asserted by existing tests).
- Reading performance: no saveLayers inside the (already heavy) page backdrop;
  blur must not cover live text pages when animating.

## Inventory of pill surfaces (current state)

| Surface | File | Today |
|---|---|---|
| Shared pill shell | `lib/reader/presentation/widgets/reader_bar_surface.dart` (`ReaderPillSurface`) | blur 20 + 0.72 surface fill + hairline — 80% glass already, no vibrancy/specular |
| Reader dock capsule | `reader_bottom_nav.dart:405` → `ReaderPillSurface` | morphs to narration transport |
| Slim top-bar pills (back/title/bookmark) | `reader_chrome_bar.dart` (3 × `ReaderPillSurface`) | individual pills sharing one shell |
| Narration rate pill | `narration_speed_control.dart` | own decoration, no blur |
| Chapter status pill | `chapter_shimmer.dart` `_StatusPill` (2 call sites) | own decoration, solid-ish |
| Density pills (settings preview) | `settings/theme_tab.dart` `_DensityPill` | static, skip (not chrome) |
| `ReaderBarSurface` (frosted/translucent full-width bars) | `reader_bar_surface.dart:66` | edge-to-edge bars — separate decision, out of scope phase 1 |

## Phase 0 — Lift design-system primitives
`GlassCapsule` (`atlas_glass_nav_bar.dart`) does vibrancy matrix (1.6×
saturation), specular gradient rim, and clipped shadows — but `_SpecularBorderPainter`
is library-private and readers only import the organism file.

1. Move `GlassCapsule`, `GlassLens`, `_SpecularBorderPainter`, `_saturation` from
   `atlas_glass_nav_bar.dart` into a new
   `lib/core/design_system/molecules/glass_surfaces.dart` (nav bar file re-exports
   them so existing imports keep working).
2. Extend `GlassCapsule` with a `pill: true` convenience mode that clamps radius to `999` and reduces blur (reader pills sit over live text: blur 16–20 instead of 24–28), plus an optional `interactive: false` mode that installs `IgnorePointer`-transparent hit-testing so empty areas fall through.

## Phase 1 — Reroute `ReaderPillSurface` through `GlassCapsule`
Single point of change; dock + slim bars inherit automatically.

- `ReaderPillSurface.build` keeps its API (`colorScheme`, `child`) and its
  `tap-falls-through` ink contract (keep inner `Material(type: transparency)`).
- Replace generic `blur(20)` + fill with `GlassCapsule(pill, blur: 20,
  vibrancy: 1.6, strong: false)`; keep the existing drop shadow parameters
  (matching current visual weight, only migrated into capsule's painter path).
- Gate: a static `useGlass` flag module-level constant derived from
  `readingSettingsProvider` *is not reachable* here — `ReaderPillSurface` is
  theme-only. Add optional param `glass: bool` (default true) and let call sites
  pass their chrome style; default call sites in dock/chrome bar watch the
  reader settings provider once at the shell level and thread it down.

## Phase 2 — Per-pill one-offs
1. `narration_speed_control.dart`: convert decoration to `GlassCapsule(pill)`
   wrapper — small; reuse `GlassLens` for the *selected* rate value highlight
   (droplet = current speed chip), driven by simple
   `AnimatedPositioned` (no spring needed at 1-row granularity).
2. `chapter_shimmer.dart` `_StatusPill`: `GlassCapsule(pill, blur: 24)`;
   keep the bouncing-dots shimmer inside; verify over both light/dark page
   screenshots and over images (blur cost + legibility).
3. Narration transport morph (dock): when morphing pill → transport, animate
   `blur`/fill opacity cross-fade (backdrop blur animates poorly on Windows —
   animate the *fill/rim* only, blur sigma fixed).

## Phase 3 — Settings & persistence
1. Add `ReaderChromeStyle.glass` to the enum in
   `settings/domain/value_objects/reading_preferences.dart` with label
   'Liquid Glass' / icon `Icons.auto_awesome`.
2. `shared_prefs_settings_repository.dart:144`: map `'glass'` string; unknown
   strings keep defaulting to translucent.
3. `/layout_tab.dart:262`: add third segment to the chrome-style chooser.
4. Migration note: existing `nav_chrome_style` settings remain independent —
   reader chrome is per-reader, deliberate.

## Phase 4 — Verification
1. Component tests (`test/reader/glass_pill_surface_test.dart`):
   - glass surface renders + vibrancy/specular painter present (painter type),
     blur path active.
   - **tap-through contract intact**: hit test on pill center with no child
     button falls to the page widget behind (regression for the reader's
     biggest UX feature).
   - narration speed pill selects value → GlassLens highlight positioned on it.
2. Settings tests: enum serialize round-trip ('glass' ↔ `ReaderChromeStyle.glass`),
   default migration for corrupt values.
3. Golden-ish visual: manual pass on Windows build over (a) long text page,
   (b) image-adapter page, (c) PDF page — check legibility + blur artifacts.
4. Perf guard: run existing reader perf tests (if any) — blur added per pill
   must not regress frame budget on the paging benchmark (>16ms frames check).

## Out of scope / future
- `ReaderBarSurface` edge-to-edge bars (different compositional problem —
  full-width frosted bars).
- Lens physics (spring/velocity) **inside** reader pills: only the speed pill
  gets a mini droplet; the dock keeps its segmented strip. Drag-across like
  the navbar only if user feedback asks for it.
- Web/HTML: BackdropFilter renders differently — same code path is fine (the
  current ReaderPillSurface already ships blur).

## Risks
- **SaveLayer count**: dock bar + chrome bar pills in the same frame = 2–4
  backdrop blurs over text. Mitigation: keep shared pill blur at 16–20 sigma
  and reuse phase 0 `GlassCapsule`'s `skipDropShadow` when pills nest.
- **After the morph**: the dock's capsule↔transport morph re-lays out the pill;
  specular rim painter is pure decoration — verify no flicker when remounting.
- Reader theme previews use fixed `ReaderChromeStyle.translucent`
  (`pdf_reader_previews.dart`) — previews should offer both variants.
