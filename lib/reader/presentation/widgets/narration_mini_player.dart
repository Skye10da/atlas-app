import 'dart:async';

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Persistent mini player shown at the bottom of the reader whenever
/// narration is active (playing or paused). Unlike the chrome bars it is not
/// tied to [chromeVisible], so it stays on screen while the user scrolls and
/// only disappears once narration is stopped. Tapping the body reopens the
/// full Now Playing sheet.
class NarrationMiniPlayer extends ConsumerWidget {
  const NarrationMiniPlayer({
    super.key,
    this.bookTitle,
    this.coverPath,
    this.chapterTitle,
    this.accent,
  });

  final String? bookTitle;
  final String? coverPath;
  final String? chapterTitle;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(speechEngineProvider);
    final session = engine.session;
    if (session == null || session.queue.isEmpty) return const SizedBox.shrink();

    final status =
        ref.watch(narrationStatusProvider).valueOrNull ??
        NarrationStatus.idle;
    if (status == NarrationStatus.idle) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final tint = accent ?? colorScheme.primary;
    final queue = session.queue;
    final activeItem = ref.watch(activeSpeechItemProvider);
    final boundary = ref.watch(activeWordBoundaryProvider);

    final sentenceProgress = queue.length > 1
        ? queue.cursor / (queue.length - 1)
        : 0.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          6,
        ),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          color: colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => NowPlayingSheet.show(
              context,
              chapterTitle: chapterTitle,
              bookTitle: bookTitle,
              coverPath: coverPath,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  minHeight: 2,
                  value: sentenceProgress,
                  color: tint,
                  backgroundColor: tint.withValues(alpha: 0.15),
                ),
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () =>
                            unawaited(_toggle(engine, status)),
                        icon: Icon(
                          switch (status) {
                            NarrationStatus.playing => Icons.pause_circle_filled,
                            NarrationStatus.paused => Icons.play_circle_filled,
                            NarrationStatus.idle => Icons.play_circle_filled,
                          },
                          size: 30,
                          color: tint,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MiniLyric(
                          item: activeItem,
                          boundary: boundary,
                          fallback: chapterTitle ?? bookTitle ?? 'Narrating',
                          dimColor: colorScheme.onSurface.withValues(alpha: 0.65),
                          accent: tint,
                        ),
                      ),
                      const SizedBox(width: 4),
                      NarrationSpeedControl(accent: tint, color: colorScheme.onSurface),
                      const SizedBox(width: 2),
                      IconButton(
                        onPressed: () => unawaited(engine.skipNext()),
                        icon: const Icon(Icons.skip_next_rounded),
                        iconSize: 22,
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      IconButton(
                        onPressed: () => unawaited(engine.stop()),
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
}

/// Single-line lyric: the current sentence with the currently spoken word
/// highlighted. Falls back to [fallback] when no sentence is active yet.
class _MiniLyric extends StatelessWidget {
  const _MiniLyric({
    required this.item,
    required this.boundary,
    required this.fallback,
    required this.dimColor,
    required this.accent,
  });

  final SpeechItem? item;
  final WordBoundary? boundary;
  final String fallback;
  final Color dimColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sentence = item?.text.trim() ?? '';
    if (sentence.isEmpty) {
      return Text(
        fallback,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dimColor),
      );
    }

    final base = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: dimColor,
    );
    final highlight = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: accent,
    );

    final s = boundary?.start ?? -1;
    final e = boundary?.end ?? -1;
    final TextSpan span;
    if (s >= 0 && e > s && e <= sentence.length) {
      span = TextSpan(
        style: base,
        children: [
          if (s > 0) TextSpan(text: sentence.substring(0, s)),
          TextSpan(text: sentence.substring(s, e), style: highlight),
          if (e < sentence.length) TextSpan(text: sentence.substring(e)),
        ],
      );
    } else {
      span = TextSpan(text: sentence, style: base);
    }

    return Text.rich(
      span,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
