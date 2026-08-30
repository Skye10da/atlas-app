import 'package:flutter/material.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_widget.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_image_widget.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

class ChapterSpanBuilder {
  const ChapterSpanBuilder();

  /// Matches quoted dialogue/text — straight double quotes and typographic
  /// (curly) double quotes.
  static final RegExp _quotePattern = RegExp('"[^"]*"|\u201C[^\u201D]*\u201D');

  /// Matches standalone markdown image references like `![alt](path)`
  static final RegExp _imagePattern = RegExp(r'!\[(.*?)\]\((.*?)\)');

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
          switch (h.styleType) {
            case HighlightStyleType.solid:
              segStyle = segStyle.copyWith(
                backgroundColor: h.color.withValues(alpha: 0.35),
              );
            case HighlightStyleType.underline:
              segStyle = segStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: h.color,
                decorationStyle: TextDecorationStyle.solid,
                decorationThickness: 2.0,
              );
            case HighlightStyleType.wavy:
              segStyle = segStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: h.color,
                decorationStyle: TextDecorationStyle.wavy,
                decorationThickness: 2.0,
              );
            case HighlightStyleType.strikethrough:
              segStyle = segStyle.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: h.color,
                decorationThickness: 2.0,
              );
            case HighlightStyleType.bold:
              segStyle = segStyle.copyWith(
                fontWeight: FontWeight.w900,
                backgroundColor: h.color.withValues(alpha: 0.22),
              );
            case HighlightStyleType.italic:
              segStyle = segStyle.copyWith(
                fontStyle: FontStyle.italic,
                backgroundColor: h.color.withValues(alpha: 0.22),
              );
          }
        }
      }

      if (extraStyle != null) segStyle = segStyle.merge(extraStyle);
      spans.add(
        TextSpan(text: content.substring(segStart, segEnd), style: segStyle),
      );
    }
    return spans;
  }

  /// Builds a segmented list of [InlineSpan]s interleaving prose text spans,
  /// inline [ReaderImageWidget] spans, and [BlockCardWidget] spans.
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
    String? bookDir,
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
      final proseText = content.substring(start, end);

      // Check for inline images within this prose slice
      final imgMatches = _imagePattern.allMatches(proseText).toList();
      if (imgMatches.isEmpty) {
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
      } else {
        var localCursor = 0;
        for (final m in imgMatches) {
          if (m.start > localCursor) {
            final segStart = start + localCursor;
            final segEnd = start + m.start;
            richSpans.addAll(
              buildQuoteAwareSpans(
                content,
                segStart,
                segEnd,
                textStyle,
                highlights: highlights,
                quoteRanges: quoteRanges,
              ),
            );
            renderMap.add((renderCursor, renderCursor + (segEnd - segStart), segStart));
            renderCursor += segEnd - segStart;
          }

          final alt = m.group(1);
          final src = m.group(2) ?? '';
          richSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SelectionContainer.disabled(
                child: ReaderImageWidget(
                  src: src,
                  alt: alt,
                  bookDir: bookDir,
                ),
              ),
            ),
          );
          localCursor = m.end;
        }

        if (localCursor < proseText.length) {
          final segStart = start + localCursor;
          final segEnd = end;
          richSpans.addAll(
            buildQuoteAwareSpans(
              content,
              segStart,
              segEnd,
              textStyle,
              highlights: highlights,
              quoteRanges: quoteRanges,
            ),
          );
          renderMap.add((renderCursor, renderCursor + (segEnd - segStart), segStart));
          renderCursor += segEnd - segStart;
        }
      }
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
