import 'package:flutter/material.dart';

/// Formatting style applied to a text highlight or annotation.
enum HighlightStyleType {
  solid,
  underline,
  wavy,
  strikethrough,
  bold,
  italic;

  String get label => switch (this) {
    HighlightStyleType.solid => 'Solid',
    HighlightStyleType.underline => 'Underline',
    HighlightStyleType.wavy => 'Wavy',
    HighlightStyleType.strikethrough => 'Strike',
    HighlightStyleType.bold => 'Bold',
    HighlightStyleType.italic => 'Italic',
  };

  IconData get icon => switch (this) {
    HighlightStyleType.solid => Icons.format_color_fill_rounded,
    HighlightStyleType.underline => Icons.format_underlined_rounded,
    HighlightStyleType.wavy => Icons.waves_rounded,
    HighlightStyleType.strikethrough => Icons.format_strikethrough_rounded,
    HighlightStyleType.bold => Icons.format_bold_rounded,
    HighlightStyleType.italic => Icons.format_italic_rounded,
  };

  static HighlightStyleType fromName(String? name) {
    if (name == null) return HighlightStyleType.solid;
    return HighlightStyleType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => HighlightStyleType.solid,
    );
  }
}

/// A text highlight kept on a chapter or PDF page.
///
/// [start] and [end] are character offsets into the chapter/page plain-text
/// content. [bounds] (optional) stores the PDF bounding box [left, top, right, bottom]
/// for precise PDF marker canvas rendering and view positioning across app sessions.
class HighlightEntry {
  const HighlightEntry({
    required this.chapterId,
    required this.start,
    required this.end,
    required this.text,
    required this.colorValue,
    this.styleType = HighlightStyleType.solid,
    this.bounds,
    this.createdAt,
  });

  factory HighlightEntry.fromJson(Map<String, dynamic> json) {
    return HighlightEntry(
      chapterId: json['chapterId'] as String,
      start: json['start'] as int,
      end: json['end'] as int,
      text: json['text'] as String,
      colorValue: json['colorValue'] as int,
      styleType: HighlightStyleType.fromName(json['styleType'] as String?),
      bounds: (json['bounds'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  final String chapterId;

  /// Inclusive start offset into the chapter's content string.
  final int start;

  /// Exclusive end offset into the chapter's content string.
  final int end;
  final String text;
  final int colorValue;
  final HighlightStyleType styleType;

  /// Optional PDF bounding box: [left, top, right, bottom].
  final List<double>? bounds;
  final DateTime? createdAt;

  Color get color => Color(colorValue);

  /// True when this highlight's range overlaps [otherStart, otherEnd).
  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && otherEnd > start && otherEnd > otherStart;

  HighlightEntry copyWith({
    String? chapterId,
    int? start,
    int? end,
    String? text,
    int? colorValue,
    HighlightStyleType? styleType,
    List<double>? bounds,
    DateTime? createdAt,
  }) {
    return HighlightEntry(
      chapterId: chapterId ?? this.chapterId,
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
      colorValue: colorValue ?? this.colorValue,
      styleType: styleType ?? this.styleType,
      bounds: bounds ?? this.bounds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'start': start,
    'end': end,
    'text': text,
    'colorValue': colorValue,
    'styleType': styleType.name,
    if (bounds != null) 'bounds': bounds,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

/// A user-created note attached to a selected span of chapter or PDF text.
class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.chapterId,
    required this.text,
    required this.sentence,
    required this.createdAt,
    this.updatedAt,
    this.colorValue,
    this.tags = const [],
    this.styleType = HighlightStyleType.solid,
    this.highlightStart,
    this.highlightEnd,
  });

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      text: json['text'] as String,
      sentence: json['sentence'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      colorValue: json['colorValue'] as int?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      styleType: HighlightStyleType.fromName(json['styleType'] as String?),
      highlightStart: json['highlightStart'] as int?,
      highlightEnd: json['highlightEnd'] as int?,
    );
  }

  final String id;
  final String chapterId;
  final String text;
  final String sentence;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? colorValue;
  final List<String> tags;
  final HighlightStyleType styleType;
  final int? highlightStart;
  final int? highlightEnd;

  Color? get color => colorValue != null ? Color(colorValue!) : null;

  NoteEntry copyWith({
    String? id,
    String? chapterId,
    String? text,
    String? sentence,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorValue,
    List<String>? tags,
    HighlightStyleType? styleType,
    int? highlightStart,
    int? highlightEnd,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      text: text ?? this.text,
      sentence: sentence ?? this.sentence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: colorValue ?? this.colorValue,
      tags: tags ?? this.tags,
      styleType: styleType ?? this.styleType,
      highlightStart: highlightStart ?? this.highlightStart,
      highlightEnd: highlightEnd ?? this.highlightEnd,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterId': chapterId,
    'text': text,
    'sentence': sentence,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (colorValue != null) 'colorValue': colorValue,
    'tags': tags,
    'styleType': styleType.name,
    if (highlightStart != null) 'highlightStart': highlightStart,
    if (highlightEnd != null) 'highlightEnd': highlightEnd,
  };
}

/// Immutable state containing all active highlights and notes for a book.
class ReaderAnnotationsState {
  const ReaderAnnotationsState({
    this.highlights = const {},
    this.notes = const {},
  });

  final Map<String, List<HighlightEntry>> highlights;
  final Map<String, List<NoteEntry>> notes;

  int get totalHighlightsCount =>
      highlights.values.fold(0, (sum, list) => sum + list.length);

  int get totalNotesCount =>
      notes.values.fold(0, (sum, list) => sum + list.length);

  ReaderAnnotationsState copyWith({
    Map<String, List<HighlightEntry>>? highlights,
    Map<String, List<NoteEntry>>? notes,
  }) {
    return ReaderAnnotationsState(
      highlights: highlights ?? this.highlights,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderAnnotationsState &&
      other.highlights == highlights &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(highlights, notes);
}
