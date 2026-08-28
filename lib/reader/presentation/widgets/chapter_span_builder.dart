import 'package:flutter/material.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_widget.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

class ChapterSpanBuilder {
  const ChapterSpanBuilder();

  /// Matches quoted dialogue/text — straight double quotes and typographic
  /// (curly) double quotes.
  static final RegExp _quotePattern = RegExp('"[^"]*"|\u201C[^\u201D]*\u201D');

  /// Quoted-text ranges (start, end) within [content].
  List<(int, int)> findQuoteRanges(String content) {
    return [
      for (final m in _quotePattern.allMatches(content)) (m.start, m.end),
    ];
  }

  /// Returns [content]'s `[start, end)` range as TextSpans, italicizing any
  /// portion that falls inside a quoted span and laying a user-highlight
  /// background over any portion inside a stored [HighlightEntry].
  List<TextSpan> buildQuoteAwareSpans(
    String content,
    int start,
    int end,
    TextStyle style, {
    TextStyle? extraStyle,
    List<HighlightEntry> highlights = const [],
    List<(int, int)>? quoteRanges,
  }) {
    if (start >= end) return const [];
    final spans = <TextSpan>[];
    final quoteStyle = style.copyWith(fontStyle: FontStyle.italic);
    final quotes = quoteRanges ?? findQuoteRanges(content);

    final cuts = <int>{start, end};
    for (final range in quotes) {
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
      final inQuote = quotes.any((r) => r.$1 <= segStart && r.$2 >= segEnd);
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
      spans.add(
        TextSpan(text: content.substring(segStart, segEnd), style: segStyle),
      );
    }
    return spans;
  }

  /// Builds a segmented list of [InlineSpan]s interleaving prose text spans and
  /// inline [BlockCardWidget] spans, together with the render-to-content map.
  (List<InlineSpan>, List<(int, int, int)>) buildSegmentedSpans({
    required List<ContentSpan> spans,
    required String content,
    required TextStyle textStyle,
    required ReadingColors readingColors,
    required double fontSize,
    required double lineHeight,
    required List<HighlightEntry> highlights,
    TextStyle? dropCapStyle,
    bool applyDropCap = false,
  }) {
    final paragraphGapHeight = fontSize * lineHeight * 0.6;
    var cursor = 0;
    var dropCapUsed = false;
    var renderCursor = 0;
    final richSpans = <InlineSpan>[];
    final renderMap = <(int, int, int)>[];
    final quoteRanges = findQuoteRanges(content);

    void addProseSpans(int start, int end) {
      if (end <= start) return;
      final useDropCap = applyDropCap && !dropCapUsed && end > start;
      if (useDropCap) dropCapUsed = true;
      final bodyStart = start + (useDropCap ? 1 : 0);

      if (useDropCap) {
        richSpans.add(
          TextSpan(
            text: content.substring(start, start + 1),
            style: dropCapStyle,
          ),
        );
      }
      richSpans.addAll(
        buildQuoteAwareSpans(
          content,
          bodyStart,
          end,
          textStyle,
          highlights: highlights,
          quoteRanges: quoteRanges,
        ),
      );
      renderMap.add((renderCursor, renderCursor + (end - start), start));
      renderCursor += end - start;
    }

    for (final span in spans) {
      if (!span.isCard) {
        final prose = span.prose ?? '';
        if (prose.isEmpty) continue;
        final idx = content.indexOf(prose, cursor);
        final start = idx >= 0 ? idx : cursor;
        final end = (start + prose.length).clamp(start, content.length).toInt();
        cursor = end;
        addProseSpans(start, end);
        continue;
      }

      final card = span.card!;
      final idx = content.indexOf(card.rawText, cursor);
      if (idx >= 0) cursor = idx + card.rawText.length;

      if (richSpans.isNotEmpty) {
        richSpans.add(
          TextSpan(
            text: '\n',
            style: textStyle.copyWith(
              height: paragraphGapHeight / fontSize,
            ),
          ),
        );
        renderCursor += 1;
      }

      richSpans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SelectionContainer.disabled(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: BlockCardWidget(card: card, colors: readingColors),
            ),
          ),
        ),
      );

      richSpans.add(
        TextSpan(
          text: '\n',
          style: textStyle.copyWith(
            height: paragraphGapHeight / fontSize,
          ),
        ),
      );
      renderCursor += 1;
    }

    return (richSpans, renderMap);
  }
}
