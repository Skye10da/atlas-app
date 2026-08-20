import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:atlas_app/core/content_engine/transport/cached_transport.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/offline_transport.dart';
import 'package:atlas_app/core/content_engine/transport/stealth_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

class _CountingTransport implements Transport {
  int htmlCalls = 0;
  int jsonCalls = 0;
  int jsonPostCalls = 0;
  int postCalls = 0;
  final List<Map<String, String>?> seenHeaders = [];
  final List<Map<String, String>?> seenForms = [];
  final List<Object?> seenJsonBodies = [];

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    htmlCalls++;
    seenHeaders.add(headers);
    return '<html>ok</html>';
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    postCalls++;
    seenHeaders.add(headers);
    seenForms.add(form);
    return '<html>posted</html>';
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonCalls++;
    seenHeaders.add(headers);
    return {'ok': true};
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    jsonPostCalls++;
    seenHeaders.add(headers);
    seenJsonBodies.add(jsonBody);
    return {'posted': true};
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    seenHeaders.add(headers);
    return [1, 2, 3];
  }
}

void main() {
  group('CachedTransport', () {
    test(
      'serves a repeat fetch from cache without calling the inner transport',
      () async {
        final inner = _CountingTransport();
        final cached = CachedTransport(inner: inner);
        final uri = Uri.parse('https://example.com/a');

        await cached.fetchHtml(uri);
        await cached.fetchHtml(uri);
        await cached.fetchHtml(uri);

        expect(inner.htmlCalls, 1);
      },
    );

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

    test('caches form POSTs by url and payload', () async {
      final inner = _CountingTransport();
      final cached = CachedTransport(inner: inner);
      final uri = Uri.parse('https://example.com/admin-ajax.php');
      const form = {'action': 'manga_get_chapters', 'manga': '591'};

      await cached.fetchHtmlPost(uri, form: form);
      await cached.fetchHtmlPost(uri, form: form);
      await cached.fetchHtmlPost(uri, form: {...form, 'manga': '592'});

      expect(inner.postCalls, 2);
    });

    test('caches JSON POSTs by url and payload', () async {
      final inner = _CountingTransport();
      final cached = CachedTransport(inner: inner);
      final uri = Uri.parse('https://example.com/api/reader/get');

      await cached.fetchJsonPost(uri, jsonBody: {'chapter_no': 1});
      await cached.fetchJsonPost(uri, jsonBody: {'chapter_no': 1});
      await cached.fetchJsonPost(uri, jsonBody: {'chapter_no': 2});

      expect(inner.jsonPostCalls, 2);
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

    test('passes form POSTs through with a decorated User-Agent', () async {
      final inner = _CountingTransport();
      final stealth = StealthTransport(
        inner: inner,
        userAgents: ['Custom-UA/1.0'],
        random: Random(1),
        sleep: (_) async {},
      );

      await stealth.fetchHtmlPost(
        Uri.parse('https://example.com/admin-ajax.php'),
        form: {'manga': '591'},
      );

      expect(inner.seenForms.single, {'manga': '591'});
      expect(inner.seenHeaders.single, {'User-Agent': 'Custom-UA/1.0'});
    });
  });

  group('OfflineTransport', () {
    test('serves cached HTML and throws on a miss', () async {
      final transport = OfflineTransport()
        ..addHtml('https://example.com/a', '<html>cached</html>');

      expect(
        await transport.fetchHtml(Uri.parse('https://example.com/a')),
        '<html>cached</html>',
      );
      await expectLater(
        transport.fetchHtml(Uri.parse('https://example.com/miss')),
        throwsA(isA<TransportException>()),
      );
    });

    test('serves cached JSON and throws on a miss', () async {
      final transport = OfflineTransport()
        ..addJson('https://example.com/data', {'n': 1});

      expect(await transport.fetchJson(Uri.parse('https://example.com/data')), {
        'n': 1,
      });
      await expectLater(
        transport.fetchJson(Uri.parse('https://example.com/miss')),
        throwsA(isA<TransportException>()),
      );
    });

    test(
      'serves form POSTs keyed by url and payload, throws on a miss',
      () async {
        const form = {'manga': '591'};
        final transport = OfflineTransport()
          ..addPostHtml(
            'https://example.com/admin-ajax.php',
            '<li class="wp-manga-chapter"><a href="/ch/1">Chapter 1</a></li>',
            form: form,
          );

        expect(
          await transport.fetchHtmlPost(
            Uri.parse('https://example.com/admin-ajax.php'),
            form: form,
          ),
          contains('Chapter 1'),
        );
        await expectLater(
          transport.fetchHtmlPost(
            Uri.parse('https://example.com/admin-ajax.php'),
            form: const {'manga': '592'},
          ),
          throwsA(isA<TransportException>()),
        );
      },
    );

    test('serves JSON POSTs keyed by url, throws on a miss', () async {
      final transport = OfflineTransport()
        ..addPostJson('https://example.com/api/reader/get', {
          'success': true,
          'data': {'body': 'arr:...'},
        });

      expect(
        await transport.fetchJsonPost(
          Uri.parse('https://example.com/api/reader/get'),
          jsonBody: {'chapter_no': 639},
        ),
        {
          'success': true,
          'data': {'body': 'arr:...'},
        },
      );
      await expectLater(
        transport.fetchJsonPost(
          Uri.parse('https://example.com/api/miss'),
          jsonBody: {},
        ),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('HttpTransport', () {
    test(
      'throws a clear, actionable message for a Cloudflare challenge',
      () async {
        final mock = MockClient(
          (request) async => http.Response(
            '<html><head><title>Just a moment...</title></head></html>',
            403,
            headers: {'server': 'cloudflare', 'cf-mitigated': 'challenge'},
          ),
        );
        final transport = HttpTransport(client: mock);

        try {
          await transport.fetchHtml(Uri.parse('https://novelfull.net/x.html'));
          fail('expected a TransportException');
        } on TransportException catch (e) {
          expect(e.message, contains('novelfull.net'));
          expect(e.message, contains('bot-check'));
          expect(
            e.sessionExpired,
            isFalse,
            reason: 'a Cloudflare bot-check is not an expired session',
          );
        }
      },
    );

    test('tags a 401 as a session-expired failure', () async {
      final mock = MockClient(
        (request) async => http.Response('unauthorized', 401),
      );
      final transport = HttpTransport(client: mock);

      try {
        await transport.fetchHtml(Uri.parse('https://example.com/ch/1'));
        fail('expected a TransportException');
      } on TransportException catch (e) {
        expect(e.sessionExpired, isTrue);
      }
    });

    test('tags a non-Cloudflare 403 as a session-expired failure', () async {
      final mock = MockClient(
        (request) async => http.Response('forbidden', 403),
      );
      final transport = HttpTransport(client: mock);

      try {
        await transport.fetchHtml(Uri.parse('https://example.com/ch/1'));
        fail('expected a TransportException');
      } on TransportException catch (e) {
        expect(e.sessionExpired, isTrue);
      }
    });

    test('keeps the generic message for other HTTP errors', () async {
      final mock = MockClient(
        (request) async => http.Response('not found', 404),
      );
      final transport = HttpTransport(client: mock);

      try {
        await transport.fetchHtml(Uri.parse('https://example.com/x'));
        fail('expected a TransportException');
      } on TransportException catch (e) {
        expect(e.message, 'GET https://example.com/x failed with 404');
      }
    });

    test('POSTs form-encoded bodies and returns the body', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/wp-admin/admin-ajax.php',
        );
        expect(
          request.headers['content-type'],
          contains('application/x-www-form-urlencoded'),
        );
        expect(request.body, 'action=manga_get_chapters&manga=591');
        return http.Response('<li>ok</li>', 200);
      });
      final transport = HttpTransport(client: mock);

      final body = await transport.fetchHtmlPost(
        Uri.parse('https://example.com/wp-admin/admin-ajax.php'),
        form: {'action': 'manga_get_chapters', 'manga': '591'},
      );

      expect(body, '<li>ok</li>');
    });

    test(
      'POSTs JSON bodies with application/json and returns decoded JSON',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://example.com/api/search');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {'text': 'male god'});
          return http.Response(
            '{"success":true,"data":[{"id":1}]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final transport = HttpTransport(client: mock);

        final value = await transport.fetchJsonPost(
          Uri.parse('https://example.com/api/search'),
          jsonBody: {'text': 'male god'},
        );

        expect(value, {
          'success': true,
          'data': [
            {'id': 1},
          ],
        });
      },
    );
  });
}
