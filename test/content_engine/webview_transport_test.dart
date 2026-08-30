import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';

class _CountingInner implements Transport {
  int htmlCalls = 0;
  int jsonCalls = 0;
  int bytesCalls = 0;
  int postCalls = 0;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    htmlCalls++;
    return '<html>inner</html>';
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    postCalls++;
    return '<html>posted</html>';
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonCalls++;
    return {'source': 'inner'};
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    jsonCalls++;
    return {'source': 'inner'};
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    bytesCalls++;
    return [1, 2, 3];
  }
}

class _ThrowingInner implements Transport {
  _ThrowingInner(this.error);

  final TransportException error;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    throw error;
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    throw error;
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    throw error;
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    throw error;
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    throw error;
  }
}

class _MutableInner implements Transport {
  _MutableInner(this.error);

  TransportException? error;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final e = error;
    if (e != null) throw e;
    return '<html>cleared</html>';
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    final e = error;
    if (e != null) throw e;
    return '<html>cleared</html>';
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final e = error;
    if (e != null) throw e;
    return {'ok': true};
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final e = error;
    if (e != null) throw e;
    return {'ok': true};
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final e = error;
    if (e != null) throw e;
    return [1, 2, 3];
  }
}

void main() {
  final service = WebViewFetchService.instance;
  final session = SessionRefreshService.instance;
  const url = 'https://novelfull.net/the-99th-divorce.html';

  setUp(() {
    service.fetcher = null;
    service.fallbackFetcher = null;
    session.clearInvalid();
  });
  tearDown(() {
    service.fetcher = null;
    service.fallbackFetcher = null;
    session.clearInvalid();
  });

  group('WebViewTransport', () {
    test(
      'delegates to the inner transport directly (HTTP-first)',
      () async {
        final inner = _CountingInner();
        final transport = WebViewTransport(inner: inner);

        expect(await transport.fetchHtml(Uri.parse(url)), '<html>inner</html>');
        expect(await transport.fetchJson(Uri.parse(url)), {'source': 'inner'});
        expect(await transport.fetchBytes(Uri.parse(url)), [1, 2, 3]);

        expect(inner.htmlCalls, 1);
        expect(inner.jsonCalls, 1);
        expect(inner.bytesCalls, 1);
      },
    );

    test('serves through inner transport first even when web-view fetcher is installed', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);
      service.fetcher =
          (url, {headers, method, jsonBody, binary = false}) async =>
              const WebViewFetchResult(body: '<html>webview</html>');

      final body = await transport.fetchHtmlPost(
        Uri.parse('https://example.com/admin-ajax.php'),
        form: {'manga': '591'},
      );

      expect(body, '<html>posted</html>');
      expect(inner.postCalls, 1);
    });

    test('recovers through live web-view fetcher when inner throws bot challenge', () async {
      final inner = _ThrowingInner(
        const TransportException('Cloudflare blocked', botChallenge: true),
      );
      final transport = WebViewTransport(inner: inner);
      service.fetcher =
          (u, {headers, method, jsonBody, binary = false}) async =>
              const WebViewFetchResult(body: '<html>from-live-webview</html>');

      expect(
        await transport.fetchHtml(Uri.parse(url)),
        '<html>from-live-webview</html>',
      );
    });

    test('recovers bytes through live web-view when inner throws bot challenge', () async {
      final inner = _ThrowingInner(
        const TransportException('Cloudflare blocked', botChallenge: true),
      );
      final transport = WebViewTransport(inner: inner);
      service.fetcher =
          (u, {headers, method, jsonBody, binary = false}) async =>
              WebViewFetchResult(
                bytes: Uint8List.fromList([10, 20, 30]),
                status: 200,
              );

      final result = await transport.fetchBytes(Uri.parse(url));
      expect(result, [10, 20, 30]);
    });

    test('an inner session-expired failure is latched and rethrown', () async {
      final inner = _ThrowingInner(
        const TransportException('401', sessionExpired: true),
      );
      final transport = WebViewTransport(inner: inner);

      await expectLater(
        transport.fetchHtml(Uri.parse(url)),
        throwsA(isA<TransportException>()),
      );
      expect(session.lastInvalidOrigin.value, Uri.parse(url));
      expect(
        session.lastInvalidSeedUrl.value,
        Uri.parse(url),
        reason: 'the challenged URL seeds the re-verify webview',
      );
    });

    test('a plain inner failure is not treated as a session wall', () async {
      final inner = _ThrowingInner(const TransportException('404'));
      final transport = WebViewTransport(inner: inner);

      await expectLater(
        transport.fetchHtml(Uri.parse(url)),
        throwsA(isA<TransportException>()),
      );
      expect(session.lastInvalidOrigin.value, isNull);
    });

    test('escalates a Cloudflare bot-check to the session-refresh flow when '
        'no live webview is available', () async {
      final inner = _ThrowingInner(
        const TransportException('Cloudflare blocked', botChallenge: true),
      );
      final transport = WebViewTransport(inner: inner);
      service.fetcher = null;

      await expectLater(
        transport.fetchHtml(Uri.parse(url)),
        throwsA(
          isA<TransportException>().having(
            (e) => e.sessionExpired,
            'sessionExpired',
            isTrue,
          ),
        ),
      );
      expect(session.lastInvalidOrigin.value, Uri.parse(url));
      expect(session.lastInvalidSeedUrl.value, Uri.parse(url));
      expect(
        session.lastInvalidVerificationProbe,
        isNotNull,
        reason: 'the challenged URL seeds the re-verify webview with a probe',
      );
    });

    test('bot-challenge escalation latches a probe that reports when the '
        'challenge clears', () async {
      final inner = _MutableInner(
        const TransportException('Cloudflare blocked', botChallenge: true),
      );
      final transport = WebViewTransport(inner: inner);
      service.fetcher = null;

      await expectLater(
        transport.fetchHtml(Uri.parse(url)),
        throwsA(isA<TransportException>()),
      );
      final probe = session.lastInvalidVerificationProbe;
      expect(probe, isNotNull);

      // Still challenged -> probe reports not cleared.
      expect(await probe!(), isFalse);

      // Once the challenge clears (fresh cookies captured), probe reports done.
      inner.error = null;
      expect(await probe(), isTrue);
    });

    test('does not escalate a generic (non-challenge) inner failure', () async {
      final inner = _ThrowingInner(const TransportException('503'));
      final transport = WebViewTransport(inner: inner);
      service.fetcher = null;

      await expectLater(
        transport.fetchHtml(Uri.parse(url)),
        throwsA(isA<TransportException>()),
      );
      expect(session.lastInvalidOrigin.value, isNull);
      expect(session.lastInvalidVerificationProbe, isNull);
    });
  });
}
