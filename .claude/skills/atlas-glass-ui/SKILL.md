---
name: atlas-glass-ui
description: Liquid-glass design conventions for the Atlas app. Use when building
  or restyling Atlas UI with a frosted, translucent, glassmorphism, or "liquid
  glass" look - navigation chrome (bottom bar, rail, desktop sidebar), pills,
  sheets, popovers, or any surface over scrolling content. Covers the shared
  GlassCapsule, GlassLens droplet, spring physics constants, the three layout
  gotchas that crash or fullscreen-stretch glass containers, and how
  navChromeProvider / ReaderChromeStyle persistence works.
---

# Atlas Liquid Glass UI

Build any frosted, translucent, or "liquid glass" surface in the Atlas Flutter
app with the shared design-system primitives - never hand-roll a new
BackdropFilter decoration. Hand-rolled glass is why `ReaderPillSurface`,
`ReaderBarSurface` and `_StatusPill` exist as separate one-off implementations
pending migration (see docs/plans/reader_glass_pills_plan.md).

## The three primitives (use these, in order)

All live in `lib/core/design_system/organisms/atlas_glass_nav_bar.dart`
(Planned move: `lib/core/design_system/molecules/glass_surfaces.dart` - when
moving, re-export from the old file so existing imports keep working).

1. **GlassCapsule** - the frosted panel: backdrop blur + 1.6x saturation boost
   ("vibrancy"), translucent twin-gradient fill, specular gradient hairline rim,
   outside-clipped drop shadow. This is your generic glass surface.

   ```dart
   GlassCapsule(
     borderRadius: 24,        // use 999 for a pill
     blur: 28,                // reader pills over live text: 16-20
     strong: false,           // true = thicker rim (solo floating panels)
     skipDropShadow: false,   // true when nested inside another capsule
     child: ...,
   )
   ```

2. **GlassLens** - the accent droplet behind a selected item. Pure decoration,
   sizes to its parent box. `radius` should be half the droplet height.

   ```dart
   GlassLens(accent: cs.primary, isDark: ..., radius: slotHeight / 2)
   ```

3. **AtlasGlassNavBar / AtlasGlassRail** - finished horizontal (phone bottom) and
   vertical (tablet dock) navigation with the droplet on spring physics. Use
   these first; only reach for raw GlassCapsule for non-nav surfaces.

## Spring metrology (do not re-tune)

- `SpringDescription(mass: 1, stiffness: 220, damping: 18)` - underdamped, small
  liquid overshoot.
- Run position math in *slot units* on uniform grids (navbar/rail):
  `AnimationController.unbounded` + `_ctrl.animateWith(SpringSimulation(...))`.
- Variable-height rows (desktop sidebar slots) can't use slot units - measure
  each slot with GlobalKeys and animate in *pixel* space instead; velocity
  stretch factor becomes per-pixel: `(_ctrl.velocity.abs() * 0.0012).clamp(0, 0.3)`.
- Velocity stretch: stretch along the motion axis (`1 + stretch`), squash across
  it by `0.45` (nav bar). Press swell: `AnimatedScale(1.12, easeOutBack, 180ms)`.
- Always respect `MediaQuery.disableAnimationsOf(context)` - jump straight to
  the target.

## Slot / action-slot math

N sp destinations + 1 optional action (Atlas "+" `AtlasNavAction`) = slots.
The action sits at `actionSlot = items.length ~/ 2`. The lens travels *through*
the action slot without stopping; taps on it resolve the action, never
selection. Keep the same skip logic for any new slot-based surface:

```dart
int _slotOf(int dest) => dest < actionSlot ? dest : dest + 1;
int slotIndex = ...; // slot > actionSlot => dest = slot - 1; slot == actionSlot => action
```

## Layout gotchas - read before placing ANY glass widget

These three bit us in production; they belong to any glass surface anchored in
a Stack, Scaffold slot, or overflow-free Row/Column:

1. **Positioned without both edges gives unbounded cross-axis.**
   `Positioned(left: 8, top: 8, bottom: 8, child: verticalWidget)` hands the
   child an infinite width. A vertical rail's inner `Column` propagates it and
   the first `Infinity`-sized descendant makes the layout engine throw.
   Fix inside the component, so it's safe in any parent:
   `SizedBox(width: componentWidth, child: core)`.

2. **A filling Center in a Scaffold bottom slot grows the bar to the window.**
   `Center` with no `widthFactor`/`heightFactor` expands to fill the available
   cross axis. Inside `Scaffold.bottomNavigationBar` (bounded-by-window, not
   intrinsically sized), every row inherits the window height and the capsule
   becomes fullscreen. Fix: `Center(heightFactor: 1)` (horizontal nav) or
   `Center(widthFactor: 1)` (vertical).

3. **Stack children overlap.** If slots are laid out as direct Stack children
   they all pile at the top-left. The Stack is a *lens canvas* only; put the
   interactive children in a real `Column`/`Row` as its non-positioned child
   (`mainAxisSize.min`), and let the droplet be the single `Positioned` child.

Where all three apply at once: `_SidebarNavList` in
`lib/core/design_system/organisms/app_scaffold.dart` is the reference.

## Chrome wiring (how glass-vs-classic toggles work)

- Shell nav: `navChromeProvider` in
  `lib/core/design_system/nav_chrome_providers.dart` -
  `NavChromeStyle { glass, classic }`, persisted via SharedPreferences key
  `nav_chrome_style`, default **glass**. Toggle card lives in
  Settings > Appearance ("Navigation Style").
- Per-layout blend rules (all in `app_scaffold.dart` under `if (glass)` branches):
  - Mobile: floating `AtlasGlassNavBar` in `Scaffold.bottomNavigationBar` +
    `extendBody: true`; lift the `NarrationMiniPlayer` to `bottom: 96` to clear
    the bar.
  - Tablet: `AtlasGlassRail` in a `Positioned(left: 8, top: 8, bottom: 8)` dock
    overlay (rail self-bounds to width 76 + padding); content inset left by 96.
  - Desktop: the sidebar interior `_DesktopSidebar(glass: true)` sits inside a
    `GlassCapsule(borderRadius: 24, blur: 24)` floating overlay; content inset
    is `sidebarWidth + 12 + 8`; in-glass nav items drop their solid
    `secondaryContainer` pill - the tint + droplet do the job.
- Glass is the default in new work; keep the classic branch rendering the
  original widget so the toggle stays honest. Each layout's page content is
  wrapped in `_PageGlanceReveal` (glass only) - a 340ms easeOutBack slide-up +
  fade that must NOT remount the child subtree (pass the same child widget; only
  replay a controller on index change), or go_router shell state dies.

## Sizing rules

- Bar height 68 (mobile), rail width 76 (tablet), sidebar capsule blur 24 /
  radius 24 (desktop), pill blur 16-20 over text.
- Keep blur/gradient constants on the component, not the call site.
- Over images or live text, prefer lower blur + higher fill alpha over
  high blur; check legibility in both themes before shipping.

## Testing glass components

Component tests live in `test/core/atlas_glass_nav_bar_test.dart` and
`test/core/desktop_sidebar_glass_test.dart`. Two conventions worth copying:

- Measure rails/bars with `tester.getRect` and assert geometry (bottom-anchored,
  height < 120) - fullscreen-stretch regressions are geometry bugs and show up here.
- For hooks or private widgets, expose a thin `@visibleForTesting` wrapper (see
  `AtlasSidebarGlassNavList` in app_scaffold.dart) rather than testing through
  the whole shell/router.
- After layout-affecting changes run: `dart analyze lib test`,
  `flutter test test/core`, `flutter build windows --debug` (build fails if the
  running debug app still locks WebView2Loader.dll - close/kill atlas_app.exe
  and rebuild).
