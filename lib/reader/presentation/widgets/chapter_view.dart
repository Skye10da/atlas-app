import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show Selectable;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/utils/glossary_highlight_ranges.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_narration_coordinator.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_span_builder.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

export 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
export 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

class ChapterView extends HookConsumerWidget {
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
    this.horizontalPadding,
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
    this.onTap,
  });

  final String content;
  final List<ContentSpan>? spans;
  final String? bookId;
  final String? chapterId;
  final double fontSize;
  final String? fontFamily;
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final ReadingViewTheme theme;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final double? horizontalPadding;
  final bool scrollable;
  final void Function(double scrollOffset)? onScroll;
  final void Function(ScrollDirection direction)? onScrollDirectionChanged;
  final TextStyle? dropCapStyle;
  final String? chapterTitle;

  final void Function(
    String text,
    Color color,
    int start,
    int end, {
    HighlightStyleType styleType,
  })? onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)? onListen;
  final void Function(int start, int end)? onErase;
  final VoidCallback? onTap;
  final SpeechItem? activeSpeechItem;
  final int? restoreCharOffset;
  final void Function()? onRestoreRevealed;
  final ValueChanged<bool>? onNarrationOutOfSyncChanged;
  final void Function(void Function() reveal)? onRegisterNarrationReveal;

  static const _spanBuilder = ChapterSpanBuilder();
  static const _selectionMenuBuilder = ChapterSelectionMenuBuilder();
  static const _narrationCoordinator = ChapterNarrationCoordinator();

  EdgeInsets get _padding {
    final vPadding = switch (marginPreset) {
      MarginPreset.narrow => AppSpacing.sm,
      MarginPreset.normal => AppSpacing.md,
      MarginPreset.wide => AppSpacing.lg,
    };
    final hPadding = horizontalPadding ??
        switch (marginPreset) {
          MarginPreset.narrow => AppSpacing.md,
          MarginPreset.normal => AppSpacing.lg,
          MarginPreset.wide => AppSpacing.xxl,
        };
    return EdgeInsets.symmetric(
      horizontal: hPadding,
      vertical: vPadding,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final textKey = useMemoized(() => GlobalKey());
    final lastScrollPos = useRef(0.0);
    final lastReportedOutOfSync = useRef(false);
    final revealAnimating = useRef(false);
    final didRestoreReveal = useRef(false);
    final listenedPosition = useRef<ScrollPosition?>(null);
    final renderContentMap = useRef<List<(int, int, int)>?>(null);

    final highlightController = useAnimationController(
      duration: const Duration(milliseconds: 380),
      initialValue: activeSpeechItem != null ? 1.0 : 0.0,
    );

    void reportOutOfSync(bool outOfSync) {
      if (!context.mounted || lastReportedOutOfSync.value == outOfSync) return;
      lastReportedOutOfSync.value = outOfSync;
      onNarrationOutOfSyncChanged?.call(outOfSync);
    }

    void refreshOutOfSync() {
      final narrating = activeSpeechItem != null;
      final isVisible = _narrationCoordinator.isSentenceVisible(
        context: context,
        textKey: textKey,
        activeSpeechItem: activeSpeechItem,
        content: content,
      );
      reportOutOfSync(narrating && !isVisible);
    }

    void followActive() {
      if (!context.mounted || revealAnimating.value) return;
      _narrationCoordinator.revealSentence(
        context: context,
        textKey: textKey,
        activeSpeechItem: activeSpeechItem,
        content: content,
        onAnimatingStart: () {
          revealAnimating.value = true;
        },
        onAnimatingEnd: () {
          revealAnimating.value = false;
          if (context.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) refreshOutOfSync();
            });
          }
        },
        onReportSync: reportOutOfSync,
      );
    }

    void revealRestoreIfNeeded() {
      if (restoreCharOffset == null || restoreCharOffset! <= 0) return;
      if (didRestoreReveal.value) return;
      didRestoreReveal.value = true;
      _narrationCoordinator.revealRestoreOffset(
        context: context,
        textKey: textKey,
        restoreCharOffset: restoreCharOffset,
        content: content,
        renderContentMap: renderContentMap.value,
        onRestored: () {
          onRestoreRevealed?.call();
        },
      );
    }

    void onOuterScroll() {
      if (revealAnimating.value) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) refreshOutOfSync();
      });
    }

    void ensureScrollListener() {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      final position = scrollable.position;
      if (listenedPosition.value == position) return;
      listenedPosition.value?.removeListener(onOuterScroll);
      listenedPosition.value = position;
      position.addListener(onOuterScroll);
    }

    void registerNarrationReveal() {
      if (activeSpeechItem == null) return;
      onRegisterNarrationReveal?.call(followActive);
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ensureScrollListener();
        registerNarrationReveal();
        revealRestoreIfNeeded();
        refreshOutOfSync();
      });
      return () {
        listenedPosition.value?.removeListener(onOuterScroll);
      };
    }, const []);

    final prevActiveText = useRef<String?>(activeSpeechItem?.text);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ensureScrollListener();
        registerNarrationReveal();
        revealRestoreIfNeeded();
        if (activeSpeechItem == null) {
          highlightController.value = 0.0;
          refreshOutOfSync();
        } else if (prevActiveText.value != activeSpeechItem?.text) {
          highlightController.forward(from: 0.0);
          followActive();
        } else {
          refreshOutOfSync();
        }
        prevActiveText.value = activeSpeechItem?.text;
      });
      return null;
    }, [activeSpeechItem?.text]);

    void handleScroll(ScrollNotification notification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent > 0) {
        onScroll?.call(metrics.pixels / metrics.maxScrollExtent);
      }
      if (notification is ScrollUpdateNotification) {
        final delta = metrics.pixels - lastScrollPos.value;
        if (delta.abs() > 4) {
          onScrollDirectionChanged?.call(
            delta > 0 ? ScrollDirection.down : ScrollDirection.up,
          );
        }
        lastScrollPos.value = metrics.pixels;
      }
    }

    final quotes = useMemoized(() => _spanBuilder.findQuoteRanges(content), [content]);

    final highlights = (bookId != null && chapterId != null)
        ? ref.watch(annotationsProvider(bookId!)).highlights[chapterId!] ??
              const <HighlightEntry>[]
        : const <HighlightEntry>[];

    final glossaryHighlightsList = useMemoized(() {
      if (bookId == null || chapterId == null || content.isEmpty) {
        return const <HighlightEntry>[];
      }
      final entries =
          ref.watch(atlasGlossaryProvider(bookId!)).valueOrNull ?? const [];
      return glossaryHighlightRanges(
        chapterId: chapterId!,
        content: content,
        entries: entries,
        color: Theme.of(context).colorScheme.secondaryContainer,
      );
    }, [bookId, chapterId, content, ref.watch(atlasGlossaryProvider(bookId ?? ''))]);

    final allHighlights = useMemoized(
      () => [...highlights, ...glossaryHighlightsList],
      [highlights, glossaryHighlightsList],
    );

    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: theme.resolve(colorScheme).text,
      fontWeight: fontWeight != null ? FontWeight(fontWeight!) : null,
    );

    Widget buildSegmented(
      TextStyle textStyle,
      List<HighlightEntry> hls,
      BuildContext selectionContext, {
      required bool applyDropCap,
    }) {
      final (richSpans, renderMap) = _spanBuilder.buildSegmentedSpans(
        spans: spans!,
        content: content,
        textStyle: textStyle,
        readingColors: theme.resolve(colorScheme),
        fontSize: fontSize,
        lineHeight: lineHeight,
        highlights: hls,
        dropCapStyle: dropCapStyle,
        applyDropCap: applyDropCap,
      );
      renderContentMap.value = renderMap;

      final registrar = SelectionContainer.maybeOf(selectionContext);
      final selectionColor = theme
          .resolve(colorScheme)
          .accent
          .withValues(alpha: 0.3);

      return RichText(
        key: textKey,
        textAlign: textAlignment.flutterTextAlign,
        selectionRegistrar: registrar,
        selectionColor: selectionColor,
        text: TextSpan(children: richSpans),
      );
    }

    Widget narrationHighlighted(
      String c,
      TextStyle textStyle,
      BuildContext selectionContext,
    ) {
      final item = activeSpeechItem;
      final idx = _narrationCoordinator.resolveActiveSpeechOffset(
        item: item,
        content: c,
      ) ?? -1;

      final registrar = SelectionContainer.maybeOf(selectionContext);
      final accent = theme.resolve(colorScheme).accent;
      final selectionColor = accent.withValues(alpha: 0.3);

      if (item == null || idx < 0) {
        return RichText(
          key: textKey,
          textAlign: textAlignment.flutterTextAlign,
          selectionRegistrar: registrar,
          selectionColor: selectionColor,
          text: TextSpan(
            children: _spanBuilder.buildQuoteAwareSpans(
              c,
              0,
              c.length,
              textStyle,
              highlights: highlights,
              quoteRanges: quotes,
            ),
          ),
        );
      }
      final paraRange = _narrationCoordinator.resolveActiveParagraphRange(
        item: item,
        content: c,
      );

      final sStart = idx.clamp(0, c.length);
      final sEnd = (idx + item.text.length).clamp(0, c.length);
      final pStart = (paraRange?.start ?? sStart).clamp(0, sStart);
      final pEnd = (paraRange?.end ?? sEnd).clamp(sEnd, c.length);

      final beforeParaSpans = _spanBuilder.buildQuoteAwareSpans(
        c,
        0,
        pStart,
        textStyle,
        highlights: highlights,
        quoteRanges: quotes,
      );
      final afterParaSpans = _spanBuilder.buildQuoteAwareSpans(
        c,
        pEnd,
        c.length,
        textStyle,
        highlights: highlights,
        quoteRanges: quotes,
      );
      final beforeSentenceInParaSpans = _spanBuilder.buildQuoteAwareSpans(
        c,
        pStart,
        sStart,
        textStyle,
        highlights: highlights,
        quoteRanges: quotes,
      );
      final afterSentenceInParaSpans = _spanBuilder.buildQuoteAwareSpans(
        c,
        sEnd,
        pEnd,
        textStyle,
        highlights: highlights,
        quoteRanges: quotes,
      );
      final activeSentenceSpans = _spanBuilder.buildQuoteAwareSpans(
        c,
        sStart,
        sEnd,
        textStyle,
        highlights: highlights,
        quoteRanges: quotes,
      );

      return AnimatedBuilder(
        animation: highlightController,
        builder: (context, _) {
          final animValue = highlightController.value;
          final paraBg = accent.withValues(alpha: 0.10 * animValue);
          final sentenceBg = accent.withValues(alpha: 0.28 * animValue);

          TextSpan applyBg(TextSpan span, Color bg) {
            return TextSpan(
              text: span.text,
              children: span.children
                  ?.map((c) => c is TextSpan ? applyBg(c, bg) : c)
                  .toList(),
              style: (span.style ?? textStyle).copyWith(
                backgroundColor: bg,
              ),
            );
          }

          return RichText(
            key: textKey,
            textAlign: textAlignment.flutterTextAlign,
            selectionRegistrar: registrar,
            selectionColor: selectionColor,
            text: TextSpan(
              children: [
                ...beforeParaSpans,
                ...beforeSentenceInParaSpans.map((s) => applyBg(s, paraBg)),
                ...activeSentenceSpans.map((s) => applyBg(s, sentenceBg)),
                ...afterSentenceInParaSpans.map((s) => applyBg(s, paraBg)),
                ...afterParaSpans,
              ],
            ),
          );
        },
      );
    }

    Widget buildFlat(
      String c,
      TextStyle textStyle,
      List<HighlightEntry> hls,
      TextStyle? ds,
      BuildContext selectionContext,
    ) {
      if (activeSpeechItem != null) {
        return narrationHighlighted(c, textStyle, selectionContext);
      }

      final registrar = SelectionContainer.maybeOf(selectionContext);
      final selectionColor = theme
          .resolve(colorScheme)
          .accent
          .withValues(alpha: 0.3);

      if (ds != null && c.isNotEmpty) {
        return RichText(
          key: textKey,
          textAlign: textAlignment.flutterTextAlign,
          selectionRegistrar: registrar,
          selectionColor: selectionColor,
          text: TextSpan(
            children: [
              TextSpan(text: c.substring(0, 1), style: ds),
              ..._spanBuilder.buildQuoteAwareSpans(
                c,
                1,
                c.length,
                textStyle,
                highlights: hls,
              ),
            ],
          ),
        );
      }

      return RichText(
        key: textKey,
        textAlign: textAlignment.flutterTextAlign,
        selectionRegistrar: registrar,
        selectionColor: selectionColor,
        text: TextSpan(
          children: _spanBuilder.buildQuoteAwareSpans(
            c,
            0,
            c.length,
            textStyle,
            highlights: hls,
          ),
        ),
      );
    }

    Widget buildText(TextStyle style, BuildContext selectionContext) {
      final textStyle = fontFamily != null
          ? style.copyWith(fontFamily: fontFamily)
          : style;

      final ds = dropCapStyle;
      final c = content;

      if (activeSpeechItem != null || spans == null) {
        renderContentMap.value = null;
        return buildFlat(c, textStyle, allHighlights, ds, selectionContext);
      }
      return buildSegmented(
        textStyle,
        allHighlights,
        selectionContext,
        applyDropCap: ds != null,
      );
    }

    final activeSelectableRegion = useRef<SelectableRegionState?>(null);

    Widget selectionAreaContextMenuBuilder(
      BuildContext context,
      SelectableRegionState selectableRegionState,
    ) {
      activeSelectableRegion.value = selectableRegionState;
      final render = _narrationCoordinator.findRenderParagraph(textKey);
      final selectable = render is Selectable ? render as Selectable : null;

      return _selectionMenuBuilder.buildContextMenu(
        context: context,
        selectableRegionState: selectableRegionState,
        content: content,
        bookId: bookId,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        highlights: highlights,
        renderContentMap: renderContentMap.value,
        selectable: selectable,
        renderParagraph: render,
        onHighlight: onHighlight,
        onAddNote: onAddNote,
        onShare: onShare,
        onSearchWeb: onSearchWeb,
        onListen: onListen,
        onErase: onErase,
      );
    }

    void handleTap(BuildContext selectionContext) {
      final regionState = selectionContext.findAncestorStateOfType<SelectableRegionState>() ??
          activeSelectableRegion.value;
      final render = _narrationCoordinator.findRenderParagraph(textKey);
      final hasRenderSelection = render != null &&
          render.selections.isNotEmpty && // ignore: invalid_use_of_visible_for_testing_member
          !render.selections.first.isCollapsed; // ignore: invalid_use_of_visible_for_testing_member
      final hasSelection = hasRenderSelection || activeSelectableRegion.value != null;

      if (hasSelection) {
        regionState?.clearSelection();
        regionState?.hideToolbar();
        activeSelectableRegion.value = null;
        return;
      }
      onTap?.call();
    }

    if (!scrollable) {
      return SelectionArea(
        contextMenuBuilder: selectionAreaContextMenuBuilder,
        child: Builder(builder: (selectionContext) {
          final textWidget = buildText(baseStyle, selectionContext);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => handleTap(selectionContext),
            child: Padding(padding: _padding, child: textWidget),
          );
        }),
      );
    }

    return SelectionArea(
      contextMenuBuilder: selectionAreaContextMenuBuilder,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          handleScroll(notification);
          return false;
        },
        child: SingleChildScrollView(
          controller: scrollController,
          child: Builder(builder: (selectionContext) {
            final textWidget = buildText(baseStyle, selectionContext);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => handleTap(selectionContext),
              child: Padding(padding: _padding, child: textWidget),
            );
          }),
        ),
      ),
    );
  }
}

