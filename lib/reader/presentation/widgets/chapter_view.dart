import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, RenderBox, RenderEditable;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/speech/parser/sentence_splitter.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

enum ReadingViewTheme {
  light,
  dark,
  sepia,
  forest,
  ocean,
  dracula,
  amoled,
  cream,
  gray,
}

extension ReadingViewThemeX on ReadingViewTheme {
  Color get background => switch (this) {
    ReadingViewTheme.light => const Color(0xFFFFFBFE),
    ReadingViewTheme.dark => const Color(0xFF1A1A1A),
    ReadingViewTheme.sepia => const Color(0xFFF5F0E8),
    ReadingViewTheme.forest => const Color(0xFFE8F0E8),
    ReadingViewTheme.ocean => const Color(0xFFE8F0F5),
    ReadingViewTheme.dracula => const Color(0xFF282A36),
    ReadingViewTheme.amoled => const Color(0xFF000000),
    ReadingViewTheme.cream => const Color(0xFFFFF9E3),
    ReadingViewTheme.gray => const Color(0xFF2C2C2C),
  };

  Color get text => switch (this) {
    ReadingViewTheme.light => const Color(0xFF1C1B1F),
    ReadingViewTheme.dark => const Color(0xFFE3E3E3),
    ReadingViewTheme.sepia => const Color(0xFF3B2F2F),
    ReadingViewTheme.forest => const Color(0xFF2D3D2D),
    ReadingViewTheme.ocean => const Color(0xFF1C3D5E),
    ReadingViewTheme.dracula => const Color(0xFFF8F8F2),
    ReadingViewTheme.amoled => const Color(0xFFFFFFFF),
    ReadingViewTheme.cream => const Color(0xFF3E2723),
    ReadingViewTheme.gray => const Color(0xFFBDBDBD),
  };

  Color get surface => switch (this) {
    ReadingViewTheme.light => const Color(0xFFF0F0F0),
    ReadingViewTheme.dark => const Color(0xFF2A2A2A),
    ReadingViewTheme.sepia => const Color(0xFFE8E0D0),
    ReadingViewTheme.forest => const Color(0xFFD8E8D8),
    ReadingViewTheme.ocean => const Color(0xFFD0E0F0),
    ReadingViewTheme.dracula => const Color(0xFF44475A),
    ReadingViewTheme.amoled => const Color(0xFF1A1A1A),
    ReadingViewTheme.cream => const Color(0xFFF5EDD0),
    ReadingViewTheme.gray => const Color(0xFF3A3A3A),
  };

  Color get accent => switch (this) {
    ReadingViewTheme.light => const Color(0xFF1A73E8),
    ReadingViewTheme.dark => const Color(0xFF8AB4F8),
    ReadingViewTheme.sepia => const Color(0xFF8B6B4A),
    ReadingViewTheme.forest => const Color(0xFF4A7C4A),
    ReadingViewTheme.ocean => const Color(0xFF2D7DBF),
    ReadingViewTheme.dracula => const Color(0xFFBD93F9),
    ReadingViewTheme.amoled => const Color(0xFFBB86FC),
    ReadingViewTheme.cream => const Color(0xFF795548),
    ReadingViewTheme.gray => const Color(0xFF90A4AE),
  };

  String get label => switch (this) {
    ReadingViewTheme.light => 'Light',
    ReadingViewTheme.dark => 'Dark',
    ReadingViewTheme.sepia => 'Sepia',
    ReadingViewTheme.forest => 'Forest',
    ReadingViewTheme.ocean => 'Ocean',
    ReadingViewTheme.dracula => 'Dracula',
    ReadingViewTheme.amoled => 'AMOLED',
    ReadingViewTheme.cream => 'Cream',
    ReadingViewTheme.gray => 'Gray',
  };

  bool get isDark =>
      this == ReadingViewTheme.dark || this == ReadingViewTheme.dracula || this == ReadingViewTheme.amoled || this == ReadingViewTheme.gray;

  IconData get icon => switch (this) {
    ReadingViewTheme.light => Icons.light_mode,
    ReadingViewTheme.dark => Icons.dark_mode,
    ReadingViewTheme.sepia => Icons.wb_sunny,
    ReadingViewTheme.forest => Icons.nature,
    ReadingViewTheme.ocean => Icons.water_drop,
    ReadingViewTheme.dracula => Icons.nightlight_round,
    ReadingViewTheme.amoled => Icons.nightlight_round,
    ReadingViewTheme.cream => Icons.wb_sunny,
    ReadingViewTheme.gray => Icons.blur_on,
  };
}

class ChapterView extends ConsumerStatefulWidget {
  const ChapterView({
    super.key,
    required this.content,
    this.bookId,
    this.chapterId,
    this.fontSize = 18.0,
    this.fontFamily,
    this.fontWeight,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.0,
    this.theme = ReadingViewTheme.light,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.scrollable = true,
    this.onScroll,
    this.onScrollDirectionChanged,
    this.dropCapStyle,
    this.chapterTitle,
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onSearchWeb,
    this.onListen,
    this.onErase,
    this.activeSpeechItem,
    this.restoreCharOffset,
    this.onRestoreRevealed,
    this.onNarrationOutOfSyncChanged,
    this.onRegisterNarrationReveal,
  });

  final String content;

  /// Book and chapter identity for loading/storing highlights from the
  /// in-memory annotations store. Omit to disable highlight rendering.
  final String? bookId;
  final String? chapterId;

  final double fontSize;
  final String? fontFamily;
  /// Numeric reader body-text weight; `null` keeps the family default.
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final ReadingViewTheme theme;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final bool scrollable;
  final void Function(double scrollOffset)? onScroll;
  final void Function(ScrollDirection direction)? onScrollDirectionChanged;
  final TextStyle? dropCapStyle;
  final String? chapterTitle;

  /// Called with the selected text, chosen color and its [content] character
  /// offsets when the reader taps a highlight swatch in the context menu.
  /// Omit to hide highlighting.
  final void Function(String text, Color color, int start, int end)? onHighlight;

  /// Called with the selected text (and surrounding sentence, if available)
  /// when the reader taps "Note". Omit to hide the note action.
  final void Function(String text, String? sentence)? onAddNote;

  /// Called with the selected text when the reader taps "Share". Omit to
  /// hide the share action.
  final void Function(String text)? onShare;

  /// Called with the selected text when the reader taps "Search the web".
  /// Omit to hide the search action.
  final void Function(String text)? onSearchWeb;

  /// Called to speak the selected sentence once ("Listen"). Omit to hide the
  /// listen action.
  final void Function(String text, String? sentence, int start, int end)?
      onListen;

  /// Called to remove any stored highlight overlapping the selection's
  /// [start, end) character range. Omit to hide the erase action.
  final void Function(int start, int end)? onErase;

  /// The sentence currently being narrated, if this chapter is narrating.
  /// When set, that sentence is rendered with a background tint. Omit for no
  /// narration highlighting.
  final SpeechItem? activeSpeechItem;

  /// A character offset (into [content]) to reveal once on open — a one-shot
  /// exact-position resume. Omit for none.
  final int? restoreCharOffset;

  /// Called once [restoreCharOffset] has been revealed so the parent can clear
  /// it and avoid a repeat reveal on every rebuild.
  final void Function()? onRestoreRevealed;

  /// Reports whether this chapter is narrating but its highlighted sentence is
  /// currently out of the visible viewport (true) or back in sync (false).
  /// Used by the parent to show/hide a "jump to narration" affordance.
  final ValueChanged<bool>? onNarrationOutOfSyncChanged;

  /// Lets the parent obtain a handle to scroll this view's narration sentence
  /// into view on demand. Invoked with the reveal callback while this chapter
  /// is the active narrator (and only then, never with `null`). The callback
  /// should be treated as opaque and safe to invoke at any time.
  final void Function(void Function() reveal)? onRegisterNarrationReveal;

  @override
  ConsumerState<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends ConsumerState<ChapterView>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _textKey = GlobalKey();
  double _lastScrollPos = 0;
  bool _didInitNarration = false;
  bool _lastReportedOutOfSync = false;
  bool _revealAnimating = false;
  bool _didRestoreReveal = false;
  ScrollPosition? _listenedPosition;

  /// Matches quoted dialogue/text — straight double quotes and typographic
  /// (curly) double quotes. Single quotes are deliberately excluded since
  /// they're far more often apostrophes/contractions than actual quotation.
  static final _quotePattern = RegExp('"[^"]*"|\u201C[^\u201D]*\u201D');

  /// Stored user highlights for this chapter (empty when identity is absent).
  List<HighlightEntry> get _highlights {
    final bookId = widget.bookId;
    final chapterId = widget.chapterId;
    if (bookId == null || chapterId == null) return const [];
    return ref.watch(annotationsProvider(bookId)).highlights[chapterId] ??
        const [];
  }

  List<(int, int)>? _cachedQuoteRanges;
  String? _cachedQuoteRangesFor;

  /// Fades the narration highlight in on each new sentence rather than
  /// popping it on instantly. Created in [initState] (not lazily) so there's
  /// always a controller to dispose in [dispose]; a lazy initializer that
  /// first ran during unmount would call `createTicker` against a deactivated
  /// widget and crash.
  late final AnimationController _highlightController;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.activeSpeechItem != null ? 1.0 : 0.0,
    );
  }

  EdgeInsets get _padding => switch (widget.marginPreset) {
    MarginPreset.narrow => const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm,
      ),
    MarginPreset.normal => const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
    MarginPreset.wide => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl, vertical: AppSpacing.lg,
      ),
  };

  @override
  void dispose() {
    _listenedPosition?.removeListener(_onOuterScroll);
    _scrollController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitNarration) return;
    _didInitNarration = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureScrollListener();
      _registerNarrationReveal();
      _revealRestoreIfNeeded();
      _refreshOutOfSync();
    });
  }

  @override
  void didUpdateWidget(ChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureScrollListener();
      _registerNarrationReveal();
      _revealRestoreIfNeeded();
      if (widget.activeSpeechItem == null) {
        _highlightController.value = 0.0;
        _refreshOutOfSync();
      } else if (oldWidget.activeSpeechItem?.text != widget.activeSpeechItem?.text) {
        _highlightController.forward(from: 0.0);
        _followActive();
      } else {
        _refreshOutOfSync();
      }
    });
  }

  void _handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent > 0) {
      widget.onScroll?.call(metrics.pixels / metrics.maxScrollExtent);
    }
    if (notification is ScrollUpdateNotification) {
      final delta = metrics.pixels - _lastScrollPos;
      if (delta.abs() > 4) {
        widget.onScrollDirectionChanged?.call(
          delta > 0 ? ScrollDirection.down : ScrollDirection.up,
        );
      }
      _lastScrollPos = metrics.pixels;
    }
  }

  /// Attaches a listener to the nearest scrollable's position so manual
  /// scrolls (which may put the narrated sentence out of view) update the
  /// "jump to narration" affordance live.
  void _ensureScrollListener() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final position = scrollable.position;
    if (_listenedPosition == position) return;
    _listenedPosition?.removeListener(_onOuterScroll);
    _listenedPosition = position;
    position.addListener(_onOuterScroll);
  }

  void _onOuterScroll() {
    if (_revealAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshOutOfSync();
    });
  }

  /// Reports the current sync state to the parent, skipping when unchanged.
  void _reportOutOfSync(bool outOfSync) {
    if (!mounted || _lastReportedOutOfSync == outOfSync) return;
    _lastReportedOutOfSync = outOfSync;
    widget.onNarrationOutOfSyncChanged?.call(outOfSync);
  }

  void _refreshOutOfSync() {
    final narrating = widget.activeSpeechItem != null;
    _reportOutOfSync(narrating && !_isActiveSentenceVisible());
  }

  /// Registers this view's reveal handle with the parent while it is the
  /// active narrator (so the overlay button can call it). Only non-null
  /// handles are ever forwarded; leaving narration is conveyed via the
  /// out-of-sync report instead, so parallel post-frame callbacks can't
  /// wipe a newly registered handle with a stale `null`.
  void _registerNarrationReveal() {
    if (widget.activeSpeechItem == null) return;
    widget.onRegisterNarrationReveal?.call(_followActive);
  }

  /// [SelectableText] composes its actual [RenderEditable] inside gesture/
  /// tap-region wrapper widgets (e.g. TextFieldTapRegion, MouseRegion) that
  /// are themselves RenderObjectWidgets — so `context.findRenderObject()`
  /// on the SelectableText's own key returns the *outer* wrapper's render
  /// object, never the RenderEditable itself. Walk the subtree to find the
  /// real one instead of assuming it's the first render object encountered.
  RenderEditable? _findRenderEditable() {
    final context = _textKey.currentContext;
    if (context == null) return null;
    RenderEditable? found;
    void visitor(Element element) {
      if (found != null) return;
      final renderObject = element.renderObject;
      if (renderObject is RenderEditable) {
        found = renderObject;
        return;
      }
      element.visitChildren(visitor);
    }
    context.visitChildElements(visitor);
    return found;
  }

  bool _isActiveSentenceVisible() {
    final info = _activeSentenceViewport();
    if (info == null) return false;
    const margin = 24.0;
    return info.$2 >= info.$5 + margin && info.$2 <= info.$6 - margin;
  }

  /// Scrolls the nearest scrollable so the currently narrated sentence stays
  /// in view (following the speech), reusing the same text lookup the
  /// highlight does. No-op when the sentence is already fully visible.
  void _followActive() {
    if (!mounted || _revealAnimating) return;
    if (_isActiveSentenceVisible()) {
      _reportOutOfSync(false);
      return;
    }
    final item = widget.activeSpeechItem;
    final idx = _activeTextOffset();
    final scrollable = Scrollable.maybeOf(context);
    final render = _findRenderEditable();
    final viewport = render != null
        ? RenderAbstractViewport.maybeOf(render)
        : null;
    if (item == null || idx == null || idx < 0 || scrollable == null ||
        render == null || viewport == null) {
      return;
    }

    final edge = render.getLocalRectForCaret(TextPosition(offset: idx)).top;
    final revealed = viewport.getOffsetToReveal(
      render,
      0.0,
      rect: Rect.fromLTWH(0, edge, 0, 0),
    );
    final position = scrollable.position;
    const margin = 24.0;
    final target = (revealed.offset - margin).clamp(0.0, position.maxScrollExtent);
    _revealAnimating = true;
    _reportOutOfSync(false);
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    ).whenComplete(() {
      _revealAnimating = false;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshOutOfSync();
        });
      }
    });
  }

  /// One-shot exact-position resume: scrolls this chapter's nearest scrollable
  /// so the character at [widget.restoreCharOffset] is in view, then calls
  /// [widget.onRestoreRevealed] so the parent clears the offset and nothing
  /// re-fires on a later rebuild or navigation. No-op once applied, while no
  /// offset is set, or before layout settles.
  void _revealRestoreIfNeeded() {
    if (_didRestoreReveal) return;
    final offset = widget.restoreCharOffset;
    if (offset == null || offset < 0) return;
    final content = widget.content;
    if (content.isEmpty) return;

    final scrollable = Scrollable.maybeOf(context);
    final render = _findRenderEditable();
    final viewport = render != null
        ? RenderAbstractViewport.maybeOf(render)
        : null;
    if (scrollable == null || render == null || viewport == null) return;

    _didRestoreReveal = true;
    final edge = render
        .getLocalRectForCaret(TextPosition(offset: offset.clamp(0, content.length)))
        .top;
    final revealed = viewport.getOffsetToReveal(
      render,
      0.0,
      rect: Rect.fromLTWH(0, edge, 0, 0),
    );
    final position = scrollable.position;
    final target = (revealed.offset - 24.0).clamp(0.0, position.maxScrollExtent);
    _revealAnimating = true;
    position.jumpTo(target);
    _revealAnimating = false;
    widget.onRestoreRevealed?.call();
  }

  /// Returns `(idx, caretGlobalTop, render, viewport, vpTop, vpBottom)` for the
  /// active sentence, or `null` when there is nothing to reveal.
  (int, double, RenderEditable, RenderAbstractViewport, double, double)?
  _activeSentenceViewport() {
    final item = widget.activeSpeechItem;
    if (item == null) return null;
    final idx = _activeTextOffset();
    if (idx == null || idx < 0) return null;

    final scrollable = Scrollable.maybeOf(context);
    final render = _findRenderEditable();
    if (scrollable == null || render == null) return null;
    final viewport = RenderAbstractViewport.maybeOf(render);
    final viewportBox = scrollable.position.context.storageContext.findRenderObject()
        as RenderBox?;
    if (viewport == null || viewportBox == null) return null;

    final caretTop = render.getLocalRectForCaret(TextPosition(offset: idx)).top;
    final caretGlobalTop = render.localToGlobal(Offset(0, caretTop)).dy;
    final vpTop = viewportBox.localToGlobal(Offset.zero).dy;
    final vpBottom = vpTop + viewportBox.size.height;
    return (idx, caretGlobalTop, render, viewport, vpTop, vpBottom);
  }

  /// Resolves the character offset in [ChapterView.content] where the
  /// currently narrated sentence begins, using the sentence's own
  /// paragraph + sentence indexes rather than a naive text search — so a
  /// name or phrase that also appears earlier in the chapter doesn't pull
  /// the highlight/scroll back to the wrong (first) occurrence.
  int? _activeTextOffset() {
    final item = widget.activeSpeechItem;
    if (item == null) return null;
    final content = widget.content;

    // Reuse the shared paragraph segmentation (trimmed, non-empty, each
    // recording its start offset in the raw content) — the same one
    // ChapterPositionResolver uses for reading-position persistence.
    final segments = const ChapterPositionResolver().paragraphsOf(content);
    if (item.paragraphIndex >= segments.length) return null;
    final para = segments[item.paragraphIndex];
    final paraTrim = para.text.trim();
    if (paraTrim.isEmpty) return null;
    final paraOffsetInSeg = para.text.indexOf(paraTrim);

    final spans = const SentenceSplitter().splitParagraphSpans(paraTrim);
    if (spans.isEmpty) return null;
    final span = spans[item.sentenceIndex.clamp(0, spans.length - 1)];
    final start = para.offset + paraOffsetInSeg + span.offset;

    if (content.startsWith(item.text, start)) return start;

    // The exact sentence couldn't be pinned (e.g. it was hard-split into a
    // piece longer than the per-item cap) — fall back to locating the text
    // inside the correct paragraph before doing a whole-chapter search.
    final inParagraph = paraTrim.indexOf(item.text);
    if (inParagraph >= 0) return para.offset + paraOffsetInSeg + inParagraph;
    final anywhere = content.indexOf(item.text);
    return anywhere >= 0 ? anywhere : null;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      letterSpacing: widget.letterSpacing,
      color: widget.theme.text,
      fontWeight: widget.fontWeight != null ? FontWeight(widget.fontWeight!) : null,
    );

    final content = _buildText(baseStyle);
    if (!widget.scrollable) {
      return Padding(padding: _padding, child: content);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScroll(notification);
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: _padding,
        child: content,
      ),
    );
  }

  Widget _buildText(TextStyle baseStyle) {
    final textStyle = widget.fontFamily != null
        ? GoogleFonts.getFont(widget.fontFamily!, textStyle: baseStyle)
        : baseStyle;

    final ds = widget.dropCapStyle;
    final c = widget.content;
    final highlights = _highlights;

    final active = widget.activeSpeechItem;
    if (active != null) {
      return _narrationHighlighted(c, textStyle);
    }

    if (ds != null && c.isNotEmpty) {
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: c.substring(0, 1), style: ds),
            ..._quoteAwareSpans(c, 1, c.length, textStyle, highlights: highlights),
          ],
        ),
        key: _textKey,
        textAlign: widget.textAlignment.flutterTextAlign,
        contextMenuBuilder: _contextMenuBuilder(c),
      );
    }

    return SelectableText.rich(
      TextSpan(
        children: _quoteAwareSpans(c, 0, c.length, textStyle, highlights: highlights),
      ),
      key: _textKey,
      textAlign: widget.textAlignment.flutterTextAlign,
      contextMenuBuilder: _contextMenuBuilder(c),
    );
  }

  /// Returns [content]'s `[start, end)` range as TextSpans, italicizing any
  /// portion that falls inside a quoted span and laying a user-highlight
  /// background over any portion inside a stored [HighlightEntry]. [extraStyle]
  /// (if given) is merged on top of each resulting span's style — used to layer
  /// the narration highlight's background on top of quote-italic + user-highlight
  /// styling rather than one silently overriding the other.
  List<TextSpan> _quoteAwareSpans(
    String content,
    int start,
    int end,
    TextStyle style, {
    TextStyle? extraStyle,
    List<HighlightEntry> highlights = const [],
  }) {
    if (start >= end) return const [];
    final spans = <TextSpan>[];
    final quoteStyle = style.copyWith(fontStyle: FontStyle.italic);

    // Collect every cut point from quote and highlight boundaries so each
    // emitted segment gets a single, unambiguous style.
    final cuts = <int>{start, end};
    for (final range in _quoteRanges(content)) {
      if (range.$2 <= start || range.$1 >= end) continue;
      cuts.add(range.$1.clamp(start, end));
      cuts.add(range.$2.clamp(start, end));
    }
    for (final h in highlights) {
      if (h.end <= start || h.start >= end) continue;
      cuts.add(h.start.clamp(start, end));
      cuts.add(h.end.clamp(start, end));
    }
    final sorted = cuts.toList()..sort();

    for (var i = 0; i < sorted.length - 1; i++) {
      final segStart = sorted[i];
      final segEnd = sorted[i + 1];
      if (segEnd <= segStart) continue;

      var segStyle = style;
      final inQuote = _quoteRanges(content).any(
        (r) => r.$1 <= segStart && r.$2 >= segEnd,
      );
      if (inQuote) segStyle = quoteStyle;
      for (final h in highlights) {
        if (h.start <= segStart && h.end >= segEnd) {
          segStyle = segStyle.copyWith(
            backgroundColor: h.color.withValues(alpha: 0.30),
          );
          break;
        }
      }
      if (extraStyle != null) segStyle = segStyle.merge(extraStyle);
      spans.add(TextSpan(
        text: content.substring(segStart, segEnd),
        style: segStyle,
      ));
    }
    return spans;
  }

  /// Quoted-text ranges (start, end) within [content], cached since this is
  /// recomputed on every rebuild while narrating (once per sentence).
  List<(int, int)> _quoteRanges(String content) {
    if (_cachedQuoteRangesFor == content && _cachedQuoteRanges != null) {
      return _cachedQuoteRanges!;
    }
    final ranges = [
      for (final m in _quotePattern.allMatches(content)) (m.start, m.end),
    ];
    _cachedQuoteRangesFor = content;
    _cachedQuoteRanges = ranges;
    return ranges;
  }

  /// Renders the whole chapter as a [TextSpan], tinting the currently
  /// narrated sentence's substring (fading the tint in via
  /// [_highlightController] rather than snapping it on) and italicizing any
  /// quoted text throughout. Falls back to plain rendering when the
  /// sentence can't be located (e.g. it crosses a paragraph break).
  Widget _narrationHighlighted(String content, TextStyle textStyle) {
    final item = widget.activeSpeechItem;
    final idx = _activeTextOffset() ?? -1;
    final highlights = _highlights;
    if (item == null || idx < 0) {
      return SelectableText.rich(
        TextSpan(
          children: _quoteAwareSpans(
            content, 0, content.length, textStyle, highlights: highlights,
          ),
        ),
        key: _textKey,
        textAlign: widget.textAlignment.flutterTextAlign,
        contextMenuBuilder: _contextMenuBuilder(content),
      );
    }
    final highlightEnd = idx + item.text.length;
    return AnimatedBuilder(
      animation: _highlightController,
      builder: (context, _) {
        final highlightStyle = TextStyle(
          backgroundColor: widget.theme.accent.withValues(
            alpha: 0.25 * _highlightController.value,
          ),
        );
        return SelectableText.rich(
          TextSpan(
            children: [
              ..._quoteAwareSpans(
                content, 0, idx, textStyle, highlights: highlights,
              ),
              ..._quoteAwareSpans(
                content,
                idx,
                highlightEnd,
                textStyle,
                extraStyle: highlightStyle,
                highlights: highlights,
              ),
              ..._quoteAwareSpans(
                content,
                highlightEnd,
                content.length,
                textStyle,
                highlights: highlights,
              ),
            ],
          ),
          key: _textKey,
          textAlign: widget.textAlignment.flutterTextAlign,
          contextMenuBuilder: _contextMenuBuilder(content),
        );
      },
    );
  }

  static const _highlightPalette = [
    AppContextMenuHighlightOption(color: Color(0xFFFFF176), label: 'Yellow'),
    AppContextMenuHighlightOption(color: Color(0xFFA5D6A7), label: 'Green'),
    AppContextMenuHighlightOption(color: Color(0xFF90CAF9), label: 'Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFF48FB1), label: 'Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFCE93D8), label: 'Purple'),
  ];

  EditableTextContextMenuBuilder _contextMenuBuilder(String fullText) {
    final bookId = widget.bookId;
    final chapterId = widget.chapterId;
    final highlights = (bookId != null && chapterId != null)
        ? ref.read(annotationsProvider(bookId)).highlights[chapterId] ??
              const []
        : const <HighlightEntry>[];

    return AppContextMenu.builder(
      build: (ctx, editable, anchor) {
        final sel = editable.textEditingValue.selection;
        final hasSelection = sel.isValid && !sel.isCollapsed;
        final word = hasSelection
            ? fullText.substring(sel.start, sel.end).trim()
            : '';
        final sentence =
            hasSelection && word.isNotEmpty ? _sentenceAround(fullText, sel) : null;
        final showSelectionActions = hasSelection && word.isNotEmpty;
        final hasOverlappingHighlight =
            highlights.any((h) => h.overlaps(sel.start, sel.end));
        final eraseEnabled =
            showSelectionActions && hasOverlappingHighlight && widget.onErase != null;

        return AppContextMenu(
          anchor: anchor,
          highlightColors: showSelectionActions ? _highlightPalette : const [],
          onHighlightSelected: showSelectionActions && widget.onHighlight != null
              ? (color) => widget.onHighlight!(word, color, sel.start, sel.end)
              : null,
          quickActions: [
            AppContextMenuAction(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              onPressed: () {
                final data = editable.textEditingValue.selection.textInside(
                  editable.textEditingValue.text,
                );
                Clipboard.setData(ClipboardData(text: data));
              },
            ),
            if (showSelectionActions && widget.onAddNote != null)
              AppContextMenuAction(
                label: 'Note',
                icon: Icons.edit_note_rounded,
                onPressed: () => widget.onAddNote!(word, sentence),
              ),
            if (showSelectionActions && widget.onListen != null)
              AppContextMenuAction(
                label: 'Listen',
                icon: Icons.play_circle_outline_rounded,
                onPressed: () => widget.onListen!(word, sentence, sel.start, sel.end),
              ),
            if (showSelectionActions && widget.onShare != null)
              AppContextMenuAction(
                label: 'Share',
                icon: Icons.ios_share_rounded,
                onPressed: () => widget.onShare!(word),
              ),
          ],
          listActions: [
            if (showSelectionActions)
              AppContextMenuAction(
                label: 'Look up "$word"',
                icon: Icons.translate_rounded,
                onPressed: () => _showDefine(word, sentence: sentence),
              ),
            if (eraseEnabled)
              AppContextMenuAction(
                label: 'Erase highlight',
                icon: Icons.format_color_reset_rounded,
                destructive: true,
                onPressed: () => widget.onErase!(sel.start, sel.end),
              ),
            if (showSelectionActions && widget.onSearchWeb != null)
              AppContextMenuAction(
                label: 'Search the web for "$word"',
                icon: Icons.search_rounded,
                onPressed: () => widget.onSearchWeb!(word),
              ),
            AppContextMenuAction(
              label: 'Select all',
              icon: Icons.select_all_rounded,
              onPressed: () => editable.selectAll(SelectionChangedCause.toolbar),
            ),
          ],
        );
      },
    );
  }

  String _sentenceAround(String fullText, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) return '';
    const punctuation = '.!?\n';
    int start = sel.start;
    while (start > 0) {
      if (punctuation.contains(fullText[start - 1])) break;
      start--;
    }
    int end = sel.end;
    while (end < fullText.length) {
      if (punctuation.contains(fullText[end])) break;
      end++;
    }
    if (end < fullText.length) end++;
    return fullText.substring(start, end).trim();
  }

  void _showDefine(String word, {String? sentence}) {
    DraggableBottomSheet.show(
      context: context,
      id: 'word_lookup',
      initialHeight: 0.7,
      child: WordLookupSheet(
        word: word,
        sourceSentence: sentence,
        sourceTitle: widget.chapterTitle,
      ),
    );
  }
}

enum ScrollDirection { up, down }

enum ReadingMode { page, continuous }

enum PageTurnAnimation { slide, fade, reveal, cube, depth }

extension PageTurnAnimationX on PageTurnAnimation {
  String get label => switch (this) {
    PageTurnAnimation.slide => 'Slide',
    PageTurnAnimation.fade => 'Fade',
    PageTurnAnimation.reveal => 'Reveal',
    PageTurnAnimation.cube => 'Cube',
    PageTurnAnimation.depth => 'Depth',
  };

  IconData get icon => switch (this) {
    PageTurnAnimation.slide => Icons.arrow_forward,
    PageTurnAnimation.fade => Icons.blur_on,
    PageTurnAnimation.reveal => Icons.swap_horiz,
    PageTurnAnimation.cube => Icons.view_in_ar,
    PageTurnAnimation.depth => Icons.layers,
  };
}

enum ScrollAnimation { smooth, snap, fadeEdges, parallax, glow }

extension ScrollAnimationX on ScrollAnimation {
  String get label => switch (this) {
    ScrollAnimation.smooth => 'Smooth',
    ScrollAnimation.snap => 'Snap',
    ScrollAnimation.fadeEdges => 'Fade Edges',
    ScrollAnimation.parallax => 'Parallax',
    ScrollAnimation.glow => 'Scroll Glow',
  };

  IconData get icon => switch (this) {
    ScrollAnimation.smooth => Icons.swap_vert,
    ScrollAnimation.snap => Icons.first_page,
    ScrollAnimation.fadeEdges => Icons.blur_linear,
    ScrollAnimation.parallax => Icons.view_carousel,
    ScrollAnimation.glow => Icons.touch_app,
  };
}

extension ReadingModeX on ReadingMode {
  String get label => switch (this) {
    ReadingMode.page => 'Page Mode',
    ReadingMode.continuous => 'Continuous',
  };
}

enum ReaderChromeStyle { translucent, frosted }

extension ReaderChromeStyleX on ReaderChromeStyle {
  String get label => switch (this) {
    ReaderChromeStyle.translucent => 'Translucent',
    ReaderChromeStyle.frosted => 'Frosted Glass',
  };

  IconData get icon => switch (this) {
    ReaderChromeStyle.translucent => Icons.blur_on,
    ReaderChromeStyle.frosted => Icons.grain,
  };
}

enum TextAlignment { left, justify, center, right }

extension TextAlignmentX on TextAlignment {
  String get label => switch (this) {
    TextAlignment.left => 'Left',
    TextAlignment.justify => 'Justify',
    TextAlignment.center => 'Center',
    TextAlignment.right => 'Right',
  };

  TextAlign get flutterTextAlign => switch (this) {
    TextAlignment.left => TextAlign.left,
    TextAlignment.justify => TextAlign.justify,
    TextAlignment.center => TextAlign.center,
    TextAlignment.right => TextAlign.right,
  };
}

enum MarginPreset { narrow, normal, wide }

extension MarginPresetX on MarginPreset {
  String get label => switch (this) {
    MarginPreset.narrow => 'Narrow',
    MarginPreset.normal => 'Normal',
    MarginPreset.wide => 'Wide',
  };
}