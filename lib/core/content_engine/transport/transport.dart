/// Abstraction over network access so templates stay transport-agnostic.
///
/// Implementations: [HttpTransport], [StealthTransport], [CachedTransport],
/// [OfflineTransport]. A plugin selects one via the `transport` key in its
/// manifest, resolved by `TransportRegistry`.
abstract interface class Transport {
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers});

  /// Fetches and decodes a JSON response of any shape (map, list, scalar).
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers});

  /// Fetches raw bytes (images, fonts). Defaults to [fetchHtml]'s transport
  /// only where supported; overridden by HTTP-backed transports.
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers});
}

class TransportException implements Exception {
  const TransportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'TransportException: $message';
}
