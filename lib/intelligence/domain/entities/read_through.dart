/// Represents a distinct read-through session for a novel in Atlas.
///
/// Enables complete memory isolation between multiple reading runs of the same book
/// (e.g. initial read vs. re-read years later), ensuring that story memory, entity
/// confidence, and spoiler boundaries from one read-through never leak into another.
class ReadThrough {
  const ReadThrough({
    required this.id,
    required this.bookId,
    required this.name,
    this.currentChapter = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReadThrough.fromJson(Map<String, dynamic> json) {
    return ReadThrough(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      name: json['name'] as String? ?? 'Primary Read',
      currentChapter: (json['currentChapter'] as num?)?.toInt() ?? 1,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Identifier of this read-through. The initial/default read-through uses `'default'`.
  final String id;

  /// Identifier of the novel/book.
  final String bookId;

  /// User-facing label (e.g. "Primary Read", "Re-read 2026", "Spoiler-Free Revisit").
  final String name;

  /// Current chapter progress within this specific read-through.
  final int currentChapter;

  /// Whether this is currently the active read-through for the reader.
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  ReadThrough copyWith({
    String? id,
    String? bookId,
    String? name,
    int? currentChapter,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReadThrough(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      currentChapter: currentChapter ?? this.currentChapter,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'name': name,
    'currentChapter': currentChapter,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
