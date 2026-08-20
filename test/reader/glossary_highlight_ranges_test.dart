import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/presentation/utils/glossary_highlight_ranges.dart';

AtlasGlossaryEntry _entry(String term, List<String> replacements,
    {int activeIndex = 0}) {
  return AtlasGlossaryEntry(
    id: 'b1:$term',
    bookId: 'b1',
    term: term,
    replacements: replacements,
    activeIndex: activeIndex,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  const color = Color(0xFFC0C0C0);

  group('glossaryHighlightRanges', () {
    test('highlights each run of the active replacement', () {
      final ranges = glossaryHighlightRanges(
        chapterId: 'b1_ch0',
        content: 'A middle a middle b',
        entries: [_entry('中', const ['middle'])],
        color: color,
      );

      expect(ranges.map((h) => (h.start, h.end)),
          [(2, 8), (11, 17)]);
      expect(ranges.every((h) => h.chapterId == 'b1_ch0'), isTrue);
      expect(ranges.every((h) => h.colorValue == color.toARGB32()), isTrue);
    });

    test('uses the active index when several options exist', () {
      final ranges = glossaryHighlightRanges(
        chapterId: 'b1_ch0',
        content: 'x center y',
        entries: [
          _entry('中', const ['middle', 'center'], activeIndex: 1),
        ],
        color: color,
      );

      expect(ranges.single.text, 'center');
      expect(ranges.single.start, 2);
      expect(ranges.single.end, 8);
    });

    test('merges overlapping and duplicate matches into one range', () {
      final ranges = glossaryHighlightRanges(
        chapterId: 'b1_ch0',
        content: 'ababab',
        entries: [
          _entry('a', const ['abab']),
          _entry('b', const ['baba']),
        ],
        color: color,
      );

      // 'abab' matches at 0 and 'baba' overlaps at 1 — union to [0, 5).
      expect(ranges, hasLength(1));
      expect(ranges.single.start, 0);
      expect(ranges.single.end, 5);
    });

    test('returns no highlights when nothing matches', () {
      final ranges = glossaryHighlightRanges(
        chapterId: 'b1_ch0',
        content: 'nothing here',
        entries: [_entry('中', const ['middle'])],
        color: color,
      );

      expect(ranges, isEmpty);
    });

    test('skips entries with no usable replacement', () {
      final ranges = glossaryHighlightRanges(
        chapterId: 'b1_ch0',
        content: '中',
        entries: [
          _entry('中', const ['']),
          _entry('正', const []),
        ],
        color: color,
      );

      expect(ranges, isEmpty);
    });

    test('returns empty for empty content or glossary', () {
      expect(
        glossaryHighlightRanges(
          chapterId: 'b1_ch0',
          content: '',
          entries: [_entry('中', const ['middle'])],
          color: color,
        ),
        isEmpty,
      );
      expect(
        glossaryHighlightRanges(
          chapterId: 'b1_ch0',
          content: 'abc',
          entries: const [],
          color: color,
        ),
        isEmpty,
      );
    });
  });
}