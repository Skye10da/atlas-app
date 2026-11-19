import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/organisms/atlas_glass_nav_bar.dart'
    show AtlasNavItem;
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
    this.docked = false,
    this.navDestinations = const <AtlasNavItem>[],
    this.currentNavIndex,
    this.onNavSelect,
  });

  final String? bookTitle;
  final String? coverPath;
  final String? chapterTitle;
  final Color? accent;

  /// Overrides the tap-to-expand action (e.g. desktop side-panel mode
  /// reopens the narration panel instead of the bottom sheet). Falls back
  /// to [NowPlayingSheet.show].
  final VoidCallback? onExpand;

  /// Docked mode: the player has slid down into the nav pill's resting spot
  /// (the pill auto-hid because narration is active), so it grows a compact
  /// icon strip of the shell's nav destinations along its bottom edge —
  /// navigation stays reachable without the hidden bar.
  final bool docked;

  /// Destinations for the docked nav strip ([AtlasNavItem]s shared with the
  /// shell's pill). Rendered only when [docked] is true.
  final List<AtlasNavItem> navDestinations;

  /// Currently selected branch index, for the strip's active highlight.
  final int? currentNavIndex;

  /// Called with the tapped destination index.
  final ValueChanged<int>? onNavSelect;

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
    final effectiveChapterTitle =
        chapterTitle ??
        (session.chapterId.startsWith('pdf_page_')
            ? 'Page ${session.chapterId.replaceFirst('pdf_page_', '')}'
            : null);

    final colorScheme = Theme.of(context).colorScheme;
    final paletteAsync = ref.watch(coverPaletteProvider(effectiveCoverPath));
    final palette = paletteAsync.valueOrNull ?? CoverPalette.fallback;
    final tint =
        accent ??
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
        child: GlassCapsule(
          borderRadius: 24,
          // Pills/strips over live reader text stay at blur 16-20 (skill
          // convention); this is a full card, so 18 keeps it legible cheaply.
          blur: 18,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      value: sentenceProgress,
                      color: tint,
                      backgroundColor: tint.withValues(alpha: 0.15),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    // Phone-width hosts can't fit the six-chip rate dial
                    // (~210px) alongside cover + transport + lyric — switch
                    // to the compact chip that opens the preset menu.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compactSpeed = constraints.maxWidth < 380;
                        return Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 4),
                              child: Tooltip(
                                message:
                                    'Go to ${effectiveBookTitle ?? 'reader'}',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () =>
                                        _navigateToReader(context, session),
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
                              onPressed: () =>
                                  unawaited(_toggle(engine, status)),
                              icon: Icon(
                                switch (status) {
                                  NarrationStatus.playing =>
                                    Icons.pause_circle_filled,
                                  NarrationStatus.paused =>
                                    Icons.play_circle_filled,
                                  NarrationStatus.idle =>
                                    Icons.play_circle_filled,
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
                                fallback:
                                    effectiveChapterTitle ??
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
                              compact: compactSpeed,
                            ),
                            IconButton(
                              onPressed: () => unawaited(engine.skipNext()),
                              icon: const Icon(Icons.skip_next_rounded),
                              iconSize: 22,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        );
                      },
                    ),
                  ),
                  if (docked &&
                      navDestinations.isNotEmpty &&
                      onNavSelect != null) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 12,
                      endIndent: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            for (var i = 0; i < navDestinations.length; i++)
                              Expanded(
                                child: _MiniNavButton(
                                  item: navDestinations[i],
                                  selected: i == currentNavIndex,
                                  tint: tint,
                                  dim: colorScheme.onSurfaceVariant,
                                  onTap: () => onNavSelect!(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
        break;
      case NarrationStatus.paused:
        await engine.resume();
        break;
      case NarrationStatus.idle:
        await engine.start();
        break;
    }
  }
}

/// One icon+label destination in the docked mini player's nav strip. Icon
/// only would be ambiguous at this size, so a 9px label rides under it.
class _MiniNavButton extends StatelessWidget {
  const _MiniNavButton({
    required this.item,
    required this.selected,
    required this.tint,
    required this.dim,
    required this.onTap,
  });

  final AtlasNavItem item;
  final bool selected;
  final Color tint;
  final Color dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 20,
                color: selected ? tint : dim,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? tint : dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    final text = Text.rich(
      buildSpan(),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

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
