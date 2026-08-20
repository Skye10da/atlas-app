import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';

class _ScriptEngine implements BrowserWebEngine {
  _ScriptEngine({String? currentUrl}) {
    _currentUrl.value = currentUrl;
  }

  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  final Map<String, JsHandlerCallback> handlers = {};
  final List<String> evaluated = [];
  final List<String> removedHandlers = [];

  /// Arguments the simulated page passes back to the JS handler, mimicking a
  /// successful (`['<json envelope>']`) or failed (`[]`) in-page fetch.
  List<dynamic> cannedArgs = const [
    '{"b":"<html>from-page</html>","s":200,"u":"https://novelfull.net/the-99th-divorce.html"}'
  ];

  @override
  ValueNotifier<String?> get currentUrl => _currentUrl;
  @override
  ValueNotifier<String?> get currentTitle => _currentTitle;
  @override
  ValueNotifier<String?> get lastError => _lastError;
  @override
  ValueNotifier<double> get progress => _progress;
  @override
  ValueNotifier<bool> get canGoBack => _canGoBack;
  @override
  ValueNotifier<bool> get canGoForward => _canGoForward;
  @override
  ValueNotifier<bool> get isLoading => _isLoading;

  @override
  Future<dynamic> evaluate(String script) async {
    evaluated.add(script);
    for (final entry in handlers.entries) {
      if (script.contains('"${entry.key}"')) {
        entry.value(List<dynamic>.from(cannedArgs));
      }
    }
    return null;
  }

  @override
  void addJsHandler(String name, JsHandlerCallback handler) {
    handlers[name] = handler;
  }

  @override
  void removeJsHandler(String name) {
    handlers.remove(name);
    removedHandlers.add(name);
  }

  @override
  Future<void> load(String url) async => _currentUrl.value = url;
  @override
  Future<void> goHome() async {}
  @override
  Future<void> goBack() async {}
  @override
  Future<void> goForward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<int> search(String query) async => 0;
  @override
  Future<bool> findNext() async => false;
  @override
  Future<bool> findPrevious() async => false;
  @override
  Future<void> clearFind() async {}
  @override
  Future<void> setSelectionListener(
      void Function(WebSelection selection)? listener) async {}
  @override
  Future<void> clearSelection() async {}
  @override
  Future<void> selectAllInPage() async {}
  @override
  Future<void> setDownloadListener(
      void Function(String url, String? mimeType)? listener) async {}
  @override
  Widget buildView() => throw UnimplementedError();
  @override
  void dispose() {}
}

void main() {
  group('WebViewPageFetcher', () {
    test('fetches a same-origin URL through the page and returns body, status '
        'and final URL', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://novelfull.net/the-99th-divorce.html',
      );
      final fetcher = WebViewPageFetcher(engine: engine);

      final result = await fetcher.fetchHtml(
        Uri.parse('https://novelfull.net/ajax-chapter-option?novelId=261'),
      );

      expect(result?.body, '<html>from-page</html>');
      expect(result?.status, 200);
      expect(
        result?.finalUrl,
        Uri.parse('https://novelfull.net/the-99th-divorce.html'),
      );
      expect(engine.evaluated, hasLength(1));
      expect(engine.evaluated.single, contains('fetch('));
      expect(engine.evaluated.single,
          contains('https://novelfull.net/ajax-chapter-option?novelId=261'));
      expect(engine.evaluated.single, contains("'include'"));
      expect(engine.evaluated.single, contains('r.status'));
      expect(engine.removedHandlers, hasLength(1));
    });

    test('marks a 401 response as a session wall', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://novelfull.net/the-99th-divorce.html',
      )..cannedArgs = const [
          '{"b":"","s":401,"u":"https://novelfull.net/login"}'
        ];
      final fetcher = WebViewPageFetcher(engine: engine);

      final result = await fetcher.fetchHtml(
        Uri.parse('https://novelfull.net/chapter-1.html'),
      );

      expect(result?.status, 401);
      expect(result?.isSessionWall, isTrue);
    });

    test('POSTs a JSON body to a same-origin URL with the right method and '
        'content type', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://wtr-lab.com/en/novel/29058/charm-is-full',
      )..cannedArgs = const [
          '{"b":"{\\"success\\":true,\\"chapter\\":{\\"title\\":\\"Chapter 1\\"}}",'
              '"s":200,"u":"https://wtr-lab.com/api/reader/get"}'
        ];
      final fetcher = WebViewPageFetcher(engine: engine);

      final result = await fetcher.fetchHtml(
        Uri.parse('https://wtr-lab.com/api/reader/get'),
        method: 'POST',
        jsonBody: {'translate': 'web', 'raw_id': 29058, 'chapter_no': 639},
      );

      expect(
        result?.body,
        '{"success":true,"chapter":{"title":"Chapter 1"}}',
      );
      expect(engine.evaluated, hasLength(1));
      final script = engine.evaluated.single;
      expect(script, contains('"POST"'));
      expect(script, contains('translate'));
      expect(script, contains('29058'));
      expect(script, contains('chapter_no'));
      expect(script, contains('Content-Type'));
      expect(script, contains('application/json'));
      expect(script, contains('opts.body = body'));
      expect(script, contains('credentials: \'include\''));
    });

    test('keeps GET fetches body-free with no content-type header', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://wtr-lab.com/en/novel/29058/charm-is-full',
      );
      final fetcher = WebViewPageFetcher(engine: engine);

      await fetcher.fetchHtml(Uri.parse('https://wtr-lab.com/api/chapters/29058'));

      final script = engine.evaluated.single;
      expect(script, contains('"GET"'));
      expect(script, isNot(contains('"Content-Type"')));
      expect(script, isNot(contains('"translate"')));
    });

    test('returns null (fall back to HTTP) for a cross-origin request', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://novelfull.net/the-99th-divorce.html',
      );
      final fetcher = WebViewPageFetcher(engine: engine);

      final result = await fetcher.fetchHtml(
        Uri.parse('https://other.com/the-99th-divorce.html'),
      );

      expect(result, isNull);
      expect(engine.evaluated, isEmpty);
      expect(engine.handlers, isEmpty);
    });

    test('returns null when the web view is not on a page', () async {
      final engine = _ScriptEngine(currentUrl: null);
      final fetcher = WebViewPageFetcher(engine: engine);

      expect(
        await fetcher.fetchHtml(Uri.parse('https://novelfull.net/x.html')),
        isNull,
      );
    });

    test('returns null when the in-page fetch fails', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://novelfull.net/the-99th-divorce.html',
      )..cannedArgs = const [];
      final fetcher = WebViewPageFetcher(engine: engine);

      expect(
        await fetcher.fetchHtml(Uri.parse('https://novelfull.net/x.html')),
        isNull,
      );
    });
  });
}