import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';

class ChapterSelectionMenuBuilder {
  const ChapterSelectionMenuBuilder();

  static const List<AppContextMenuHighlightOption> highlightPalette = [
    AppContextMenuHighlightOption(color: Color(0xFFFFF176), label: 'Yellow'),
    AppContextMenuHighlightOption(color: Color(0xFFA5D6A7), label: 'Green'),
    AppContextMenuHighlightOption(color: Color(0xFF90CAF9), label: 'Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFF48FB1), label: 'Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFCE93D8), label: 'Purple'),
  ];

  /// Converts an offset from [SelectionHandler.getSelection] (relative to
  /// this view's rendered [RichText]) into the matching offset in
  /// the chapter's raw content.
  static int? contentOffsetFromRenderOffset(
    int renderOffset,
    List<(int, int, int)>? renderContentMap,
  ) {
    if (renderOffset < 0) return null;
    if (renderContentMap == null) return renderOffset;
    for (final (renderStart, renderEnd, contentStart) in renderContentMap) {
      if (renderOffset < renderStart) return contentStart;
      if (renderOffset <= renderEnd) {
        return contentStart + (renderOffset - renderStart);
      }
    }
    if (renderContentMap.isEmpty) return 0;
    final (renderStart, renderEnd, contentStart) = renderContentMap.last;
    return contentStart + (renderEnd - renderStart);
  }

  /// Extracts the complete sentence encompassing the given text selection.
  static String sentenceAround(String fullText, TextSelection sel) {
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

  Widget buildContextMenu({
    required BuildContext context,
    required SelectableRegionState selectableRegionState,
    required String content,
    required String? bookId,
    required String? chapterId,
    required String? chapterTitle,
    required List<HighlightEntry> highlights,
    required List<(int, int, int)>? renderContentMap,
    Selectable? selectable,
    void Function(String text, Color color, int start, int end)? onHighlight,
    void Function(String text, String? sentence)? onAddNote,
    void Function(String text)? onShare,
    void Function(String text)? onSearchWeb,
    void Function(String text, String? sentence, int start, int end)? onListen,
    void Function(int start, int end)? onErase,
  }) {
    final range = selectable?.getSelection();
    final globalStart = range != null
        ? contentOffsetFromRenderOffset(range.startOffset, renderContentMap)
        : null;
    final globalEnd = range != null
        ? contentOffsetFromRenderOffset(range.endOffset, renderContentMap)
        : null;
    final hasOffsets = globalStart != null && globalEnd != null;
    final word = hasOffsets
        ? content.substring(globalStart, globalEnd).trim()
        : '';
    final showSelectionActions = word.isNotEmpty;

    final sentence = hasOffsets
        ? sentenceAround(
            content,
            TextSelection(baseOffset: globalStart, extentOffset: globalEnd),
          )
        : null;
    final hasOverlappingHighlight = hasOffsets &&
        highlights.any((h) => h.overlaps(globalStart, globalEnd));
    final eraseEnabled =
        hasOffsets && hasOverlappingHighlight && onErase != null;

    return AppContextMenu(
      anchor: selectableRegionState.contextMenuAnchors.primaryAnchor,
      highlightColors: hasOffsets ? highlightPalette : const [],
      onHighlightSelected: hasOffsets && onHighlight != null
          ? (color) => onHighlight(word, color, globalStart, globalEnd)
          : null,
      quickActions: [
        AppContextMenuAction(
          label: 'Copy',
          icon: Icons.content_copy_rounded,
          onPressed: () => Clipboard.setData(ClipboardData(text: word)),
        ),
        if (showSelectionActions && onAddNote != null)
          AppContextMenuAction(
            label: 'Note',
            icon: Icons.edit_note_rounded,
            onPressed: () => onAddNote(word, sentence),
          ),
        if (hasOffsets && onListen != null)
          AppContextMenuAction(
            label: 'Listen',
            icon: Icons.play_circle_outline_rounded,
            onPressed: () =>
                onListen(word, sentence, globalStart, globalEnd),
          ),
        if (showSelectionActions && onShare != null)
          AppContextMenuAction(
            label: 'Share',
            icon: Icons.ios_share_rounded,
            onPressed: () => onShare(word),
          ),
      ],
      listActions: [
        if (showSelectionActions)
          AppContextMenuAction(
            label: 'Look up "$word"',
            icon: Icons.translate_rounded,
            onPressed: () {
              AppSheet.show(
                context: context,
                id: 'word_lookup',
                initialHeight: 0.7,
                child: WordLookupSheet(
                  word: word,
                  sourceSentence: sentence,
                  sourceTitle: chapterTitle,
                ),
              );
            },
          ),
        if (showSelectionActions && bookId != null)
          AppContextMenuAction(
            label: 'Set as term…',
            icon: Icons.settings_suggest_outlined,
            onPressed: () {
              AppSheet.show(
                context: context,
                id: 'glossary_term',
                initialHeight: 0.6,
                child: GlossaryTermSheet(bookId: bookId, term: word),
              );
            },
          ),
        if (eraseEnabled)
          AppContextMenuAction(
            label: 'Erase highlight',
            icon: Icons.format_color_reset_rounded,
            destructive: true,
            onPressed: () => onErase(globalStart, globalEnd),
          ),
        if (showSelectionActions && onSearchWeb != null)
          AppContextMenuAction(
            label: 'Search the web for "$word"',
            icon: Icons.search_rounded,
            onPressed: () => onSearchWeb(word),
          ),
        AppContextMenuAction(
          label: 'Select all',
          icon: Icons.select_all_rounded,
          onPressed: () =>
              selectableRegionState.selectAll(SelectionChangedCause.toolbar),
        ),
      ],
    );
  }
}
