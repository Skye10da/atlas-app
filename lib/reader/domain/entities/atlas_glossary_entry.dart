/// A user-defined per-novel glossary entry: the original term as it appears in
/// the chapter text plus one or more replacement options the reader may display
/// in its place.
///
/// The Atlas glossary is stored locally (per `bookId`) and is applied at reader
/// render time, so the on-disk chapter text is never modified.
class AtlasGlossaryEntry {
  const AtlasGlossaryEntry({
    required this.id,
    required this.bookId,
    required this.term,
    required this.replacements,
    this.activeIndex = 0,
    required this.createdAt,
  });

  factory AtlasGlossaryEntry.fromJson(Map<String, dynamic> json) {
    return AtlasGlossaryEntry(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      replacements: [
        for (final r in (json['replacements'] as List? ?? const []))
          if (r is String) r,
      ],
      activeIndex: (json['activeIndex'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Stable identifier within the book (e.g. `<bookId>:<term>`), used to
  /// update or remove the entry later.
  final String id;

  final String bookId;

  /// The source text in the chapter that gets replaced (e.g. `中`).
  final String term;

  /// Every replacement the user has defined, in the order they were added.
  final List<String> replacements;

  /// Index into [replacements] of the one currently applied. Never
  /// out-of-range: [activeReplacement] returns `null` instead of throwing.
  final int activeIndex;

  final DateTime createdAt;

  /// The replacement currently displayed for this term, or `null` when the
  /// entry has no usable option.
  String? get activeReplacement {
    if (activeIndex < 0 || activeIndex >= replacements.length) return null;
    final value = replacements[activeIndex].trim();
    return value.isEmpty ? null : value;
  }

  AtlasGlossaryEntry copyWith({
    String? id,
    String? bookId,
    String? term,
    List<String>? replacements,
    int? activeIndex,
    DateTime? createdAt,
  }) {
    return AtlasGlossaryEntry(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      term: term ?? this.term,
      replacements: replacements ?? this.replacements,
      activeIndex: activeIndex ?? this.activeIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'term': term,
        'replacements': replacements,
        'activeIndex': activeIndex,
        'createdAt': createdAt.toIso8601String(),
      };
}