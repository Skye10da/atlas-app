import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/cover_palette_service.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// Persistent mini player shown at the bottom of the reader whenever
/// narration is active (playing or paused). Unlike the chrome bars it is not
/// tied to [chromeVisible], so it stays on screen while the user scrolls and
/// only disappears once narration is stopped. Tapping the cover navigates directly
/// to the reader at the current narration location; tapping the body reopens the
/// full Now Playing sheet.
class NarrationMiniPlayer extends ConsumerWidget {
  const NarrationMiniPlayer({
    super.key,
    this.bookTitle,
    this.coverPath,
    this.chapterTitle,
    this.accent,
    this.onExpand,
  });

  final String? bookTitle;
  final String? coverPath;
  final String? chapterTitle;
  final Color? accent;

  /// Overrides the tap-to-expand action (e.g. desktop side-panel mode
  /// reopens the narration panel instead of the bottom sheet). Falls back
  /// to [NowPlayingSheet.show].
  final VoidCallback? onExpand;

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

    final effectiveCoverPath = coverPath ?? session.coverPath;
    final effectiveBookTitle = bookTitle ?? session.bookTitle;
    final effectiveChapterTitle = chapterTitle ??
        (session.chapterId.startsWith('pdf_page_')
            ? 'Page ${session.chapterId.replaceFirst('pdf_page_', '')}'
            : null);

    final colorScheme = Theme.of(context).colorScheme;
    final paletteAsync = ref.watch(coverPaletteProvider(effectiveCoverPath));
    final palette = paletteAsync.valueOrNull ?? CoverPalette.fallback;
    final tint = accent ??
        (effectiveCoverPath != null ? palette.accent : colorScheme.primary);
    final queue = session.queue;
    final activeItem = ref.watch(activeSpeechItemProvider);
    final boundary = ref.watch(activeWordBoundaryProvider);

    final sentenceProgress = queue.length > 1
        ? queue.cursor / (queue.length - 1)
        : 0.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            color: colorScheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                final expand = onExpand;
                if (expand != null) {
                  expand();
                  return;
                }
                NowPlayingSheet.show(
                  context,
                  chapterTitle: effectiveChapterTitle,
                  bookTitle: effectiveBookTitle,
                  coverPath: effectiveCoverPath,
                );
              },
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
                    height: 52,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, right: 4),
                          child: Tooltip(
                            message: 'Go to ${effectiveBookTitle ?? 'reader'}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _navigateToReader(context, session),
                                child: Container(
                                  width: 32,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: BookCover(
                                    coverPath: effectiveCoverPath,
                                    width: 32,
                                    height: 38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => unawaited(_toggle(engine, status)),
                          icon: Icon(
                            switch (status) {
                              NarrationStatus.playing =>
                                Icons.pause_circle_filled,
                              NarrationStatus.paused =>
                                Icons.play_circle_filled,
                              NarrationStatus.idle => Icons.play_circle_filled,
                            },
                            size: 28,
                            color: tint,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _MiniLyric(
                            item: activeItem,
                            boundary: boundary,
                            playing: status == NarrationStatus.playing,
                            fallback: effectiveChapterTitle ??
                                effectiveBookTitle ??
                                'Narrating',
                            dimColor: colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                            accent: tint,
                          ),
                        ),
                        const SizedBox(width: 4),
                        NarrationSpeedControl(
                          accent: tint,
                          color: colorScheme.onSurface,
                        ),
                        IconButton(
                          onPressed: () => unawaited(engine.skipNext()),
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 22,
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        IconButton(
                          onPressed: () => unawaited(engine.stop()),
                          icon: const Icon(Icons.close),
                          iconSize: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
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
      ),
    );
  }

  void _navigateToReader(BuildContext context, SpeechSession session) {
    if (session.chapterId.startsWith('pdf_page_')) {
      final page = session.chapterId.replaceFirst('pdf_page_', '');
      context.push('/reader/${session.bookId}?page=$page');
    } else {
      context.push('/reader/${session.bookId}?chapterId=${session.chapterId}');
    }
  }

  Future<void> _toggle(SpeechEngine engine, NarrationStatus status) async {
    switch (status) {
      case NarrationStatus.playing:
        await engine.pause();
      case NarrationStatus.paused:
      case NarrationStatus.idle:
        await engine.resume();
    }
  }
}

/// Single-line rolling karaoke lyric. The active sentence lays out as one line
/// and scrolls so the currently spoken word stays anchored near the left edge:
/// as a new word becomes active, the preceding text flows out to the left and
/// the following text enters from the right. The slide duration is sized from
/// the word's length so the motion stays roughly in sync with how long the word
class _MiniLyric extends HookWidget {
  const _MiniLyric({
    required this.item,
    required this.boundary,
    required this.playing,
    required this.fallback,
    required this.dimColor,
    required this.accent,
  });

  final SpeechItem? item;
  final WordBoundary? boundary;
  final bool playing;
  final String fallback;
  final Color dimColor;
  final Color accent;

  static const double _leftInset = 6;
  static const int _msBase = 160;
  static const int _msPerChar = 64;
  static const int _minMs = 180;
  static const int _maxMs = 900;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  static bool get _useWordBoundaries => !_isDesktop;

  static List<_WordRange> _tokenize(String text) {
    return RegExp(r'\S+')
        .allMatches(text)
        .map((m) => _WordRange(start: m.start, end: m.end, word: m[0]!))
        .toList();
  }

  static bool _sameWord(String a, String b) {
    String normalize(String s) => s.toLowerCase().replaceAll(
      RegExp(r"[^\p{L}\p{N}'’\u2019-]", unicode: true),
      '',
    );
    final na = normalize(a);
    return na.isNotEmpty && na == normalize(b);
  }

  static int _estimateMs(int charCount) =>
      (_msBase + charCount * _msPerChar).clamp(_minMs, _maxMs);

  static double _wordStartX(TextPainter painter, int wordStart) {
    if (wordStart <= 0) return 0;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: wordStart),
    );
    if (boxes.isEmpty) return 0;
    return boxes.last.right;
  }

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 220),
    );

    final lineText = item?.text.trim() ?? '';
    final sentence = lineText.isEmpty ? fallback : lineText;
    final words = useMemoized(() => _tokenize(sentence), [sentence]);

    final activeWord = useState(words.isEmpty ? -1 : 0);
    final startX = useState(0.0);
    final endX = useState(0.0);
    final renderedX = useRef(0.0);
    final boundariesStalled = useState(false);

    final fallbackTimer = useRef<Timer?>(null);
    final stallTimer = useRef<Timer?>(null);

    void stopFallback() {
      fallbackTimer.value?.cancel();
      fallbackTimer.value = null;
      stallTimer.value?.cancel();
      stallTimer.value = null;
    }

    TextStyle getBaseStyle() => TextStyle(
      fontSize: 13,
      fontWeight: sentence == fallback ? FontWeight.w600 : FontWeight.w500,
      color: dimColor,
    );

    TextSpan buildSpan() {
      final accentStyle = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: accent,
      );
      final s = (activeWord.value >= 0 && activeWord.value < words.length)
          ? words[activeWord.value].start
          : null;
      final e = (activeWord.value >= 0 && activeWord.value < words.length)
          ? words[activeWord.value].end
          : null;
      if (s != null && e != null && e > s && e <= sentence.length) {
        return TextSpan(
          style: getBaseStyle(),
          children: [
            if (s > 0) TextSpan(text: sentence.substring(0, s)),
            TextSpan(text: sentence.substring(s, e), style: accentStyle),
            if (e < sentence.length) TextSpan(text: sentence.substring(e)),
          ],
        );
      }
      return TextSpan(text: sentence, style: getBaseStyle());
    }

    void animateTo(int wi) {
      if (wi < 0 || wi >= words.length || wi == activeWord.value) return;
      activeWord.value = wi;
      final span = buildSpan();
      final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      final r = words[wi];
      final wordPos = _wordStartX(painter, r.start);
      painter.dispose();

      startX.value = renderedX.value;
      endX.value = _leftInset - wordPos;
      controller.duration = Duration(milliseconds: _estimateMs(r.word.length));
      controller.forward(from: 0);
    }

    void scheduleNext(int wi) {
      stopFallback();

      if (!playing) return;
      if (wi < 0 || wi >= words.length) return;

      if (boundariesStalled.value || !_useWordBoundaries) {
        fallbackTimer.value = Timer(
          Duration(milliseconds: _estimateMs(words[wi].word.length)),
          () {
            if (wi + 1 < words.length) {
              animateTo(wi + 1);
              scheduleNext(wi + 1);
            }
          },
        );
        return;
      }

      stallTimer.value = Timer(
        Duration(milliseconds: _estimateMs(words[wi].word.length) * 2),
        () {
          boundariesStalled.value = true;
          scheduleNext(wi);
        },
      );
    }

    useEffect(() {
      activeWord.value = words.isEmpty ? -1 : 0;
      startX.value = 0;
      endX.value = 0;
      renderedX.value = 0;
      controller.stop();
      controller.value = 0;
      stopFallback();
      boundariesStalled.value = false;

      if (activeWord.value >= 0 && words.isNotEmpty && words.first.start > 0) {
        animateTo(activeWord.value);
      }
      if (playing) scheduleNext(activeWord.value);
      return stopFallback;
    }, [sentence, playing]);

    useEffect(() {
      if (!_useWordBoundaries) return null;
      final w = boundary?.word.trim();
      if (w == null || w.isEmpty || words.isEmpty) return null;
      for (var i = 0; i < words.length; i++) {
        if (_sameWord(words[i].word, w)) {
          stallTimer.value?.cancel();
          stallTimer.value = null;
          animateTo(i);
          scheduleNext(i);
          return null;
        }
      }
      return null;
    }, [boundary]);

    final text = Text.rich(buildSpan(), maxLines: 1, overflow: TextOverflow.clip);

    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        child: text,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(controller.value);
          final x = startX.value + (endX.value - startX.value) * t;
          renderedX.value = x;
          return Transform.translate(offset: Offset(x, 0), child: child);
        },
      ),
    );
  }
}

class _WordRange {
  const _WordRange({
    required this.start,
    required this.end,
    required this.word,
  });

  final int start;
  final int end;
  final String word;
}
