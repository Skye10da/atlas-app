class ChapterModel {
  const ChapterModel({
    required this.id,
    required this.title,
    required this.index,
    this.content,
    this.contentUrl,
    this.wordCount,
    this.publishedAt,
  });

  final String id;
  final String title;
  final int index;
  final String? content;
  final String? contentUrl;
  final int? wordCount;
  final DateTime? publishedAt;
}
