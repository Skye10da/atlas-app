import 'package:flutter/material.dart';

/// A text highlight kept on a chapter, in-memory only while the reader is open.
///
/// [start] and [end] are character offsets into the chapter's plain-text
/// content, matching the selection offsets the context menu builder resolves
/// from `EditableTextState`. [colorValue] is stored instead of a [Color] so the
/// entity stays pure/UI-free and remains comparable/equatable without Flutter.
class HighlightEntry {
  const HighlightEntry({
    required this.chapterId,
    required this.start,
    required this.end,
    required this.text,
    required this.colorValue,
  });

  final String chapterId;

  /// Inclusive start offset into the chapter's content string.
  final int start;

  /// Exclusive end offset into the chapter's content string.
  final int end;
  final String text;
  final int colorValue;

  Color get color => Color(colorValue);

  /// True when this highlight's range overlaps [otherStart, otherEnd).
  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && otherEnd > start && otherEnd > otherStart;
}

/// A user-created note attached to a selected span of chapter text.
class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.chapterId,
    required this.text,
    required this.sentence,
    required this.createdAt,
  });

  final String id;
  final String chapterId;
  final String text;
  final String sentence;
  final DateTime createdAt;
}
