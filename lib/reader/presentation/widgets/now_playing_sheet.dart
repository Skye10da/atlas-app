import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/cover_palette_service.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/narration_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/voice_gallery_sheet.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';

/// "Now Playing" narration stage, Apple-Music-style but built on the app's
/// liquid-glass language with Material 3 Expressive motifs: a large
/// palette-tinted cover hero, an oversized karaoke lyric line, a two-tier
/// transport (big expressive play/pause disc + a glass strip of speed / voice /
/// settings pills), and an animated settings reveal.
///
/// Opened from the reader bottom nav's Listen button (see
/// [NowPlayingSheet.show]).
class NowPlayingSheet extends HookConsumerWidget {
  const NowPlayingSheet({
    super.key,
    this.chapterTitle,
    this.bookTitle,
    this.coverPath,
  });

  final String? chapterTitle;
  final String? bookTitle;
  final String? coverPath;

  static Future<void> show(
    BuildContext context, {
    String? chapterTitle,
    String? bookTitle,
    String? coverPath,
  }) {
    // No [title]: the stage itself owns the identity (overline + cover hero),
    // and a header bar would steal vertical space from the lyrics.
    return AppSheet.show(
      context: context,
      id: 'reader_now_playing',
      initialHeight: 0.9,
      snapPoints: const [0.55, 0.9],
      maxHeightFactor: 0.95,
      child: NowPlayingSheet(
        chapterTitle: chapterTitle,
        bookTitle: bookTitle,
        coverPath: coverPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSettings = useState(false);
    final colorScheme = Theme.of(context).colorScheme;
    final engine = ref.watch(speechEngineProvider);
    final session = engine.session;
    final queue = session?.queue;
    final hasSession = queue != null && queue.isNotEmpty;

    final status =
        ref.watch(narrationStatusProvider).valueOrNull ?? NarrationStatus.idle;
    final activeItem = ref.watch(activeSpeechItemProvider);
    final boundary = ref.watch(activeWordBoundaryProvider);

    final effectiveCoverPath = coverPath ?? session?.coverPath;
    final effectiveBookTitle = bookTitle ?? session?.bookTitle;
    final effectiveChapterTitle =
        chapterTitle ??
        (session != null && session.chapterId.startsWith('pdf_page_')
            ? 'Page ${session.chapterId.replaceFirst('pdf_page_', '')}'
            : null);

    final title = effectiveChapterTitle ?? effectiveBookTitle ?? 'Listen';
    // Subtitle carries the book title only when the headline doesn't already
    // show it (chapter headline + book subtitle), never a duplicate.
    final subtitle = effectiveBookTitle != null && effectiveBookTitle != title
        ? effectiveBookTitle
        : null;

    // Ambient tint from the cover art, shared with the mini player.
    final paletteAsync = ref.watch(coverPaletteProvider(effectiveCoverPath));
    final tint = effectiveCoverPath != null
        ? (paletteAsync.valueOrNull ?? CoverPalette.fallback).accent
        : colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // Size the cover so hero + lyrics + two transport tiers fit without
        // scrollbars while settings are collapsed.
        final availableForCover = maxHeight - 340.0;
        final coverCap = math.min(
          math.min(maxWidth * 0.42, 190.0),
          math.max(80.0, availableForCover / 1.4),
        );

        return SingleChildScrollView(
          physics: showSettings.value
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NOW PLAYING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: session != null
                    ? () {
                        Navigator.of(context).maybePop();
                        if (session.chapterId.startsWith('pdf_page_')) {
                          final page = session.chapterId.replaceFirst(
                            'pdf_page_',
                            '',
                          );
                          context.push('/reader/${session.bookId}?page=$page');
                        } else {
                          context.push(
                            '/reader/${session.bookId}?chapterId=${session.chapterId}',
                          );
                        }
                      }
                    : null,
                child: _CoverArt(
                  coverPath: effectiveCoverPath,
                  tint: tint,
                  maxSize: coverCap,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _Lyrics(
                item: activeItem,
                boundary: boundary,
                status: status,
                hasSession: hasSession,
              ),
              if (queue != null && queue.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _QueueProgress(
                  cursor: queue.cursor,
                  length: queue.length,
                  tint: tint,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _TransportControls(
                status: status,
                queue: queue,
                tint: tint,
                color: colorScheme.onSurface,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Glass strip: settings chip + speed dial + voice pill. A Wrap
              // (not a Row) so narrow phones fold to two centered lines
              // instead of shrinking every control.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _SettingsChip(
                    expanded: showSettings.value,
                    tint: tint,
                    color: colorScheme.onSurface,
                    onTap: () => showSettings.value = !showSettings.value,
                  ),
                  NarrationSpeedControl(
                    accent: tint,
                    color: colorScheme.onSurface,
                  ),
                  VoicePill(accent: tint, color: colorScheme.onSurface),
                ],
              ),
              // Expressive settings reveal: size-animated tonal capsule
              // instead of a hard Divider.
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: !showSettings.value
                    ? const SizedBox.shrink()
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: AppSpacing.md),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        child: const NarrationTab(),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

/// Large rounded cover art over an ambient tint glow derived from the cover
/// palette. Falls back to a stylized placeholder when the book has no cover.
class _CoverArt extends StatelessWidget {
  const _CoverArt({this.coverPath, required this.tint, required this.maxSize});

  final String? coverPath;
  final Color tint;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final size = maxSize.isFinite && maxSize > 0 ? maxSize : 160.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ambient glow tinted by the cover palette (expressive hero halo).
        Container(
          width: size * 0.9,
          height: size * 1.3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.30),
                blurRadius: 40,
                spreadRadius: 6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        // Primary cover card: big expressive radius, deep grounded shadow.
        Container(
          width: size,
          height: size * 1.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: coverPath != null
                ? Image.file(
                    File(coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _CoverPlaceholder(),
                  )
                : const _CoverPlaceholder(),
          ),
        ),
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 64,
          color: colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// The karaoke lyric line with ShaderMask top/bottom fade: the current sentence
/// with the currently-spoken word emphasized, exactly as Apple Music highlights.
/// Expressive typography: larger, heavier highlight.
class _Lyrics extends StatelessWidget {
  const _Lyrics({
    required this.item,
    required this.boundary,
    required this.status,
    required this.hasSession,
  });

  final SpeechItem? item;
  final WordBoundary? boundary;
  final NarrationStatus status;
  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!hasSession || status == NarrationStatus.idle) {
      return Text(
        item != null
            ? 'Tap play to continue narrating.'
            : 'Open Listen to narrate the chapter aloud.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      );
    }

    final sentence = item?.text.trim() ?? '';
    if (sentence.isEmpty) {
      return const SizedBox.shrink();
    }

    final dim = TextStyle(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface.withValues(alpha: 0.55),
    );
    final highlight = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: colorScheme.primary,
    );

    TextSpan lyricSpan;
    final s = boundary?.start ?? -1;
    final e = boundary?.end ?? -1;
    if (s >= 0 && e > s && e <= sentence.length) {
      lyricSpan = TextSpan(
        style: dim,
        children: [
          if (s > 0) TextSpan(text: sentence.substring(0, s)),
          TextSpan(text: sentence.substring(s, e), style: highlight),
          if (e < sentence.length) TextSpan(text: sentence.substring(e)),
        ],
      );
    } else {
      lyricSpan = TextSpan(text: sentence, style: dim);
    }

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.08, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text.rich(
          lyricSpan,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _QueueProgress extends StatelessWidget {
  const _QueueProgress({
    required this.cursor,
    required this.length,
    required this.tint,
    required this.color,
  });

  final int cursor;
  final int length;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = length > 1 ? cursor / (length - 1) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            color: tint,
            backgroundColor: tint.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sentence ${cursor + 1} of $length',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}

/// Main transport tier: paragraph restart / sentence skip flanking a big
/// expressive play-pause disc (a [GlassLens] droplet behind a 64dp target, so
/// the primary action reads at arm's length instead of competing with pills).
class _TransportControls extends ConsumerWidget {
  const _TransportControls({
    required this.status,
    required this.queue,
    required this.tint,
    required this.color,
  });

  final NarrationStatus status;
  final SpeechQueue? queue;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(speechEngineProvider);
    final q = queue;
    final atStart = q == null || q.cursor <= 0;
    final atEnd = q == null || q.cursor >= q.length - 1;
    final restartIndex = _paragraphStartIndex(q);
    final nextIndex = _nextParagraphIndex(q);
    final playing = status == NarrationStatus.playing;

    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TransportButton(
                icon: Icons.replay,
                size: 22,
                tooltip: 'Restart paragraph',
                color: color,
                enabled: restartIndex != null,
                onTap: () => unawaited(_restartParagraph(engine, restartIndex)),
              ),
              const SizedBox(width: AppSpacing.lg),
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                size: 28,
                tooltip: 'Previous sentence',
                color: color,
                enabled: !atStart,
                onTap: () => unawaited(engine.skipPrevious()),
              ),
              const SizedBox(width: AppSpacing.md),
              _PlayDisc(
                playing: playing,
                tint: tint,
                onTap: () => unawaited(_toggle(engine, status)),
              ),
              const SizedBox(width: AppSpacing.md),
              _TransportButton(
                icon: Icons.skip_next_rounded,
                size: 28,
                tooltip: 'Next sentence',
                color: color,
                enabled: !atEnd,
                onTap: () => unawaited(engine.skipNext()),
              ),
              const SizedBox(width: AppSpacing.lg),
              _TransportButton(
                icon: Icons.double_arrow,
                size: 22,
                tooltip: 'Next paragraph',
                color: color,
                enabled: nextIndex != null,
                onTap: () => unawaited(_skipToParagraph(engine, nextIndex)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(SpeechEngine engine, NarrationStatus status) async {
    switch (status) {
      case NarrationStatus.playing:
        return engine.pause();
      case NarrationStatus.paused:
        return engine.resume();
      case NarrationStatus.idle:
        return engine.start();
    }
  }

  /// First queue index belonging to the current item's paragraph, or null
  /// when there is no active item.
  int? _paragraphStartIndex(SpeechQueue? q) {
    final cur = q?.current;
    if (q == null || cur == null) return null;
    var start = q.cursor;
    while (start > 0) {
      final prev = q.itemAt(start - 1);
      if (prev != null && prev.paragraphIndex == cur.paragraphIndex) {
        start--;
      } else {
        break;
      }
    }
    return start;
  }

  /// Queue index of the first item in the paragraph after the current one,
  /// or null when there is no next paragraph.
  int? _nextParagraphIndex(SpeechQueue? q) {
    final cur = q?.current;
    if (q == null || cur == null) return null;
    for (int i = q.cursor + 1; i < q.length; i++) {
      final item = q.itemAt(i);
      if (item != null && item.paragraphIndex != cur.paragraphIndex) return i;
    }
    return null;
  }

  Future<void> _restartParagraph(SpeechEngine engine, int? start) async {
    final q = engine.session?.queue;
    if (q == null || start == null) return;
    q.seekTo(start);
    await engine.stop();
    await engine.start();
  }

  Future<void> _skipToParagraph(SpeechEngine engine, int? index) async {
    final q = engine.session?.queue;
    if (q == null || index == null) return;
    q.seekTo(index);
    await engine.stop();
    await engine.start();
  }
}

/// The expressive play/pause disc: a [GlassLens] droplet backing a 64dp
/// hit target, with a springy scale-in on the icon swap (Material 3
/// Expressive motion; the spring curve keeps the morph lively without a
/// controller). Honors [MediaQuery.disableAnimationsOf].
class _PlayDisc extends StatelessWidget {
  const _PlayDisc({
    required this.playing,
    required this.tint,
    required this.onTap,
  });

  final bool playing;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onDisc = Theme.of(context).colorScheme.onSurface;
    final motionOff = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('play_disc'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: GlassLens(accent: tint, isDark: isDark, radius: 32),
                ),
              ),
              AnimatedSwitcher(
                duration: motionOff
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  key: ValueKey(playing),
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  color: onDisc,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small glass chip that reveals the narration settings panel. Matches the
/// speed / voice pills it sits beside in the glass strip.
class _SettingsChip extends StatelessWidget {
  const _SettingsChip({
    required this.expanded,
    required this.tint,
    required this.color,
    required this.onTap,
  });

  final bool expanded;
  final Color tint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? 'Hide narration settings' : 'Narration settings',
      child: GlassCapsule(
        pill: true,
        blur: 18,
        strong: false,
        skipDropShadow: true,
        child: InkWell(
          key: const ValueKey('settings_chip'),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            height: 30,
            width: 36,
            child: Icon(
              Icons.tune,
              size: 16,
              color: expanded ? tint : color.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 28,
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: enabled ? onTap : null,
      iconSize: size,
      color: enabled ? color : color.withValues(alpha: 0.3),
      icon: Icon(icon),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
    final label = tooltip;
    if (label == null) return button;
    return Tooltip(message: label, child: button);
  }
}
