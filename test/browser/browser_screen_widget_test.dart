import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/entities/web_tab_state.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_repository_interface.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/screens/browser_screen.dart';
import 'package:atlas_app/browser/presentation/widgets/browser_start_page.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/error_handling/result.dart';

class FakeBrowserEngine implements BrowserWebEngine {
  FakeBrowserEngine({this.initialUrl}) {
    _currentUrl.value = initialUrl;
  }

  final String? initialUrl;
  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  final List<String> loadedUrls = [];
  bool disposed = false;
  int buildCount = 0;

  /// Simulated JS bridge: [evaluate] fires the matching handler with
  /// [cannedArgs], standing in for the web view's in-page `fetch` callback.
  final Map<String, JsHandlerCallback> handlers = {};
  List<dynamic> cannedArgs = ['<html>from-browser</html>'];

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
  Future<void> load(String url) async {
    loadedUrls.add(url);
    _currentUrl.value = url;
  }

  void reportError(String message) {
    _currentUrl.value = 'https://a.example/error';
    _lastError.value = message;
  }

  void clearError() => _lastError.value = null;

  @override
  Future<void> goHome() async {
    _currentUrl.value = kBrowserStartPageUrl;
    loadedUrls.add(kBrowserStartPageUrl);
  }

  @override
  Future<void> goBack() async {}
  @override
  Future<void> goForward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<dynamic> evaluate(String script) async {
    for (final entry in handlers.entries) {
      if (script.contains('"${entry.key}"')) {
        entry.value(List<dynamic>.from(cannedArgs));
      }
    }
    return null;
  }
  @override
  Future<int> search(String query) async => 0;
  @override
  Future<bool> findNext() async => true;
  @override
  Future<bool> findPrevious() async => true;
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
  void addJsHandler(String name, JsHandlerCallback handler) {
    handlers[name] = handler;
  }
  @override
  void removeJsHandler(String name) {
    handlers.remove(name);
  }
  @override
  Widget buildView() {
    buildCount++;
    return const SizedBox.shrink();
  }
  @override
  void dispose() {
    disposed = true;
    for (final notifier in <ValueNotifier<Object?>>[
      _currentUrl,
      _currentTitle,
      _lastError,
      _progress,
      _canGoBack,
      _canGoForward,
      _isLoading,
    ]) {
      notifier.dispose();
    }
  }
}

class InMemoryBrowserRepository implements BrowserRepositoryInterface {
  final webHistory = <WebHistoryEntry>[];
  final webBookmarks = <BrowserBookmark>[];
  final webTabs = <WebTabState>[];

  @override
  Future<Result<List<WebHistoryEntry>>> getAllHistory({int limit = 50}) async =>
      Success(webHistory.take(limit).toList());

  @override
  Stream<Result<List<WebHistoryEntry>>> watchHistory({int limit = 50}) =>
      Stream.value(Success(webHistory.take(limit).toList()));

  @override
  Future<Result<void>> recordVisit({
    required String url,
    String? title,
    DateTime? visitedAt,
  }) async {
    webHistory.insert(
      0,
      WebHistoryEntry(
        id: '$url#${webHistory.length}',
        url: url,
        title: title,
        visitedAt: visitedAt ?? DateTime.now(),
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> clearHistory() async {
    webHistory.clear();
    return const Success(null);
  }

  @override
  Future<Result<List<BrowserBookmark>>> getAllBookmarks() async =>
      Success(List.of(webBookmarks));

  @override
  Stream<Result<List<BrowserBookmark>>> watchBookmarks() =>
      Stream.value(Success(List.of(webBookmarks)));

  @override
  Future<Result<void>> addBookmark(BrowserBookmark bookmark) async {
    webBookmarks.add(bookmark);
    return const Success(null);
  }

  @override
  Future<Result<void>> removeBookmark(String bookmarkId) async {
    webBookmarks.removeWhere((b) => b.id == bookmarkId);
    return const Success(null);
  }

  @override
  Future<Result<List<WebTabState>>> getTabs() async {
    final sorted = List.of(webTabs)..sort((a, b) => a.order.compareTo(b.order));
    return Success(sorted);
  }

  @override
  Future<Result<void>> upsertTab(WebTabState tab) async {
    webTabs.removeWhere((t) => t.id == tab.id);
    webTabs.add(tab);
    return const Success(null);
  }

  @override
  Future<Result<void>> removeTab(String tabId) async {
    webTabs.removeWhere((t) => t.id == tabId);
    return const Success(null);
  }

  @override
  Future<Result<void>> clearTabs() async {
    webTabs.clear();
    return const Success(null);
  }
}

void main() {
  late InMemoryBrowserRepository repo;
  late List<FakeBrowserEngine> createdEngines;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = InMemoryBrowserRepository();
    createdEngines = [];
  });

  Widget harness({String? initialUrl}) {
    return ProviderScope(
      overrides: [
        browserRepositoryProvider.overrideWithValue(repo),
        browserEngineFactoryProvider.overrideWithValue(
          ({String? initialUrl}) {
            final engine = FakeBrowserEngine(initialUrl: initialUrl);
            createdEngines.add(engine);
            return engine;
          },
        ),
      ],
      child: MaterialApp(
        home: BrowserScreen(initialUrl: initialUrl),
      ),
    );
  }

  testWidgets('tap and address entry reach the engine', (tester) async {
    await tester.pumpWidget(harness(initialUrl: 'https://a.example'));
    await tester.pumpAndSettle();

    expect(createdEngines, hasLength(1));
    expect(tester.takeException(), isNull);

    final engine = createdEngines.single;

    // A submitted address reaches the engine, normalized.
    final urlField = find.byType(TextField).first;
    await tester.enterText(urlField, 'example.com');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.loadedUrls, contains('https://example.com'));
    expect(tester.takeException(), isNull);

    // The New Tab button responds to a tap.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(createdEngines, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('load errors show a banner without unmounting the web view',
      (tester) async {
    await tester.pumpWidget(harness(initialUrl: 'https://a.example'));
    await tester.pumpAndSettle();

    final engine = createdEngines.single;
    expect(find.textContaining('Could not load'), findsNothing);

    engine.reportError('Could not load this page: net::ERR_INTERNET_DISCONNECTED');
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Could not load this page'), findsOneWidget);
    // The page widget stays in the tree (the platform view is never unmounted).
    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);

    // Retry issues a fresh load and clears the banner.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(engine.loadedUrls, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blank start-page tab still mounts the web view and loads',
      (tester) async {
    await tester.pumpWidget(harness(initialUrl: null));
    await tester.pumpAndSettle();

    expect(createdEngines, hasLength(1));
    final engine = createdEngines.single;

    // No initialUrl → the tab is on the native start page, but the platform
    // web view must still be mounted underneath (this was the regression:
    // it wasn't, so every load was silently swallowed).
    expect(engine.buildCount, greaterThan(0));
    expect(tester.takeException(), isNull);

    // A submitted address now reaches the mounted view.
    final urlField = find.byType(TextField).first;
    await tester.enterText(urlField, 'example.com');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.loadedUrls, contains('https://example.com'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home returns the current tab to the new-tab page',
      (tester) async {
    await tester.pumpWidget(harness(initialUrl: 'https://a.example'));
    await tester.pumpAndSettle();

    final engine = createdEngines.single;
    expect(engine.currentUrl.value, 'https://a.example');
    expect(find.byType(BrowserStartPage), findsNothing);

    final urlField = find.byType(TextField).first;
    expect(tester.widget<TextField>(urlField).controller!.text, 'https://a.example');

    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(engine.currentUrl.value, kBrowserStartPageUrl);
    expect(find.byType(BrowserStartPage), findsOneWidget);
    expect(tester.widget<TextField>(urlField).controller!.text, isEmpty,
        reason: 'the address pill should clear when Home lands on the start page');
    expect(tester.takeException(), isNull);

    // Leaving the start page again restores the pill and drops the overlay.
    await engine.load('https://a.example');
    await tester.pumpAndSettle();
    expect(engine.currentUrl.value, 'https://a.example');
    expect(find.byType(BrowserStartPage), findsNothing);
    expect(tester.widget<TextField>(urlField).controller!.text, 'https://a.example');
  });

  testWidgets('routes same-origin plugin fetches through the live web view '
      'while mounted and clears the fetcher on dispose', (tester) async {
    final service = WebViewFetchService.instance;
    service.fetcher = null;

    await tester.pumpWidget(
      harness(initialUrl: 'https://novelfull.net/the-99th-divorce.html'),
    );
    await tester.pumpAndSettle();

    final fetcher = service.fetcher;
    expect(fetcher, isNotNull,
        reason: 'the browser shell keeps the shared web-view fetcher installed');

    // A same-origin chapter URL is served from the live page context...
    final html = await fetcher!(
      Uri.parse('https://novelfull.net/legend-of-swordsman/chapter-1.html'),
    );
    expect(html, '<html>from-browser</html>');

    // ...and a cross-origin target falls through to null (→ plain HTTP).
    expect(
      await fetcher(Uri.parse('https://other.example/x.html')),
      isNull,
    );

    // Closing the browser drops the shared fetcher so later plugin fetches
    // don't route into a torn-down web view.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(service.fetcher, isNull);
  });
}
