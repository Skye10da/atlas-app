import 'package:flutter/material.dart';

import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';

/// Locates every run of glossary-replacement text inside [content] and returns
/// them as non-overlapping [HighlightEntry]s so the reader can tint replaced
/// terms like a user highlight.
///
/// [content] is expected to already have the glossary applied — the active
/// replacement text is what gets matched. Overlapping or repeated matches are
/// merged into a single range so span builders never emit duplicate text.
List<HighlightEntry> glossaryHighlightRanges({
  required String chapterId,
  required String content,
  required List<AtlasGlossaryEntry> entries,
  required Color color,
}) {
  if (entries.isEmpty || content.isEmpty) return const [];

  final raw = <(int, int)>[];
  for (final entry in entries) {
    final replacement = entry.activeReplacement;
    if (replacement == null || replacement.isEmpty) continue;
    var cursor = 0;
    while (cursor < content.length) {
      final start = content.indexOf(replacement, cursor);
      if (start < 0) break;
      raw.add((start, start + replacement.length));
      cursor = start + replacement.length;
    }
  }
  if (raw.isEmpty) return const [];

  raw.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  final merged = <(int, int)>[raw.first];
  for (final range in raw.skip(1)) {
    final last = merged.last;
    if (range.$1 <= last.$2) {
      merged[merged.length - 1] = (
        last.$1,
        range.$2 > last.$2 ? range.$2 : last.$2,
      );
    } else {
      merged.add(range);
    }
  }

  return [
    for (final range in merged)
      HighlightEntry(
        chapterId: chapterId,
        start: range.$1,
        end: range.$2,
        text: content.substring(range.$1, range.$2),
        colorValue: color.toARGB32(),
      ),
  ];
}
