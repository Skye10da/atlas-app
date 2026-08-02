import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/cached_transport.dart';
import 'package:atlas_app/core/content_engine/transport/offline_transport.dart';
import 'package:atlas_app/core/content_engine/transport/stealth_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

class _CountingTransport implements Transport {
  int htmlCalls = 0;
  int jsonCalls = 0;
  final List<Map<String, String>?> seenHeaders = [];

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    htmlCalls++;
    seenHeaders.add(headers);
    return '<html>ok</html>';
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonCalls++;
    seenHeaders.add(headers);
    return {'ok': true};
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    seenHeaders.add(headers);
    return [1, 2, 3];
  }
}

void main() {
  group('CachedTransport', () {
    test('serves a repeat fetch from cache without calling the inner transport',
        () async {
      final inner = _CountingTransport();
      final cached = CachedTransport(inner: inner);
      final uri = Uri.parse('https://example.com/a');

      await cached.fetchHtml(uri);
      await cached.fetchHtml(uri);
      await cached.fetchHtml(uri);

      expect(inner.htmlCalls, 1);
    });

    test('distinguishes cache entries by URL', () async {
      final inner = _CountingTransport();
      final cached = CachedTransport(inner: inner);

      await cached.fetchHtml(Uri.parse('https://example.com/a'));
      await cached.fetchHtml(Uri.parse('https://example.com/b'));

      expect(inner.htmlCalls, 2);
    });

    test('caches JSON separately from HTML', () async {
      final inner = _CountingTransport();
      final cached = CachedTransport(inner: inner);
      final uri = Uri.parse('https://example.com/data');

      await cached.fetchJson(uri);
      await cached.fetchJson(uri);

      expect(inner.jsonCalls, 1);
      expect(inner.htmlCalls, 0);
    });
  });

  group('StealthTransport', () {
    test('adds a User-Agent from the configured pool', () async {
      final inner = _CountingTransport();
      final stealth = StealthTransport(
        inner: inner,
        userAgents: ['Custom-UA/1.0'],
        random: Random(1),
        sleep: (_) async {},
      );

      await stealth.fetchHtml(Uri.parse('https://example.com/a'));

      expect(inner.seenHeaders.single, {'User-Agent': 'Custom-UA/1.0'});
    });

    test('waits between minDelay and maxDelay before each request', () async {
      final inner = _CountingTransport();
      final sleeps = <Duration>[];
      final stealth = StealthTransport(
        inner: inner,
        userAgents: ['UA'],
        minDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(milliseconds: 200),
        random: Random(1),
        sleep: (d) async => sleeps.add(d),
      );

      await stealth.fetchHtml(Uri.parse('https://example.com/a'));

      expect(sleeps, hasLength(1));
      final delay = sleeps.single.inMilliseconds;
      expect(delay, greaterThanOrEqualTo(100));
      expect(delay, lessThan(200));
    });
  });

  group('OfflineTransport', () {
    test('serves cached HTML and throws on a miss', () async {
      final transport = OfflineTransport()
        ..addHtml('https://example.com/a', '<html>cached</html>');

      expect(await transport.fetchHtml(Uri.parse('https://example.com/a')),
          '<html>cached</html>');
      await expectLater(
        transport.fetchHtml(Uri.parse('https://example.com/miss')),
        throwsA(isA<TransportException>()),
      );
    });

    test('serves cached JSON and throws on a miss', () async {
      final transport = OfflineTransport()
        ..addJson('https://example.com/data', {'n': 1});

      expect(await transport.fetchJson(Uri.parse('https://example.com/data')),
          {'n': 1});
      await expectLater(
        transport.fetchJson(Uri.parse('https://example.com/miss')),
        throwsA(isA<TransportException>()),
      );
    });
  });
}
