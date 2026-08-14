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
    test('delegates to the inner transport when no web-view fetcher is set',
        () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      expect(await transport.fetchHtml(Uri.parse(url)), '<html>inner</html>');
      expect(await transport.fetchJson(Uri.parse(url)), {'source': 'inner'});
      expect(await transport.fetchBytes(Uri.parse(url)), [1, 2, 3]);

      expect(inner.htmlCalls, 1);
      expect(inner.jsonCalls, 1);
      expect(inner.bytesCalls, 1);
    });

    test('bypasses the web-view fetcher for form POSTs', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);
      var webViewCalls = 0;
      service.fetcher = (url, {headers}) async {
        webViewCalls++;
        return const WebViewFetchResult(body: '<html>webview</html>');
      };

      final body = await transport.fetchHtmlPost(
        Uri.parse('https://example.com/admin-ajax.php'),
        form: {'manga': '591'},
      );

      expect(body, '<html>posted</html>');
      expect(inner.postCalls, 1);
      expect(webViewCalls, 0);
    });

    test('serves HTML through the web-view fetcher when installed', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);
      service.fetcher = (u, {headers}) async =>
          const WebViewFetchResult(body: '<html>from-webview</html>');

      expect(await transport.fetchHtml(Uri.parse(url)),
          '<html>from-webview</html>');
      expect(inner.htmlCalls, 0);
    });

    test('falls back to the inner transport when the web-view fetch is '
        'unusable (null result or thrown)', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fetcher = (u, {headers}) async => null;
      expect(await transport.fetchHtml(Uri.parse(url)), '<html>inner</html>');

      service.fetcher = (u, {headers}) async => throw StateError('nope');
      expect(await transport.fetchHtml(Uri.parse(url)), '<html>inner</html>');

      expect(inner.htmlCalls, 2);
    });

    test('uses the fallback fetcher when the primary cannot serve', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fetcher = (u, {headers}) async => null;
      service.fallbackFetcher = (u, {headers}) async =>
          const WebViewFetchResult(body: '<html>from-background</html>');

      expect(await transport.fetchHtml(Uri.parse(url)),
          '<html>from-background</html>');
      expect(inner.htmlCalls, 0);
    });

    test('primary fetcher wins over the fallback when both can serve',
        () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fetcher = (u, {headers}) async =>
          const WebViewFetchResult(body: '<html>from-browser</html>');
      service.fallbackFetcher = (u, {headers}) async =>
          const WebViewFetchResult(body: '<html>background</html>');

      expect(await transport.fetchHtml(Uri.parse(url)),
          '<html>from-browser</html>');
      expect(inner.htmlCalls, 0);
    });

    test('a throwing fallback still degrades to the inner transport', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fetcher = (u, {headers}) async => null;
      service.fallbackFetcher = (u, {headers}) async => throw StateError('down');

      expect(await transport.fetchHtml(Uri.parse(url)), '<html>inner</html>');
      expect(inner.htmlCalls, 1);
    });

    test('fallback serves JSON and bytes too', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fallbackFetcher = (u, {headers}) async =>
          const WebViewFetchResult(body: '{"ok":true}');

      expect(await transport.fetchJson(Uri.parse(url)), {'ok': true});
      expect(inner.jsonCalls, 0);
    });

    test('an auth-wall web-view result is not served; it falls back to the '
        'inner transport and latches the origin as session-invalid', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fetcher = (u, {headers}) async =>
          const WebViewFetchResult(body: '<login>', status: 401);

      expect(await transport.fetchHtml(Uri.parse(url)), '<html>inner</html>');
      expect(inner.htmlCalls, 1);
      expect(session.lastInvalidOrigin.value, Uri.parse(url));
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
    });

    test('a plain inner failure is not treated as a session wall', () async {
      final inner = _ThrowingInner(
        const TransportException('404'),
      );
      final transport = WebViewTransport(inner: inner);

      await expectLater(
        transport.fetchHtml(Uri.parse(url)),
        throwsA(isA<TransportException>()),
      );
      expect(session.lastInvalidOrigin.value, isNull);
    });
  });
}