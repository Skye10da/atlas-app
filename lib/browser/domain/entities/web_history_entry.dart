/// A single visit recorded by the in-app browser.
class WebHistoryEntry {
  const WebHistoryEntry({
    required this.id,
    required this.url,
    this.title,
    required this.visitedAt,
  });

  final String id;
  final String url;
  final String? title;
  final DateTime visitedAt;

  String get displayTitle {
    final trimmed = title?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final host = Uri.tryParse(url)?.host;
    if (host != null && host.isNotEmpty) return host;
    return url;
  }
}
