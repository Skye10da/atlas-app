class ChapterModel {
  const ChapterModel({
    required this.id,
    required this.title,
    required this.index,
    this.content,
    this.contentUrl,
    this.wordCount,
    this.publishedAt,
    this.language,
  });

  final String id;
  final String title;
  final int index;
  final String? content;
  final String? contentUrl;
  final int? wordCount;
  final DateTime? publishedAt;

  /// Target language override for this fetch, when the caller wants a
  /// translation different from the plugin manifest default. Read by
  /// `PluginSource` to build the template context; ignored by non-plugin
  /// sources.
  final String? language;
}
