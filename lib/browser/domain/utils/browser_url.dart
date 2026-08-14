/// Normalizes free-form address-bar input into a navigable URL.
///
/// Bare hosts get `https://`; anything that does not look like a URL (search
/// phrases, single words) falls back to a search-engine query.
String normalizeBrowserUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return url;
  if (url.startsWith('about:')) return url;
  if (_hasKnownScheme(url)) return url;
  if (!looksLikeBrowserUrl(url)) {
    // `host:port` (e.g. `localhost:8080`) is an address, not a search query.
    if (RegExp(r'^[^:/\s]+:\d+$').hasMatch(url)) {
      return 'https://$url';
    }
    return browserSearchUrl(url);
  }
  if (!url.contains('://')) {
    url = 'https://$url';
  }
  return url;
}

/// Non-http schemes that must be passed through untouched (they have no host
/// to prefix, so prepending `https://` would mangle them).
const Set<String> _kNonHttpSchemes = {
  'about',
  'mailto',
  'tel',
  'sms',
  'data',
  'javascript',
  'ftp',
  'file',
  'blob',
};

/// Whether [input] starts with a known scheme from [_kNonHttpSchemes].
bool _hasKnownScheme(String input) {
  final schemeEnd = input.indexOf(':');
  if (schemeEnd <= 1) return false;
  return _kNonHttpSchemes.contains(input.substring(0, schemeEnd).toLowerCase());
}

/// Builds a search-engine URL for free-form address-bar [query] text.
String browserSearchUrl(String query) {
  return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query.trim())}';
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

/// Whether [url] points at a PDF document, by extension. Browser taps on
/// `.pdf` files are intercepted into the download/import flow instead of an
/// in-page navigation.
bool looksLikePdfUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return path.toLowerCase().endsWith('.pdf');
}