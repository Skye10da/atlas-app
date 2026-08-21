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
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 6),
        child: Material(
          elevation: 6,
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
                chapterTitle: chapterTitle,
                bookTitle: bookTitle,
                coverPath: coverPath,
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
                  height: 50,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => unawaited(_toggle(engine, status)),
                        icon: Icon(
                          switch (status) {
                            NarrationStatus.playing =>
                              Icons.pause_circle_filled,
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
                          playing: status == NarrationStatus.playing,
                          fallback: chapterTitle ?? bookTitle ?? 'Narrating',
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

/// Single-line rolling karaoke lyric. The active sentence lays out as one line
/// and scrolls so the currently spoken word stays anchored near the left edge:
/// as a new word becomes active, the preceding text flows out to the left and
/// the following text enters from the right. The slide duration is sized from
/// the word's length so the motion stays roughly in sync with how long the word
/// takes to speak. Falls back to [fallback] when no sentence is active yet.
class _MiniLyric extends StatefulWidget {
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

  @override
  State<_MiniLyric> createState() => _MiniLyricState();
}

class _MiniLyricState extends State<_MiniLyric>
    with SingleTickerProviderStateMixin {
  // Where the spoken word rests after each slide.
  static const double _leftInset = 6;
  // Per-word slide duration: base + characters * perChar, clamped.
  static const int _msBase = 160;
  static const int _msPerChar = 64;
  static const int _minMs = 180;
  static const int _maxMs = 900;

  late final AnimationController _controller;
  late String _sentence;
  TextPainter? _painter;
  final List<_WordRange> _words = [];
  double _startX = 0;
  double _endX = 0;
  double _renderedX = 0;
  int _activeWord = -1;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _sentence = _lineOf(widget.item);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _resetLine();
  }

  @override
  void didUpdateWidget(covariant _MiniLyric oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _lineOf(widget.item);
    if (next != _sentence) {
      _resetLine();
      return;
    }
    // Re-anchor to the real spoken word when a boundary event arrives (present
    // on most platforms). This keeps the fallback timer in line with actual
    // speech when those events are live.
    _syncFromProvider();
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _scheduleNext(_activeWord);
      } else {
        _stopFallback();
      }
    }
  }

  /// Parses [widget.item] into word ranges and (re)starts the lyric at word 0.
  void _resetLine() {
    _sentence = _lineOf(widget.item);
    _words
      ..clear()
      ..addAll(_tokenize(_sentence));
    _activeWord = _words.isEmpty ? -1 : 0;
    _startX = 0;
    _endX = 0;
    _renderedX = 0;
    _controller.stop();
    _controller.value = 0;
    _stopFallback();
    _rebuildPainter();
    // Slide to word 0's resting position (near the left inset).
    if (_activeWord >= 0 && _words.first.start > 0) {
      _animateTo(_activeWord);
    }
    if (widget.playing) _scheduleNext(_activeWord);
  }

  /// Stable identity of a line: the trimmed sentence, or [widget.fallback] when
  /// the sentence is empty.
  String _lineOf(SpeechItem? item) {
    final text = item?.text.trim() ?? '';
    return text.isEmpty ? widget.fallback : text;
  }

  /// Words of [_sentence] as character ranges.
  static List<_WordRange> _tokenize(String text) {
    return RegExp(r'\S+')
        .allMatches(text)
        .map((m) => _WordRange(start: m.start, end: m.end, word: m[0]!))
        .toList();
  }

  /// Advances to the word, sliding so its left edge lands at the inset, then
  /// schedules the next word after the current word's estimated duration.
  void _animateTo(int wi) {
    if (wi < 0 || wi >= _words.length || wi == _activeWord) return;
    _activeWord = wi;
    _rebuildPainter();
    final painter = _painter;
    if (painter == null) return;
    final r = _words[wi];
    final wordStartX = _wordStartX(painter, r.start);
    _startX = _renderedX;
    _endX = _leftInset - wordStartX;
    _controller.duration = Duration(milliseconds: _estimateMs(r.word.length));
    _controller.forward(from: 0);
    _scheduleNext(wi);
  }

  void _syncFromProvider() {
    final w = widget.boundary?.word.trim();
    if (w == null || w.isEmpty || _words.isEmpty) return;
    for (var i = 0; i < _words.length; i++) {
      if (_sameWord(_words[i].word, w)) {
        _animateTo(i);
        return;
      }
    }
  }

  static bool _sameWord(String a, String b) {
    String normalize(String s) => s.toLowerCase().replaceAll(
      RegExp(r"[^\p{L}\p{N}'’\u2019-]", unicode: true),
      '',
    );
    final na = normalize(a);
    return na.isNotEmpty && na == normalize(b);
  }

  void _scheduleNext(int wi) {
    _stopFallback();
    if (!widget.playing) return;
    if (wi < 0) return;
    final next = wi + 1;
    if (next >= _words.length) return;
    _fallbackTimer = Timer(
      Duration(milliseconds: _estimateMs(_words[wi].word.length)),
      () {
        if (!mounted) return;
        _animateTo(next);
      },
    );
  }

  void _stopFallback() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  int _estimateMs(int charCount) =>
      (_msBase + charCount * _msPerChar).clamp(_minMs, _maxMs);

  TextStyle get _baseStyle => TextStyle(
    fontSize: 13,
    fontWeight: _sentence == widget.fallback
        ? FontWeight.w600
        : FontWeight.w500,
    color: widget.dimColor,
  );

  /// Rebuilds the measuring painter from the exact span build() renders so the
  /// measured word extents match the on-screen glyphs (a bolder highlighted
  /// word would otherwise be measured too narrow and clipped).
  void _rebuildPainter() {
    _painter?.dispose();
    final span = _span();
    _painter = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
  }

  TextSpan _span() {
    final accent = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: widget.accent,
    );
    final s = _startBounds;
    final e = _endBounds;
    if (s != null && e != null && e > s && e <= _sentence.length) {
      return TextSpan(
        style: _baseStyle,
        children: [
          if (s > 0) TextSpan(text: _sentence.substring(0, s)),
          TextSpan(text: _sentence.substring(s, e), style: accent),
          if (e < _sentence.length) TextSpan(text: _sentence.substring(e)),
        ],
      );
    }
    return TextSpan(text: _sentence, style: _baseStyle);
  }

  int? get _startBounds => (_activeWord >= 0 && _activeWord < _words.length)
      ? _words[_activeWord].start
      : null;

  int? get _endBounds => (_activeWord >= 0 && _activeWord < _words.length)
      ? _words[_activeWord].end
      : null;

  /// Horizontal position of the word starting at [wordStart] within the laid
  /// out line, in logical pixels.
  static double _wordStartX(TextPainter painter, int wordStart) {
    if (wordStart <= 0) return 0;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: wordStart),
    );
    if (boxes.isEmpty) return 0;
    return boxes.last.right;
  }

  @override
  void dispose() {
    _stopFallback();
    _painter?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(_span(), maxLines: 1, overflow: TextOverflow.clip);

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        child: text,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final x = _startX + (_endX - _startX) * t;
          _renderedX = x;
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
