/// Normalizes free-form address-bar input into a navigable URL.
///
/// Phase 0 behavior: ensure a scheme. Later phases add search-engine fallback
/// for non-URL text.
String normalizeBrowserUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return url;
  if (url.startsWith('about:')) return url;
  final noScheme = !url.contains('://');
  if (noScheme) {
    url = 'https://$url';
  }
  return url;
}

/// Whether [input] looks like a URL we should navigate to (vs a search query).
bool looksLikeBrowserUrl(String input) {
  final url = input.trim();
  if (url.isEmpty) return false;
  if (url.contains('://')) return true;
  if (url.startsWith('about:')) return true;
  return url.contains('.') && !url.contains(' ');
}

/// Whether [url] points at an EPUB document, by extension. Browser taps on
/// `.epub` files are intercepted into the library import flow instead of a
/// file download.
bool looksLikeEpubUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return path.toLowerCase().endsWith('.epub');
}