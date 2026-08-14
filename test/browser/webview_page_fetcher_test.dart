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
  /// successful (`['<html>']`) or failed (`[]`) in-page fetch.
  List<dynamic> cannedArgs = ['<html>from-page</html>'];

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
    test('fetches a same-origin URL through the page and returns its text',
        () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://novelfull.net/the-99th-divorce.html',
      );
      final fetcher = WebViewPageFetcher(engine: engine);

      final html = await fetcher.fetchHtml(
        Uri.parse('https://novelfull.net/ajax-chapter-option?novelId=261'),
      );

      expect(html, '<html>from-page</html>');
      expect(engine.evaluated, hasLength(1));
      expect(engine.evaluated.single, contains('fetch('));
      expect(engine.evaluated.single,
          contains('https://novelfull.net/ajax-chapter-option?novelId=261'));
      expect(engine.evaluated.single, contains("'include'"));
      expect(engine.removedHandlers, hasLength(1));
    });

    test('returns null (fall back to HTTP) for a cross-origin request', () async {
      final engine = _ScriptEngine(
        currentUrl: 'https://novelfull.net/the-99th-divorce.html',
      );
      final fetcher = WebViewPageFetcher(engine: engine);

      final html = await fetcher.fetchHtml(
        Uri.parse('https://other.com/the-99th-divorce.html'),
      );

      expect(html, isNull);
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
