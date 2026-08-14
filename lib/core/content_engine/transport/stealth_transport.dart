import 'dart:math';

import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Default UA pool for sites with basic bot mitigation.
const defaultUserAgents = <String>[
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.4 Safari/605.1.15',
  'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0',
];

/// Wraps another transport with UA rotation and jittered request delays
/// (`permissions.json`'s `requestDelayMs`). The `sleep` seam lets tests
/// substitute a fake clock instead of waiting real time.
class StealthTransport implements Transport {
  StealthTransport({
    required this.inner,
    this.userAgents = defaultUserAgents,
    this.minDelay = const Duration(milliseconds: 800),
    this.maxDelay = const Duration(milliseconds: 2000),
    Random? random,
    Future<void> Function(Duration)? sleep,
  })  : _random = random ?? Random(),
        _sleep = sleep ?? Future<void>.delayed;

  final Transport inner;
  final List<String> userAgents;
  final Duration minDelay;
  final Duration maxDelay;
  final Random _random;
  final Future<void> Function(Duration) _sleep;

  Map<String, String> _decorate(Map<String, String>? headers) => {
        'User-Agent': userAgents[_random.nextInt(userAgents.length)],
        ...?headers,
      };

  Future<void> _throttle() async {
    final span = maxDelay - minDelay;
    final jitter = Duration(milliseconds: _random.nextInt(span.inMilliseconds));
    await _sleep(minDelay + jitter);
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    await _throttle();
    return inner.fetchHtml(url, headers: _decorate(headers));
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    await _throttle();
    return inner.fetchHtmlPost(url, headers: _decorate(headers), form: form);
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    await _throttle();
    return inner.fetchJson(url, headers: _decorate(headers));
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    await _throttle();
    return inner.fetchJsonPost(url, headers: _decorate(headers), jsonBody: jsonBody);
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    await _throttle();
    return inner.fetchBytes(url, headers: _decorate(headers));
  }
}
