/// Abstraction over network access so templates stay transport-agnostic.
///
/// Implementations: [HttpTransport], [StealthTransport], [CachedTransport],
/// [OfflineTransport]. A plugin selects one via the `transport` key in its
/// manifest, resolved by `TransportRegistry`.
abstract interface class Transport {
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers});

  /// Sends an `application/x-www-form-urlencoded` POST and returns the body.
  /// Used by sites whose data lives behind a form action instead of a plain
  /// GET — e.g. the WordPress Madara manga/novel theme's chapter archive,
  /// which POSTs `action=manga_get_chapters&manga=<id>` to `admin-ajax.php`.
  /// The response may be HTML directly or JSON wrapping an HTML fragment; the
  /// template resolves that with its `responseField` config.
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  });

  /// Fetches and decodes a JSON response of any shape (map, list, scalar).
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers});

  /// Sends an `application/json` POST (body encoded from [jsonBody]) and
  /// returns the decoded JSON response. Used by API-driven sites that refuse
  /// form-encoded bodies — e.g. WTR-LAB's `/api/search` and `/api/reader/get`
  /// endpoints, which require a raw JSON payload.
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  });

  /// Fetches raw bytes (images, fonts). Defaults to [fetchHtml]'s transport
  /// only where supported; overridden by HTTP-backed transports.
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers});
}

class TransportException implements Exception {
  const TransportException(
    this.message, {
    this.cause,
    this.sessionExpired = false,
    this.botChallenge = false,
  });

  final String message;
  final Object? cause;

  /// True when the failure is an auth/session wall (HTTP 401/403 that is not
  /// Cloudflare's bot check) rather than a generic network/HTTP error — the
  /// signal that the saved webview session expired and a re-verify pass (see
  /// `SessionRefreshService`) would help.
  final bool sessionExpired;

  /// True when the failure is a Cloudflare-style bot challenge rather than a
  /// generic HTTP/session error. Distinct from [sessionExpired] so the
  /// transport can decide whether a live-webview re-verify pass (which runs
  /// the real JS challenge and captures fresh cookies) could solve it.
  final bool botChallenge;

  @override
  String toString() => 'TransportException: $message';
}
