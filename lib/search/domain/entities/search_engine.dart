enum SearchEngine {
  google(
    id: 'google',
    label: 'Google',
    searchUrlTemplate: 'https://www.google.com/search?q={q}',
  ),
  bing(
    id: 'bing',
    label: 'Bing',
    searchUrlTemplate: 'https://www.bing.com/search?q={q}',
  ),
  duckDuckGo(
    id: 'duckduckgo',
    label: 'DuckDuckGo',
    searchUrlTemplate: 'https://duckduckgo.com/?q={q}',
  ),
  brave(
    id: 'brave',
    label: 'Brave',
    searchUrlTemplate: 'https://search.brave.com/search?q={q}',
  );

  const SearchEngine({
    required this.id,
    required this.label,
    required this.searchUrlTemplate,
  });

  final String id;
  final String label;
  final String searchUrlTemplate;

  String buildUrl(String query) {
    return searchUrlTemplate.replaceAll(
      '{q}',
      Uri.encodeQueryComponent(query.trim()),
    );
  }

  static SearchEngine fromId(String? id) {
    if (id == null) return SearchEngine.google;
    return SearchEngine.values.firstWhere(
      (e) => e.id == id,
      orElse: () => SearchEngine.google,
    );
  }
}
