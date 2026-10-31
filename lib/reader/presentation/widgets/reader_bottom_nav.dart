import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/presentation/providers/dock_prefs_provider.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_dock_customize_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_quick_settings_sheet.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

/// Reader dock rendered as the demo's floating pill: it toggles between the
/// tucked-away **spine** (reading-dot · chapter-% · clock · battery, one slim
/// row) and the expanded **capsule** (prev / next chapter at the ends, the
/// customizable action row and the scrub rail). While narration or auto-scroll
/// is running the pill morphs into that transport exclusively. The row and
/// what the spine shows can be customized via [readerDockPrefsProvider]
/// (More menu, or long-press on the spine); prefs persist between sessions.
class ReaderBottomNav extends HookConsumerWidget {
  const ReaderBottomNav({
    super.key,
    required this.textColor,
    required this.onSettingsTap,
    required this.onChapterIndexTap,
    required this.onBookmarkTap,
    this.isBookmarked = false,
    this.currentChapterTitle,
    this.currentChapterNumber,
    this.totalChapters,
    this.autoScrollActive = false,
    this.onAutoScrollToggle,
    this.autoScrollPaused = false,
    this.onAutoScrollPauseToggle,
    this.autoScrollSpeed,
    this.onAutoScrollSpeedChanged,
    this.bookTitle,
    this.coverPath,
    this.progress,
    this.progressColor,
    this.onListenTap,
    this.onAnnotationsTap,
    this.onSearchTap,
    this.onIntelligenceTap,
    this.onRedownload,
    this.isRedownloading = false,
    this.onScrubToChapter,
    this.onCustomize,
    this.onPrevChapter,
    this.onNextChapter,
    this.chromeStyle = ReaderChromeStyle.translucent,
  });

  final Color textColor;

  /// Opens the full reading settings (reached from the Aa quick sheet).
  final VoidCallback onSettingsTap;
  final VoidCallback onChapterIndexTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onAnnotationsTap;
  final bool isBookmarked;
  final String? currentChapterTitle;
  final int? currentChapterNumber;
  final int? totalChapters;
  final bool autoScrollActive;
  final VoidCallback? onAutoScrollToggle;

  /// Pause/resume and speed feedback while auto-scroll is running (speed in
  /// engine units, "px per 50 ms tick"; see [ReaderDockPrefs.autoScrollSpeed]).
  final bool autoScrollPaused;
  final VoidCallback? onAutoScrollPauseToggle;
  final double? autoScrollSpeed;
  final ValueChanged<double>? onAutoScrollSpeedChanged;
  final String? bookTitle;
  final String? coverPath;

  /// Normalized in-chapter progress (0..1), shown as a percentage. Passed as
  /// a listenable so the dock tracks scrolling without rebuilding.
  final ValueListenable<double>? progress;
  final Color? progressColor;

  /// Overrides the Listen button action (e.g. desktop opens the narration
  /// panel instead of the bottom sheet). Falls back to [NowPlayingSheet.show].
  final VoidCallback? onListenTap;

  final VoidCallback? onSearchTap;
  final VoidCallback? onIntelligenceTap;
  final VoidCallback? onRedownload;
  final bool isRedownloading;

  /// Called with a 0-based chapter index when the chapter strip is released.
  /// When null the strip is display-only.
  final ValueChanged<int>? onScrubToChapter;

  /// When given, replaces the built-in customize sheet opener (used by the
  /// chapter-strip long-press). Tests inject a no-op here.
  final VoidCallback? onCustomize;

  /// Demo's fixed chapter edge buttons. Rendered at the capsule's ends only
  /// when wired; null (already at the book boundary) hides them.
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;

  /// Reader chrome style, threaded from the mounting layout's settings.
  /// [ReaderChromeStyle.glass] renders the dock capsule on the liquid-glass
  /// [ReaderPillSurface]; every other value keeps the classic shell.
  final ReaderChromeStyle chromeStyle;

  void _openNowPlaying(BuildContext context) {
    HapticFeedback.selectionClick();
    final custom = onListenTap;
    if (custom != null) {
      custom();
      return;
    }
    NowPlayingSheet.show(
      context,
      chapterTitle: currentChapterTitle,
      bookTitle: bookTitle,
      coverPath: coverPath,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final batteryLevel = ref.watch(liveBatteryLevelProvider).valueOrNull;
    final charging = ref.watch(liveChargingProvider).valueOrNull ?? false;
    final accent = progressColor ?? textColor;

    // Customizable action row: the user's order wins; unavailable, promoted
    // actions (e.g. flow in layouts without auto-scroll) are filtered out.
    final prefs = ref.watch(readerDockPrefsProvider);
    final spine = prefs.spine;
    final actions = prefs.normalizedActions();

    final registry = <ReaderDockAction, _DockActionDescriptor>{
      ReaderDockAction.contents: const _DockActionDescriptor(
        id: ReaderDockAction.contents,
        icon: Icons.format_list_numbered_rounded,
        label: 'Contents',
      ),
      if (onAnnotationsTap != null)
        ReaderDockAction.annotations: const _DockActionDescriptor(
          id: ReaderDockAction.annotations,
          icon: Icons.sticky_note_2_outlined,
          label: 'Notes',
        ),
      ReaderDockAction.listen: const _DockActionDescriptor(
        id: ReaderDockAction.listen,
        icon: Icons.headphones_rounded,
        label: 'Listen',
      ),
      ReaderDockAction.aa: const _DockActionDescriptor(
        id: ReaderDockAction.aa,
        icon: Icons.text_fields_rounded,
        label: 'Aa',
      ),
      if (onAutoScrollToggle != null)
        ReaderDockAction.flow: _DockActionDescriptor(
          id: ReaderDockAction.flow,
          icon: autoScrollActive ? Icons.bolt_rounded : Icons.bolt_outlined,
          label: 'Auto-scroll',
        ),
      if (onSearchTap != null)
        ReaderDockAction.search: const _DockActionDescriptor(
          id: ReaderDockAction.search,
          icon: Icons.search_rounded,
          label: 'Search',
        ),
      if (onIntelligenceTap != null)
        ReaderDockAction.atlas: const _DockActionDescriptor(
          id: ReaderDockAction.atlas,
          icon: Icons.psychology_outlined,
          label: 'Atlas',
        ),
      if (onRedownload != null)
        ReaderDockAction.redownload: _DockActionDescriptor(
          id: ReaderDockAction.redownload,
          icon: isRedownloading
              ? Icons.refresh_rounded
              : Icons.refresh_outlined,
          label: isRedownloading ? 'Redownloading…' : 'Redownload',
        ),
    };

    final moreItems = registry.entries
        .where((e) => !actions.contains(e.key))
        .map((e) => e.value)
        .toList();

    final callbacks = <ReaderDockAction, VoidCallback>{
      ReaderDockAction.contents: onChapterIndexTap,
      ReaderDockAction.annotations: onAnnotationsTap ?? onChapterIndexTap,
      ReaderDockAction.listen: () => _openNowPlaying(context),
      ReaderDockAction.aa: () {
        HapticFeedback.selectionClick();
        ReaderQuickSettingsSheet.show(
          context,
          onAllSettings: onSettingsTap,
        );
      },
      ReaderDockAction.flow: () => onAutoScrollToggle?.call(),
      ReaderDockAction.search: () => onSearchTap?.call(),
      ReaderDockAction.atlas: () => onIntelligenceTap?.call(),
      ReaderDockAction.redownload: () => onRedownload?.call(),
    };

    void showCustomizeSheet(BuildContext ctx) =>
        ReaderDockCustomizeSheet.show(
          ctx,
          availablePromotable: registry.keys.toList(),
        );

    void openCustomize() {
      final override = onCustomize;
      if (override != null) {
        override();
      } else {
        showCustomizeSheet(context);
      }
    }

    // Demo layer priority — narration > auto-scroll > expanded capsule >
    // tucked-away spine. Detected the same way [NarrationMiniPlayer] does.
    final engine = ref.watch(speechEngineProvider);
    final session = engine.session;
    final narrStatus =
        ref.watch(narrationStatusProvider).valueOrNull ?? NarrationStatus.idle;
    final narrating = session != null &&
        session.queue.isNotEmpty &&
        narrStatus != NarrationStatus.idle;

    final expanded = useState(false);

    // Demo-like fit-content pill: in capsule mode its width hugs the button
    // row, and the scrub rail stretches to that exact width. All dock buttons
    // have fixed geometry (44px, 40px edges, 4px gaps), so the row width is
    // known. Button count = prev/next edges + visible actions + More.
    final visibleActionCount = actions
        .where((id) => registry.containsKey(id))
        .length;
    final buttonCount =
        (onPrevChapter != null ? 1 : 0) +
        (onNextChapter != null ? 1 : 0) +
        visibleActionCount +
        1; // + More
    final capsuleRowWidth = 20.0 +
        (onPrevChapter != null ? _NavIconButton.edgeSize.toDouble() : 0.0) +
        (onNextChapter != null ? _NavIconButton.edgeSize.toDouble() : 0.0) +
        _NavIconButton.size * (visibleActionCount + 1) + // + More
        4.0 * (buttonCount - 1);
    final scrubRailWidth = capsuleRowWidth - 20.0;

    final colorScheme = Theme.of(context).colorScheme;

    Widget layer;
    if (narrating) {
      layer = _NarrationStrip(
        textColor: textColor,
        accent: accent,
        onOpen: () => _openNowPlaying(context),
      );
    } else if (autoScrollActive) {
      layer = Padding(
        padding: const EdgeInsets.all(4),
        child: AutoScrollStrip(
          textColor: textColor,
          accent: accent,
          paused: autoScrollPaused,
          speed: autoScrollSpeed ?? 2.0,
          onTogglePause: onAutoScrollPauseToggle,
          onStop: onAutoScrollToggle,
          onSpeedChanged: onAutoScrollSpeedChanged,
        ),
      );
    } else if (expanded.value) {
      layer = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                if (onPrevChapter != null)
                  _NavIconButton(
                    icon: Icons.chevron_left_rounded,
                    label: 'Previous chapter',
                    textColor: textColor,
                    edge: true,
                    onTap: onPrevChapter!,
                  ),
                for (final id in actions)
                  if (registry[id] != null)
                    _NavIconButton(
                      icon: registry[id]!.icon,
                      label: registry[id]!.label,
                      textColor: textColor,
                      onTap: callbacks[id]!,
                    ),
                PopupMenuButton<String>(
                  position: PopupMenuPosition.over,
                  onSelected: (value) {
                    if (value == 'customize') {
                      openCustomize();
                      return;
                    }
                    final cb = ReaderDockAction.tryParse(value) == null
                        ? null
                        : callbacks[ReaderDockAction.tryParse(value)!];
                    if (cb != null) cb();
                  },
                  itemBuilder: (_) => [
                    for (final item in moreItems)
                      PopupMenuItem(
                        value: item.id.jsonName,
                        child: ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (moreItems.isNotEmpty) const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'customize',
                      child: ListTile(
                        leading: Icon(Icons.tune_rounded),
                        title: Text('Customize dock'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: IgnorePointer(
                    child: _NavIconButton(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      textColor: textColor,
                      onTap: () {},
                    ),
                  ),
                ),
                if (onNextChapter != null)
                  _NavIconButton(
                    icon: Icons.chevron_right_rounded,
                    label: 'Next chapter',
                    textColor: textColor,
                    edge: true,
                    onTap: onNextChapter!,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            child: SizedBox(
              width: scrubRailWidth,
              child: _ChapterStrip(
                textColor: textColor,
                accent: accent,
                chapterIndex: currentChapterNumber ?? 0,
                totalChapters: totalChapters ?? 0,
                progress: progress,
                onScrubToChapter: onScrubToChapter,
              ),
            ),
          ),
        ],
      );
    } else {
      layer = _SpineRow(
        textColor: textColor,
        accent: accent,
        chapterIndex: currentChapterNumber ?? 0,
        totalChapters: totalChapters ?? 0,
        progress: progress,
        showProgress: spine.chapterProgress,
        showClock: spine.clock,
        showBattery: spine.battery,
        clock: _ClockIndicator(textColor: textColor),
        battery: _BatteryIndicator(
          level: batteryLevel,
          charging: charging,
          textColor: textColor,
        ),
        hairColor: colorScheme.onSurface.withValues(alpha: 0.10),
        onTap: () {
          HapticFeedback.selectionClick();
          expanded.value = true;
        },
        onLongPress: openCustomize,
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TapRegion(
            groupId: 'reader-dock',
            onTapOutside: (_) {
              if (expanded.value) expanded.value = false;
            },
            child: ReaderPillSurface(
              colorScheme: colorScheme,
              glass: chromeStyle == ReaderChromeStyle.glass,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: layer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One candidate action in the customizable row. Availability is decided by
/// the mounting layout (which callbacks it passes); ordering/visibility comes
/// from [readerDockPrefsProvider].
class _DockActionDescriptor {
  const _DockActionDescriptor({
    required this.id,
    required this.icon,
    required this.label,
  });

  final ReaderDockAction id;
  final IconData icon;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _DockActionDescriptor &&
      other.id == id &&
      other.icon == icon &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, icon, label);
}

/// Auto-scroll transport strip, shown pinned under the chrome (inside the
/// dock while chrome is visible, or floating above [NarrationMiniPlayer] when
/// the chrome is hidden). Same visual language as the narration strip.
class AutoScrollStrip extends StatelessWidget {
  const AutoScrollStrip({
    super.key,
    required this.textColor,
    required this.accent,
    required this.paused,
    required this.speed,
    this.onTogglePause,
    this.onStop,
    this.onSpeedChanged,
  });

  final Color textColor;
  final Color accent;

  /// Engine units: px per 50 ms tick (1–6), shown as px/s.
  final bool paused;
  final double speed;
  final VoidCallback? onTogglePause;
  final VoidCallback? onStop;
  final ValueChanged<double>? onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final pxPerSecond = (speed * 20).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onTogglePause != null)
            IconButton(
              tooltip: paused ? 'Resume' : 'Pause',
              color: textColor,
              icon: Icon(
                paused ? Icons.play_circle_filled : Icons.pause_circle_filled,
                size: 30,
              ),
              onPressed: onTogglePause,
            ),
          if (onSpeedChanged != null)
            IconButton(
              tooltip: 'Slower',
              color: textColor,
              icon: const Icon(Icons.remove_rounded, size: 20),
              onPressed: () => onSpeedChanged!(speed - 0.5),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              paused
                  ? 'Auto-scroll paused'
                  : 'Auto-scrolling · $pxPerSecond px/s',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (onSpeedChanged != null)
            IconButton(
              tooltip: 'Faster',
              color: textColor,
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => onSpeedChanged!(speed + 0.5),
            ),
          if (onStop != null)
            IconButton(
              tooltip: 'Stop auto-scroll',
              color: textColor,
              icon: const Icon(Icons.close_rounded),
              onPressed: onStop,
            ),
        ],
      ),
    );
  }
}

/// Compact transport shown inside the pill while narration is playing or
/// paused — the dock morphs into this row exclusively (demo `layer-narr`).
class _NarrationStrip extends ConsumerWidget {
  const _NarrationStrip({
    required this.textColor,
    required this.accent,
    required this.onOpen,
  });

  final Color textColor;
  final Color accent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(speechEngineProvider);
    final session = engine.session;
    if (session == null || session.queue.isEmpty) {
      return const SizedBox.shrink();
    }
    final status =
        ref.watch(narrationStatusProvider).valueOrNull ?? NarrationStatus.idle;
    if (status == NarrationStatus.idle) return const SizedBox.shrink();
    final playing = status == NarrationStatus.playing;
    final rate =
        ref.watch(narrationSettingsProvider).valueOrNull?.speechRate ??
        session.settings.speechRate;
    final actionLabel = playing ? 'Narrating' : 'Paused';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Resume',
              color: textColor,
              icon: Icon(
                playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 30,
              ),
              onPressed: () =>
                  unawaited(playing ? engine.pause() : engine.resume()),
            ),
            IconButton(
              tooltip: 'Next sentence',
              color: textColor,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: () => unawaited(engine.skipNext()),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                child: Text(
                  '$actionLabel · ${rate.toStringAsFixed(1)}×',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Stop narration',
              color: textColor,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => unawaited(engine.stop()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The demo's tucked-away spine: one slim row with the reading pulse-dot, the
/// chapter label (+ dimmed %), hairline separators and clock/battery per
/// prefs, and an expand chevron. Tap expands the dock into the capsule;
/// long-press opens the Customize sheet.
class _SpineRow extends StatelessWidget {
  const _SpineRow({
    required this.textColor,
    required this.accent,
    required this.chapterIndex,
    required this.totalChapters,
    required this.progress,
    required this.showProgress,
    required this.showClock,
    required this.showBattery,
    required this.clock,
    required this.battery,
    required this.hairColor,
    required this.onTap,
    required this.onLongPress,
  });

  final Color textColor;
  final Color accent;
  final int chapterIndex;
  final int totalChapters;
  final ValueListenable<double>? progress;
  final bool showProgress;
  final bool showClock;
  final bool showBattery;
  final Widget clock;
  final Widget battery;
  final Color hairColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: textColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final pctStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: textColor.withValues(alpha: 0.55),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final base = totalChapters > 0
        ? 'Ch. ${chapterIndex + 1} of $totalChapters'
        : 'Ch. ${chapterIndex + 1}';

    Widget label;
    if (!showProgress || progress == null) {
      label = Text(base, style: labelStyle);
    } else {
      label = ValueListenableBuilder<double>(
        valueListenable: progress!,
        builder: (_, value, _) => Text.rich(
          TextSpan(
            text: base,
            style: labelStyle,
            children: [
              const TextSpan(text: '  '),
              TextSpan(
                text: '${(value.clamp(0.0, 1.0) * 100).round()}%',
                style: pctStyle,
              ),
            ],
          ),
        ),
      );
    }

    final sep = Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: hairColor,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (_) {
        HapticFeedback.selectionClick();
        onLongPress();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            label,
            if (showClock) ...[sep, clock],
            if (showClock && showBattery) sep,
            if (showBattery) ...[sep, battery],
            const SizedBox(width: 10),
            Icon(
              Icons.expand_less_rounded,
              size: 18,
              color: textColor.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

/// The expanded capsule's scrub rail. Dragging previews "Go to Ch. X";
/// releasing jumps.
class _ChapterStrip extends HookWidget {
  const _ChapterStrip({
    required this.textColor,
    required this.accent,
    required this.chapterIndex,
    required this.totalChapters,
    this.progress,
    this.onScrubToChapter,
  });

  final Color textColor;
  final Color accent;
  final int chapterIndex;
  final int totalChapters;
  final ValueListenable<double>? progress;
  final ValueChanged<int>? onScrubToChapter;

  @override
  Widget build(BuildContext context) {
    final drag = useState<double?>(null);
    final canScrub = onScrubToChapter != null && totalChapters > 1;
    final idle = totalChapters > 1 ? chapterIndex / (totalChapters - 1) : 0.0;
    final fraction = (drag.value ?? idle).clamp(0.0, 1.0);
    final previewIndex = totalChapters > 1
        ? (fraction * (totalChapters - 1)).round()
        : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (drag.value != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Go to Ch. ${previewIndex + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            void setFromDx(double dx) {
              drag.value = (dx / width).clamp(0.0, 1.0);
            }

            return Semantics(
              slider: canScrub,
              label: 'Chapter position',
              value: 'Chapter ${chapterIndex + 1} of $totalChapters',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: canScrub
                    ? (d) => setFromDx(d.localPosition.dx)
                    : null,
                onHorizontalDragUpdate: canScrub
                    ? (d) => setFromDx(d.localPosition.dx)
                    : null,
                onHorizontalDragEnd: canScrub
                    ? (_) {
                        final target = previewIndex;
                        drag.value = null;
                        HapticFeedback.selectionClick();
                        onScrubToChapter!(target);
                      }
                    : null,
                onHorizontalDragCancel: canScrub ? () => drag.value = null : null,
                child: SizedBox(
                  height: 28,
                  // All rules are Positioned so the Stack's *intrinsic*
                  // width stays finite (0) — IntrinsicWidth up the tree then
                  // drives the rail to the button row's width, exactly like
                  // the demo's CSS fit-content pill.
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        bottom: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 12,
                        bottom: 12,
                        width: width * fraction,
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (canScrub)
                        Positioned(
                          left: (fraction * width - 7).clamp(0.0, width - 14),
                          top: 7,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Color(0x33000000), blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ClockIndicator extends HookWidget {
  const _ClockIndicator({required this.textColor});

  final Color textColor;

  static String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour == 0
        ? 12
        : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final timeString = useState(_formatCurrentTime());

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        timeString.value = _formatCurrentTime();
      });
      return timer.cancel;
    }, const []);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        timeString.value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor.withValues(alpha: 0.55),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
    this.edge = false,
  });

  /// Demo `.dock-btn` geometry, mobile-friendly: 44px Material-guided touch
  /// targets with 22px glyphs; prev/next stay slightly slimmer (40px).
  static const double size = 44;
  static const double edgeSize = 40;
  static const double iconSize = 22;
  static const double edgeIconSize = 20;

  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  /// Demo `.dock-btn.edge`: slightly slimmer prev/next chapter buttons.
  final bool edge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: edge ? edgeSize : size,
            height: size,
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: edge ? edgeIconSize : iconSize,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({
    required this.level,
    required this.textColor,
    this.charging = false,
  });

  final double? level;
  final Color textColor;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final pct = level != null ? (level! * 100).round() : null;

    final IconData icon;
    if (charging) {
      icon = Icons.battery_charging_full_rounded;
    } else {
      icon = switch (pct) {
        null => Icons.battery_unknown_rounded,
        >= 80 => Icons.battery_full_rounded,
        >= 50 => Icons.battery_5_bar_rounded,
        >= 20 => Icons.battery_3_bar_rounded,
        _ => Icons.battery_alert_rounded,
      };
    }

    final label = pct != null ? '$pct%' : '100%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.55),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

