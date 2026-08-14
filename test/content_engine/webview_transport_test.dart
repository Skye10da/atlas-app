import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';

class _CountingInner implements Transport {
  int htmlCalls = 0;
  int jsonCalls = 0;
  int bytesCalls = 0;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    htmlCalls++;
    return '<html>inner</html>';
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonCalls++;
    return {'source': 'inner'};
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    bytesCalls++;
    return [1, 2, 3];
  }
}

void main() {
  final service = WebViewFetchService.instance;
  const url = 'https://novelfull.net/the-99th-divorce.html';

  setUp(() {
    service.fetcher = null;
    service.fallbackFetcher = null;
  });
  tearDown(() {
    service.fetcher = null;
    service.fallbackFetcher = null;
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

    test('serves HTML through the web-view fetcher when installed', () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);
      service.fetcher = (u, {headers}) async => '<html>from-webview</html>';

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
      service.fallbackFetcher =
          (u, {headers}) async => '<html>from-background</html>';

      expect(await transport.fetchHtml(Uri.parse(url)),
          '<html>from-background</html>');
      expect(inner.htmlCalls, 0);
    });

    test('primary fetcher wins over the fallback when both can serve',
        () async {
      final inner = _CountingInner();
      final transport = WebViewTransport(inner: inner);

      service.fetcher = (u, {headers}) async => '<html>from-browser</html>';
      service.fallbackFetcher = (u, {headers}) async => '<html>background</html>';

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

      service.fallbackFetcher = (u, {headers}) async => '{"ok":true}';

      expect(await transport.fetchJson(Uri.parse(url)), {'ok': true});
      expect(inner.jsonCalls, 0);
    });
  });
}
