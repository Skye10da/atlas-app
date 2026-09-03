/// A single paginated page of chapter content: text spans with highlight
/// layering, the selection context menu (define/note/listen/share), and the
/// chapter header/footer chrome on boundary pages. Extracted from the reader
/// shell so the layout file stays focused on navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_chrome_pieces.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_narration_coordinator.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

class PagedPageView extends StatelessWidget {
  const PagedPageView({
    super.key,
    required this.content,
    required this.chapterTitle,
    required this.chapterIndex,
    this.bookId,
    this.chapterId,
    this.pageStartOffset = 0,
    this.highlights = const [],
    this.activeSpeechItem,
    this.fullChapterContent,
    required this.isFirstPageOfChapter,
    required this.isLastPageOfChapter,
    required this.textStyle,
    this.fontFamily,
    required this.textAlignment,
    required this.marginPreset,
    this.horizontalPadding,
    required this.vt,
    this.showHeaders = true,
    this.chapterStyle,
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onSearchWeb,
    this.onListen,
    this.onErase,
    this.onSetGlossaryTerm,
    this.onTap,
  });

  final String content;
  final String chapterTitle;
  final int chapterIndex;

  /// Book/chapter identity for storing page-relative selections back as
  /// chapter-relative highlights. Omit to disable highlight handling.
  final String? bookId;
  final String? chapterId;

  /// Character offset of this page within its chapter's content, so
  /// page-local selection offsets can be mapped to chapter-global offsets.
  final int pageStartOffset;

  /// Stored highlights for this chapter; those intersecting this page's slice
  /// are rendered as backgrounds.
  final List<HighlightEntry> highlights;

  /// Currently narrated speech item, for speech/paragraph highlighting on this page.
  final SpeechItem? activeSpeechItem;

  /// Full text of the chapter containing this page, for speech offset resolution.
  final String? fullChapterContent;

  final bool isFirstPageOfChapter;
  final bool isLastPageOfChapter;
  final TextStyle textStyle;
  final String? fontFamily;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final double? horizontalPadding;
  final ReadingViewTheme vt;
  final bool showHeaders;
  final ChapterStyle? chapterStyle;
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
  final void Function(String text, String? sentence, int start, int end)?
  onListen;
  final void Function(int start, int end)? onErase;

  /// Called with the selected text so the host can define a glossary term for
  /// it. Omit to hide the "Set as term…" action.
  final ValueChanged<String>? onSetGlossaryTerm;

  /// Called when the page text is single-tapped so the reader can toggle chrome.
  final VoidCallback? onTap;

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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedStyle = fontFamily != null
        ? textStyle.copyWith(fontFamily: fontFamily)
        : textStyle;
    final cs = chapterStyle;

    return Container(
      color: vt.resolve(colorScheme).background,
      child: Column(
        children: [
          if (isFirstPageOfChapter && showHeaders && cs != null)
            ChapterHeaderBanner(
              chapterNumber: chapterIndex + 1,
              title: chapterTitle,
              style: cs,
            ),
          if (isFirstPageOfChapter && showHeaders && cs != null)
            ChapterOrnamentalDivider(
              accentColor: cs.accentColor,
              verticalPadding: 4,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: _padding,
              child: _buildText(context, resolvedStyle, cs),
            ),
          ),
          if (isLastPageOfChapter && showHeaders) ...[
            if (cs != null)
              ChapterOrnamentalDivider(accentColor: cs.accentColor),
            ChapterEndFooter(
              chapterNumber: chapterIndex + 1,
              textColor: vt.resolve(colorScheme).text,
              baseFontSize: textStyle.fontSize!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildText(BuildContext context, TextStyle resolvedStyle, ChapterStyle? cs) {
    final c = content;
    final contextMenu = _contextMenuBuilder(c);
    final pageHighlights = _pageHighlights(context, c);

    final spans = _pageSpans(c, resolvedStyle, pageHighlights);

    void handleTap() {
      if (onTap == null) return;
      onTap!();
    }

    if (cs != null && isFirstPageOfChapter && c.isNotEmpty) {
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: c.substring(0, 1), style: cs.dropCapStyle),
            ..._restSpans(c, resolvedStyle, pageHighlights),
          ],
        ),
        textAlign: textAlignment.flutterTextAlign,
        contextMenuBuilder: contextMenu,
        onTap: handleTap,
      );
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlignment.flutterTextAlign,
      contextMenuBuilder: contextMenu,
      onTap: handleTap,
    );
  }

  /// Highlights whose chapter-global range intersects this page's slice,
  /// translated into page-local coordinates, including active narration highlights.
  List<HighlightEntry> _pageHighlights(BuildContext context, String pageContent) {
    if (chapterId == null || pageStartOffset >= (fullChapterContent?.length ?? pageContent.length + pageStartOffset)) {
      return const [];
    }
    final out = <HighlightEntry>[];
    for (final h in highlights) {
      final localStart = h.start - pageStartOffset;
      final localEnd = h.end - pageStartOffset;
      if (localEnd <= 0 || localStart >= pageContent.length) continue;
      out.add(
        HighlightEntry(
          chapterId: h.chapterId,
          start: localStart.clamp(0, pageContent.length),
          end: localEnd.clamp(0, pageContent.length),
          text: h.text,
          colorValue: h.colorValue,
          styleType: h.styleType,
          bounds: h.bounds,
        ),
      );
    }

    if (activeSpeechItem != null &&
        activeSpeechItem!.chapterId == chapterId &&
        fullChapterContent != null &&
        fullChapterContent!.isNotEmpty) {
      final paraRange = const ChapterNarrationCoordinator().resolveActiveParagraphRange(
        item: activeSpeechItem,
        content: fullChapterContent!,
      );
      final speechOffset = const ChapterNarrationCoordinator().resolveActiveSpeechOffset(
        item: activeSpeechItem,
        content: fullChapterContent!,
      );
      final accentColor = vt.resolve(Theme.of(context).colorScheme).accent;

      if (paraRange != null) {
        final localParaStart = (paraRange.start - pageStartOffset).clamp(0, pageContent.length);
        final localParaEnd = (paraRange.end - pageStartOffset).clamp(0, pageContent.length);
        if (localParaEnd > localParaStart) {
          out.add(
            HighlightEntry(
              chapterId: chapterId ?? '',
              start: localParaStart,
              end: localParaEnd,
              text: pageContent.substring(localParaStart, localParaEnd),
              colorValue: accentColor.withValues(alpha: 0.12).toARGB32(),
            ),
          );
        }
      }

      if (speechOffset != null) {
        final localSpeechStart = (speechOffset - pageStartOffset).clamp(0, pageContent.length);
        final localSpeechEnd = (speechOffset + activeSpeechItem!.text.length - pageStartOffset).clamp(0, pageContent.length);
        if (localSpeechEnd > localSpeechStart) {
          out.add(
            HighlightEntry(
              chapterId: chapterId ?? '',
              start: localSpeechStart,
              end: localSpeechEnd,
              text: pageContent.substring(localSpeechStart, localSpeechEnd),
              colorValue: accentColor.withValues(alpha: 0.32).toARGB32(),
            ),
          );
        }
      }
    }

    return out;
  }

  /// Plain body spans (drop-cap first char excluded) with highlight layering.
  List<TextSpan> _restSpans(
    String c,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    if (c.length <= 1) return const [];
    return _buildLayeredSpans(c, 1, c.length, resolvedStyle, pageHighlights);
  }

  /// Whole-page spans with highlight layering.
  List<TextSpan> _pageSpans(
    String c,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    if (c.isEmpty) return const [];
    return _buildLayeredSpans(c, 0, c.length, resolvedStyle, pageHighlights);
  }

  List<TextSpan> _buildLayeredSpans(
    String c,
    int startOffset,
    int endOffset,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    if (pageHighlights.isEmpty) {
      return [TextSpan(text: c.substring(startOffset, endOffset), style: resolvedStyle)];
    }
    final cuts = <int>{startOffset, endOffset};
    for (final h in pageHighlights) {
      if (h.end <= startOffset || h.start >= endOffset) continue;
      cuts.add(h.start.clamp(startOffset, endOffset));
      cuts.add(h.end.clamp(startOffset, endOffset));
    }
    final sorted = cuts.toList()..sort();
    final spans = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final segStart = sorted[i];
      final segEnd = sorted[i + 1];
      if (segEnd <= segStart) continue;

      var segStyle = resolvedStyle;
      // Layer highlights: paragraph tint is overlaid by active sentence / user highlight
      HighlightEntry? activeH;
      for (final h in pageHighlights) {
        if (h.start <= segStart && h.end >= segEnd) {
          activeH = h;
        }
      }
      if (activeH != null) {
        switch (activeH.styleType) {
          case HighlightStyleType.solid:
            segStyle = segStyle.copyWith(backgroundColor: activeH.color);
          case HighlightStyleType.underline:
            segStyle = segStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: activeH.color,
              decorationThickness: 2.2,
            );
          case HighlightStyleType.wavy:
            segStyle = segStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: activeH.color,
              decorationThickness: 2.0,
            );
          case HighlightStyleType.strikethrough:
            segStyle = segStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: activeH.color,
              decorationThickness: 2.0,
            );
          case HighlightStyleType.bold:
            segStyle = segStyle.copyWith(
              fontWeight: FontWeight.w900,
              backgroundColor: activeH.color.withValues(alpha: 0.22),
            );
          case HighlightStyleType.italic:
            segStyle = segStyle.copyWith(
              fontStyle: FontStyle.italic,
              backgroundColor: activeH.color.withValues(alpha: 0.22),
            );
        }
      }

      spans.add(TextSpan(text: c.substring(segStart, segEnd), style: segStyle));
    }
    return spans;
  }

  static const _highlightPalette = ChapterSelectionMenuBuilder.highlightPalette;

  EditableTextContextMenuBuilder _contextMenuBuilder(String fullText) {
    return AppContextMenu.builder(
      build: (ctx, editable, anchor) {
        final sel = editable.textEditingValue.selection;
        final hasSelection = sel.isValid &&
            !sel.isCollapsed &&
            sel.start >= 0 &&
            sel.end <= fullText.length &&
            sel.start < sel.end;
        final word = hasSelection
            ? fullText.substring(sel.start, sel.end).trim()
            : '';
        final sentence = hasSelection && word.isNotEmpty
            ? _sentenceAround(fullText, sel)
            : null;
        final showSelectionActions = hasSelection && word.isNotEmpty;
        final srcTitle = chapterTitle;
        final chapterOffset = pageStartOffset;
        final globalStart = hasSelection ? chapterOffset + sel.start : 0;
        final globalEnd = hasSelection ? chapterOffset + sel.end : 0;
        final overlappingHighlight = showSelectionActions
            ? highlights
                .where((h) => h.overlaps(globalStart, globalEnd))
                .firstOrNull
            : null;
        final hasOverlappingHighlight = overlappingHighlight != null;
        final eraseEnabled =
            showSelectionActions && hasOverlappingHighlight && onErase != null;

        return AppContextMenu(
          anchor: anchor,
          highlightColors: showSelectionActions ? _highlightPalette : const [],
          initialStyle:
              overlappingHighlight?.styleType ?? HighlightStyleType.solid,
          onHighlightWithStyle: showSelectionActions && onHighlight != null
              ? (color, style) => onHighlight!(
                  word,
                  color,
                  globalStart,
                  globalEnd,
                  styleType: style,
                )
              : null,
          quickActions: [
            AppContextMenuAction(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              onPressed: () {
                final text = editable.textEditingValue.text;
                final s = editable.textEditingValue.selection;
                if (s.isValid &&
                    !s.isCollapsed &&
                    s.start >= 0 &&
                    s.end <= text.length &&
                    s.start < s.end) {
                  final data = text.substring(s.start, s.end);
                  Clipboard.setData(ClipboardData(text: data));
                } else if (word.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: word));
                }
              },
            ),
            if (showSelectionActions && onAddNote != null)
              AppContextMenuAction(
                label: 'Note',
                icon: Icons.edit_note_rounded,
                onPressed: () => onAddNote!(word, sentence),
              ),
            if (showSelectionActions && onListen != null)
              AppContextMenuAction(
                label: 'Listen',
                icon: Icons.play_circle_outline_rounded,
                onPressed: () =>
                    onListen!(word, sentence, globalStart, globalEnd),
              ),
            if (showSelectionActions && onShare != null)
              AppContextMenuAction(
                label: 'Share',
                icon: Icons.ios_share_rounded,
                onPressed: () => onShare!(word),
              ),
          ],
          listActions: [
            if (showSelectionActions)
              AppContextMenuAction(
                label: 'Look up "$word"',
                icon: Icons.translate_rounded,
                onPressed: () => _showDefine(
                  ctx,
                  word,
                  sentence: sentence,
                  sourceTitle: srcTitle,
                ),
              ),
            if (showSelectionActions && onSetGlossaryTerm != null)
              AppContextMenuAction(
                label: 'Set as term…',
                icon: Icons.settings_suggest_outlined,
                onPressed: () => onSetGlossaryTerm!(word),
              ),
            if (eraseEnabled)
              AppContextMenuAction(
                label: 'Erase highlight',
                icon: Icons.format_color_reset_rounded,
                destructive: true,
                onPressed: () => onErase!(globalStart, globalEnd),
              ),
            if (showSelectionActions && onSearchWeb != null)
              AppContextMenuAction(
                label: 'Search the web for "$word"',
                icon: Icons.search_rounded,
                onPressed: () => onSearchWeb!(word),
              ),
            AppContextMenuAction(
              label: 'Select all',
              icon: Icons.select_all_rounded,
              onPressed: () =>
                  editable.selectAll(SelectionChangedCause.toolbar),
            ),
          ],
        );
      },
    );
  }

  String _sentenceAround(String fullText, TextSelection sel) {
    if (fullText.isEmpty || !sel.isValid || sel.isCollapsed || sel.start < 0) {
      return '';
    }
    final safeStart = sel.start.clamp(0, fullText.length);
    final safeEnd = sel.end.clamp(0, fullText.length);
    if (safeStart >= safeEnd) return '';
    const punctuation = '.!?\n';
    int start = safeStart;
    while (start > 0) {
      if (punctuation.contains(fullText[start - 1])) break;
      start--;
    }
    int end = safeEnd;
    while (end < fullText.length) {
      if (punctuation.contains(fullText[end])) break;
      end++;
    }
    if (end < fullText.length) end++;
    return fullText.substring(start, end).trim();
  }

  void _showDefine(
    BuildContext ctx,
    String word, {
    String? sentence,
    String? sourceTitle,
  }) {
    AppSheet.show(
      context: ctx,
      id: 'word_lookup',
      initialHeight: 0.7,
      child: WordLookupSheet(
        word: word,
        sourceSentence: sentence,
        sourceTitle: sourceTitle,
      ),
    );
  }
}

