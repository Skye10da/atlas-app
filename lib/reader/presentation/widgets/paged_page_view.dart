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
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';

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
    required this.isFirstPageOfChapter,
    required this.isLastPageOfChapter,
    required this.textStyle,
    this.fontFamily,
    required this.textAlignment,
    required this.marginPreset,
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

  final bool isFirstPageOfChapter;
  final bool isLastPageOfChapter;
  final TextStyle textStyle;
  final String? fontFamily;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final ReadingViewTheme vt;
  final bool showHeaders;
  final ChapterStyle? chapterStyle;
  final void Function(String text, Color color, int start, int end)?
  onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)?
  onListen;
  final void Function(int start, int end)? onErase;

  /// Called with the selected text so the host can define a glossary term for
  /// it. Omit to hide the "Set as term…" action.
  final ValueChanged<String>? onSetGlossaryTerm;

  EdgeInsets get _padding => switch (marginPreset) {
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
              child: _buildText(resolvedStyle, cs),
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

  Widget _buildText(TextStyle resolvedStyle, ChapterStyle? cs) {
    final c = content;
    final contextMenu = _contextMenuBuilder(c);
    final pageHighlights = _pageHighlights(c);

    final spans = _pageSpans(c, resolvedStyle, pageHighlights);

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
      );
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlignment.flutterTextAlign,
      contextMenuBuilder: contextMenu,
    );
  }

  /// Highlights whose chapter-global range intersects this page's slice,
  /// translated into page-local coordinates (may be empty).
  List<HighlightEntry> _pageHighlights(String pageContent) {
    if (chapterId == null || pageStartOffset >= pageContent.length) {
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
        ),
      );
    }
    return out;
  }

  /// Plain body spans (drop-cap first char excluded) with highlight layering.
  List<TextSpan> _restSpans(
    String c,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    final spans = <TextSpan>[];
    var cursor = 1;
    for (final h in pageHighlights) {
      if (h.end <= 1) continue;
      final start = h.start < 1 ? 1 : h.start;
      final end = h.end;
      if (start > cursor) {
        spans.add(
          TextSpan(text: c.substring(cursor, start), style: resolvedStyle),
        );
      }
      spans.add(
        TextSpan(
          text: c.substring(start, end > c.length ? c.length : end),
          style: resolvedStyle.copyWith(
            backgroundColor: h.color.withValues(alpha: 0.30),
          ),
        ),
      );
      cursor = end > c.length ? c.length : end;
    }
    if (cursor < c.length) {
      spans.add(TextSpan(text: c.substring(cursor), style: resolvedStyle));
    }
    return spans;
  }

  /// Whole-page spans with highlight layering (first char kept plain).
  List<TextSpan> _pageSpans(
    String c,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    if (pageHighlights.isEmpty) {
      return [TextSpan(text: c, style: resolvedStyle)];
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final h in pageHighlights) {
      if (h.start > cursor) {
        spans.add(
          TextSpan(text: c.substring(cursor, h.start), style: resolvedStyle),
        );
      }
      spans.add(
        TextSpan(
          text: c.substring(h.start, h.end > c.length ? c.length : h.end),
          style: resolvedStyle.copyWith(
            backgroundColor: h.color.withValues(alpha: 0.30),
          ),
        ),
      );
      cursor = h.end > c.length ? c.length : h.end;
    }
    if (cursor < c.length) {
      spans.add(TextSpan(text: c.substring(cursor), style: resolvedStyle));
    }
    return spans;
  }

  static const _highlightPalette = [
    AppContextMenuHighlightOption(color: Color(0xFFFFF176), label: 'Yellow'),
    AppContextMenuHighlightOption(color: Color(0xFFA5D6A7), label: 'Green'),
    AppContextMenuHighlightOption(color: Color(0xFF90CAF9), label: 'Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFF48FB1), label: 'Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFCE93D8), label: 'Purple'),
  ];

  EditableTextContextMenuBuilder _contextMenuBuilder(String fullText) {
    return AppContextMenu.builder(
      build: (ctx, editable, anchor) {
        final sel = editable.textEditingValue.selection;
        final hasSelection = sel.isValid && !sel.isCollapsed;
        final word = hasSelection
            ? fullText.substring(sel.start, sel.end).trim()
            : '';
        final sentence = hasSelection && word.isNotEmpty
            ? _sentenceAround(fullText, sel)
            : null;
        final showSelectionActions = hasSelection && word.isNotEmpty;
        final srcTitle = chapterTitle;
        final chapterOffset = pageStartOffset;
        final globalStart = chapterOffset + sel.start;
        final globalEnd = chapterOffset + sel.end;
        final hasOverlappingHighlight = highlights.any(
          (h) => h.overlaps(globalStart, globalEnd),
        );
        final eraseEnabled =
            showSelectionActions && hasOverlappingHighlight && onErase != null;

        return AppContextMenu(
          anchor: anchor,
          highlightColors: showSelectionActions ? _highlightPalette : const [],
          onHighlightSelected: showSelectionActions && onHighlight != null
              ? (color) => onHighlight!(word, color, globalStart, globalEnd)
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
