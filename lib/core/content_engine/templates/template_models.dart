/// Value types produced by template implementations. Kept free of transport /
/// selector dependencies so both `templates/` and `selectors/` can build on
/// them without cycles.
class SearchResult {
  const SearchResult({
    required this.title,
    required this.url,
    this.author,
    this.coverUrl,
    this.description,
    this.language,
  });

  final String title;
  final String url;
  final String? author;
  final String? coverUrl;
  final String? description;
  final String? language;
}

class ChapterRef {
  const ChapterRef({required this.title, required this.url, this.publishedAt});

  final String title;
  final String url;
  final DateTime? publishedAt;
}

/// Best-effort novel metadata extracted by a template's `metadata` method,
/// bridged into the existing `NovelModel` by `PluginSource`.
class NovelMetadata {
  const NovelMetadata({
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.language,
    this.chapterCount = 0,
    this.sourceId,
    this.genres = const [],
    this.status,
    this.rating,
    this.lastUpdated,
  });

  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final String? language;
  final int chapterCount;
  final String? sourceId;
  final List<String> genres;
  final String? status;
  final double? rating;
  final DateTime? lastUpdated;
}
