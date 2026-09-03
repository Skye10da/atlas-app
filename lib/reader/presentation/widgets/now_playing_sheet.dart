import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/narration_tab.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';

/// Apple-Music-style "Now Playing" narration card. Shows the book cover with
/// the current sentence rendered as a karaoke lyric line beneath it — the
/// word currently being spoken is highlighted — plus the transport controls.
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
    return AppSheet.show(
      context: context,
      id: 'reader_now_playing',
      title: 'Now Playing',
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
    final effectiveChapterTitle = chapterTitle ??
        (session != null && session.chapterId.startsWith('pdf_page_')
            ? 'Page ${session.chapterId.replaceFirst('pdf_page_', '')}'
            : null);

    final title = effectiveChapterTitle ?? effectiveBookTitle ?? 'Listen';
    final subtitle =
        effectiveBookTitle != null && effectiveBookTitle != effectiveChapterTitle
            ? effectiveBookTitle
            : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // Size the cover efficiently so all elements (cover, title, lyrics,
        // progress, controls) fit without forcing scrollbars when settings are collapsed.
        final availableForCover = maxHeight - 280.0;
        final coverCap = math.min(
          math.min(maxWidth * 0.42, 180.0),
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
              GestureDetector(
                onTap: session != null
                    ? () {
                        Navigator.of(context).maybePop();
                        if (session.chapterId.startsWith('pdf_page_')) {
                          final page =
                              session.chapterId.replaceFirst('pdf_page_', '');
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
                  maxSize: coverCap,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
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
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _TransportControls(
                status: status,
                queue: queue,
                accent: colorScheme.primary,
                color: colorScheme.onSurface,
                settingsExpanded: showSettings.value,
                onToggleSettings: () =>
                    showSettings.value = !showSettings.value,
              ),
              if (showSettings.value) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colorScheme.onSurface.withValues(alpha: 0.12)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      'Narration',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.tune,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const NarrationTab(),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

/// Large rounded cover art with a soft Apple-style shadow. Falls back to a
/// stylized placeholder when the book has no cover.
class _CoverArt extends StatelessWidget {
  const _CoverArt({this.coverPath, required this.maxSize});

  final String? coverPath;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final size = maxSize.isFinite && maxSize > 0 ? maxSize : 160.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ambient soft blur glow behind cover
        Container(
          width: size * 0.9,
          height: size * 1.3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        // Primary Cover Image Card
        Container(
          width: size,
          height: size * 1.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
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
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface.withValues(alpha: 0.55),
    );
    final highlight = TextStyle(
      fontSize: 15,
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
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
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
    required this.color,
  });

  final int cursor;
  final int length;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = length > 1 ? cursor / (length - 1) : 0.0;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            color: color,
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sentence ${cursor + 1} of $length',
          style: TextStyle(fontSize: 14, color: color),
        ),
      ],
    );
  }
}

/// Transport controls for the narration session: restart/skip paragraph,
/// sentence skip, play/pause, plus a speed selector pinned to the right edge
/// and a toggle that reveals the narration settings panel.
class _TransportControls extends ConsumerWidget {
  const _TransportControls({
    required this.status,
    required this.queue,
    required this.accent,
    required this.color,
    required this.settingsExpanded,
    required this.onToggleSettings,
  });

  final NarrationStatus status;
  final SpeechQueue? queue;
  final Color accent;
  final Color color;
  final bool settingsExpanded;
  final VoidCallback onToggleSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(speechEngineProvider);
    final q = queue;
    final atStart = q == null || q.cursor <= 0;
    final atEnd = q == null || q.cursor >= q.length - 1;
    final restartIndex = _paragraphStartIndex(q);
    final nextIndex = _nextParagraphIndex(q);

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsToggleButton(
                expanded: settingsExpanded,
                accent: accent,
                color: color,
                onTap: onToggleSettings,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TransportButton(
                    icon: Icons.replay,
                    size: 22,
                    tooltip: 'Restart paragraph',
                    color: color,
                    enabled: restartIndex != null,
                    onTap: () =>
                        unawaited(_restartParagraph(engine, restartIndex)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TransportButton(
                    icon: Icons.skip_previous_rounded,
                    size: 26,
                    tooltip: 'Previous sentence',
                    color: color,
                    enabled: !atStart,
                    onTap: () => unawaited(engine.skipPrevious()),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: _TransportButton(
                      key: ValueKey(status == NarrationStatus.playing),
                      icon: status == NarrationStatus.playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 58,
                      iconColor: accent,
                      tooltip: status == NarrationStatus.playing ? 'Pause' : 'Play',
                      color: color,
                      onTap: () => unawaited(_toggle(engine, status)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _TransportButton(
                    icon: Icons.skip_next_rounded,
                    size: 26,
                    tooltip: 'Next sentence',
                    color: color,
                    enabled: !atEnd,
                    onTap: () => unawaited(engine.skipNext()),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: AppSpacing.xs),
              NarrationSpeedControl(accent: accent, color: color),
            ],
          ),
        ],
      ),
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

class _SettingsToggleButton extends StatelessWidget {
  const _SettingsToggleButton({
    required this.expanded,
    required this.accent,
    required this.color,
    required this.onTap,
  });

  final bool expanded;
  final Color accent;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? 'Hide narration settings' : 'Narration settings',
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.tune),
        iconSize: 20,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        color: expanded ? accent : color.withValues(alpha: 0.75),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconColor,
    this.size = 28,
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final Color? iconColor;
  final VoidCallback onTap;
  final double size;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: enabled ? onTap : null,
      iconSize: size,
      color: enabled ? (iconColor ?? color) : color.withValues(alpha: 0.3),
      icon: Icon(icon),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
    final label = tooltip;
    if (label == null) return button;
    return Tooltip(message: label, child: button);
  }
}
