/// A page the user chose to keep in the browser's Favorites.
class BrowserBookmark {
  const BrowserBookmark({
    required this.id,
    required this.url,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String url;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return Uri.tryParse(url)?.host ?? url;
  }
}