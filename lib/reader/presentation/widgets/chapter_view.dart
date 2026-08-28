import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show Selectable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/utils/glossary_highlight_ranges.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_widget.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_narration_coordinator.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_span_builder.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

export 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
export 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

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
    this.theme = ReadingViewTheme.paper,
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
    this.spans,
  });

  final String content;

  /// Optional block-card scan of [content]: prose/card spans in reading
  /// order. When set, the continuous renderer interleaves detected
  /// status cards ([BlockCardWidget]) with normally styled prose
  /// segments; all highlight/narration offsets stay chapter-global
  /// because each card's rawText is part of [content]. When narration
  /// is active the flat single-text path is used instead so speech
  /// offset math is never affected. Null keeps the legacy behavior.
  final List<ContentSpan>? spans;

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
  final void Function(String text, Color color, int start, int end)?
  onHighlight;

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
  static const _spanBuilder = ChapterSpanBuilder();
  static const _selectionMenuBuilder = ChapterSelectionMenuBuilder();
  static const _narrationCoordinator = ChapterNarrationCoordinator();

  final _scrollController = ScrollController();
  final _textKey = GlobalKey();
  double _lastScrollPos = 0;
  bool _didInitNarration = false;
  bool _lastReportedOutOfSync = false;
  bool _revealAnimating = false;
  bool _didRestoreReveal = false;
  ScrollPosition? _listenedPosition;

  /// Prose-chunk map recorded by [_buildSegmented]: each entry is
  /// (renderStart, renderEnd, contentStart) for one contiguous run of prose
  /// text.
  List<(int, int, int)>? _renderContentMap;

  /// Stored user highlights for this chapter (empty when identity is absent).
  List<HighlightEntry> get _highlights {
    final bookId = widget.bookId;
    final chapterId = widget.chapterId;
    if (bookId == null || chapterId == null) return const [];
    return ref.watch(annotationsProvider(bookId)).highlights[chapterId] ??
        const [];
  }

  /// Glossary-replacement highlights for [content], tinted with the system
  /// theme's secondary container so they stay readable in light and dark mode.
  List<HighlightEntry> _glossaryHighlights(String content) {
    final bookId = widget.bookId;
    final chapterId = widget.chapterId;
    if (bookId == null || chapterId == null || content.isEmpty) {
      return const [];
    }
    final entries =
        ref.watch(atlasGlossaryProvider(bookId)).valueOrNull ?? const [];
    return glossaryHighlightRanges(
      chapterId: chapterId,
      content: content,
      entries: entries,
      color: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  /// Fades the narration highlight in on each new sentence rather than
  /// popping it on instantly.
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
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    MarginPreset.normal => const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    MarginPreset.wide => const EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.lg,
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
      } else if (oldWidget.activeSpeechItem?.text !=
          widget.activeSpeechItem?.text) {
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
    final isVisible = _narrationCoordinator.isSentenceVisible(
      context: context,
      textKey: _textKey,
      activeSpeechItem: widget.activeSpeechItem,
      content: widget.content,
    );
    _reportOutOfSync(narrating && !isVisible);
  }

  /// Registers this view's reveal handle with the parent while it is the
  /// active narrator (so the overlay button can call it).
  void _registerNarrationReveal() {
    if (widget.activeSpeechItem == null) return;
    widget.onRegisterNarrationReveal?.call(_followActive);
  }

  /// Scrolls the nearest scrollable so the currently narrated sentence stays
  /// in view.
  void _followActive() {
    if (!mounted || _revealAnimating) return;
    _narrationCoordinator.revealSentence(
      context: context,
      textKey: _textKey,
      activeSpeechItem: widget.activeSpeechItem,
      content: widget.content,
      onAnimatingStart: () {
        _revealAnimating = true;
      },
      onAnimatingEnd: () {
        _revealAnimating = false;
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _refreshOutOfSync();
          });
        }
      },
      onReportSync: _reportOutOfSync,
    );
  }

  /// One-shot exact-position resume: scrolls so the character at
  /// [widget.restoreCharOffset] is in view.
  void _revealRestoreIfNeeded() {
    if (_didRestoreReveal) return;
    _didRestoreReveal = true;
    _narrationCoordinator.revealRestoreOffset(
      context: context,
      textKey: _textKey,
      restoreCharOffset: widget.restoreCharOffset,
      content: widget.content,
      onRestored: () {
        widget.onRestoreRevealed?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      letterSpacing: widget.letterSpacing,
      color: widget.theme.resolve(colorScheme).text,
      fontWeight: widget.fontWeight != null
          ? FontWeight(widget.fontWeight!)
          : null,
    );

    final content = _buildText(baseStyle);
    if (!widget.scrollable) {
      return Padding(padding: _padding, child: content);
    }

    return SelectionArea(
      contextMenuBuilder: _selectionAreaContextMenuBuilder,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScroll(notification);
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: _padding,
          child: content,
        ),
      ),
    );
  }

  Widget _buildText(TextStyle baseStyle) {
    final textStyle = widget.fontFamily != null
        ? baseStyle.copyWith(fontFamily: widget.fontFamily)
        : baseStyle;

    final ds = widget.dropCapStyle;
    final c = widget.content;
    final highlights = [..._highlights, ..._glossaryHighlights(c)];

    final active = widget.activeSpeechItem;
    if (active != null || widget.spans == null) {
      _renderContentMap = null;
      return _buildFlat(c, textStyle, highlights, ds);
    }
    return _buildSegmented(textStyle, highlights, applyDropCap: ds != null);
  }

  Widget _buildFlat(
    String c,
    TextStyle textStyle,
    List<HighlightEntry> highlights,
    TextStyle? dropCapStyle,
  ) {
    final active = widget.activeSpeechItem;
    if (active != null) {
      return _narrationHighlighted(c, textStyle);
    }

    if (dropCapStyle != null && c.isNotEmpty) {
      return RichText(
        key: _textKey,
        textAlign: widget.textAlignment.flutterTextAlign,
        text: TextSpan(
          children: [
            TextSpan(text: c.substring(0, 1), style: dropCapStyle),
            ..._spanBuilder.buildQuoteAwareSpans(
              c,
              1,
              c.length,
              textStyle,
              highlights: highlights,
            ),
          ],
        ),
      );
    }

    return RichText(
      key: _textKey,
      textAlign: widget.textAlignment.flutterTextAlign,
      text: TextSpan(
        children: _spanBuilder.buildQuoteAwareSpans(
          c,
          0,
          c.length,
          textStyle,
          highlights: highlights,
        ),
      ),
    );
  }

  /// Renders the chapter as a single [RichText] with [WidgetSpan] for cards.
  Widget _buildSegmented(
    TextStyle textStyle,
    List<HighlightEntry> highlights, {
    required bool applyDropCap,
  }) {
    final (richSpans, renderMap) = _spanBuilder.buildSegmentedSpans(
      spans: widget.spans!,
      content: widget.content,
      textStyle: textStyle,
      readingColors: widget.theme.resolve(Theme.of(context).colorScheme),
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      highlights: highlights,
      dropCapStyle: widget.dropCapStyle,
      applyDropCap: applyDropCap,
    );
    _renderContentMap = renderMap;

    return RichText(
      key: _textKey,
      textAlign: widget.textAlignment.flutterTextAlign,
      text: TextSpan(children: richSpans),
    );
  }

  /// Renders the whole chapter as a [TextSpan], tinting the currently
  /// narrated sentence's substring.
  Widget _narrationHighlighted(String content, TextStyle textStyle) {
    final item = widget.activeSpeechItem;
    final idx = _narrationCoordinator.resolveActiveSpeechOffset(
      item: item,
      content: content,
    ) ?? -1;
    final highlights = _highlights;

    if (item == null || idx < 0) {
      return RichText(
        key: _textKey,
        textAlign: widget.textAlignment.flutterTextAlign,
        text: TextSpan(
          children: _spanBuilder.buildQuoteAwareSpans(
            content,
            0,
            content.length,
            textStyle,
            highlights: highlights,
          ),
        ),
      );
    }
    final highlightEnd = idx + item.text.length;
    return AnimatedBuilder(
      animation: _highlightController,
      builder: (context, _) {
        final highlightStyle = TextStyle(
          backgroundColor: widget.theme
              .resolve(Theme.of(context).colorScheme)
              .accent
              .withValues(alpha: 0.25 * _highlightController.value),
        );
        return RichText(
          key: _textKey,
          textAlign: widget.textAlignment.flutterTextAlign,
          text: TextSpan(
            children: [
              ..._spanBuilder.buildQuoteAwareSpans(
                content,
                0,
                idx,
                textStyle,
                highlights: highlights,
              ),
              ..._spanBuilder.buildQuoteAwareSpans(
                content,
                idx,
                highlightEnd,
                textStyle,
                extraStyle: highlightStyle,
                highlights: highlights,
              ),
              ..._spanBuilder.buildQuoteAwareSpans(
                content,
                highlightEnd,
                content.length,
                textStyle,
                highlights: highlights,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _selectionAreaContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final bookId = widget.bookId;
    final chapterId = widget.chapterId;
    final highlights = (bookId != null && chapterId != null)
        ? ref.read(annotationsProvider(bookId)).highlights[chapterId] ??
              const []
        : const <HighlightEntry>[];

    final render = _narrationCoordinator.findRenderParagraph(_textKey);
    final selectable = render is Selectable ? render as Selectable : null;

    return _selectionMenuBuilder.buildContextMenu(
      context: context,
      selectableRegionState: selectableRegionState,
      content: widget.content,
      bookId: bookId,
      chapterId: chapterId,
      chapterTitle: widget.chapterTitle,
      highlights: highlights,
      renderContentMap: _renderContentMap,
      selectable: selectable,
      onHighlight: widget.onHighlight,
      onAddNote: widget.onAddNote,
      onShare: widget.onShare,
      onSearchWeb: widget.onSearchWeb,
      onListen: widget.onListen,
      onErase: widget.onErase,
    );
  }
}
