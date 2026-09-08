import 'dart:math' as math;
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
    AppContextMenuHighlightOption(color: Color(0xFFFFD54F), label: 'Sunset Gold'),
    AppContextMenuHighlightOption(color: Color(0xFF69F0AE), label: 'Emerald Mint'),
    AppContextMenuHighlightOption(color: Color(0xFF40C4FF), label: 'Sky Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFFF8A80), label: 'Coral Orange'),
    AppContextMenuHighlightOption(color: Color(0xFFFF80AB), label: 'Rose Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFB388FF), label: 'Electric Violet'),
    AppContextMenuHighlightOption(color: Color(0xFFEEFF41), label: 'Neon Lime'),
    AppContextMenuHighlightOption(color: Color(0xFFFFA726), label: 'Warm Amber'),
    AppContextMenuHighlightOption(color: Color(0xFF90A4AE), label: 'Slate Graphite'),
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
    RenderParagraph? renderParagraph,
    void Function(
      String text,
      Color color,
      int start,
      int end, {
      HighlightStyleType styleType,
    })?
    onHighlight,
    void Function(String text, String? sentence)? onAddNote,
    void Function(String text)? onShare,
    void Function(String text)? onSearchWeb,
    void Function(String text, String? sentence, int start, int end)? onListen,
    void Function(int start, int end)? onErase,
  }) {
    int? globalStart;
    int? globalEnd;

    final range = selectable?.getSelection();
    if (range != null) {
      globalStart = contentOffsetFromRenderOffset(
        range.startOffset,
        renderContentMap,
      );
      globalEnd = contentOffsetFromRenderOffset(
        range.endOffset,
        renderContentMap,
      );
    } else if (renderParagraph != null &&
        renderParagraph.hasSize &&
        renderParagraph.attached) {
      // ignore: invalid_use_of_visible_for_testing_member
      final selections = renderParagraph.selections;
      if (selections.isNotEmpty && !selections.first.isCollapsed) {
        final sel = selections.first;
        final startRender = math.min(sel.baseOffset, sel.extentOffset);
        final endRender = math.max(sel.baseOffset, sel.extentOffset);
        globalStart = contentOffsetFromRenderOffset(
          startRender,
          renderContentMap,
        );
        globalEnd = contentOffsetFromRenderOffset(
          endRender,
          renderContentMap,
        );
      } else {
        try {
          final anchors = selectableRegionState.contextMenuAnchors;
          final p1 = renderParagraph.globalToLocal(anchors.primaryAnchor);
          final pos1 = renderParagraph.getPositionForOffset(p1).offset;
          final wordRange =
              renderParagraph.getWordBoundary(TextPosition(offset: pos1));
          if (wordRange.isValid && !wordRange.isCollapsed) {
            globalStart = contentOffsetFromRenderOffset(
              wordRange.start,
              renderContentMap,
            );
            globalEnd = contentOffsetFromRenderOffset(
              wordRange.end,
              renderContentMap,
            );
          }
        } catch (_) {}
      }
    }

    final hasOffsets = globalStart != null &&
        globalEnd != null &&
        globalStart >= 0 &&
        globalEnd <= content.length &&
        globalStart < globalEnd;
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
    final overlappingHighlight = hasOffsets
        ? highlights.where((h) => h.overlaps(globalStart!, globalEnd!)).firstOrNull
        : null;
    final hasOverlappingHighlight = overlappingHighlight != null;
    final eraseEnabled =
        hasOffsets && hasOverlappingHighlight && onErase != null;

    return AppContextMenu(
      anchor: selectableRegionState.contextMenuAnchors.primaryAnchor,
      highlightColors: hasOffsets ? highlightPalette : const [],
      initialStyle: overlappingHighlight?.styleType ?? HighlightStyleType.solid,
      onHighlightWithStyle: hasOffsets && onHighlight != null
          ? (color, style) => onHighlight(
              word,
              color,
              globalStart!,
              globalEnd!,
              styleType: style,
            )
          : null,
      quickActions: [
        AppContextMenuAction(
          label: 'Copy',
          icon: Icons.content_copy_rounded,
          onPressed: () {
            if (word.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: word));
            }
          },
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
                onListen(word, sentence, globalStart!, globalEnd!),
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
            onPressed: () => onErase(globalStart!, globalEnd!),
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
