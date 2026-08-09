import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/controllers/browser_tabs_controller.dart';
import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/domain/entities/web_tab_state.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_repository_interface.dart';
import 'package:atlas_app/core/error_handling/result.dart';

class FakeBrowserEngine implements BrowserWebEngine {
  FakeBrowserEngine({this.initialUrl}) {
    _currentUrl.value = initialUrl;
  }

  final String? initialUrl;
  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  final List<String> loadedUrls = [];
  final List<String> jsHandlers = [];
  bool disposed = false;
  int buildCount = 0;

  @override
  ValueNotifier<String?> get currentUrl => _currentUrl;
  @override
  ValueNotifier<String?> get currentTitle => _currentTitle;
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

  @override
  Future<void> goBack() async {}
  @override
  Future<void> goForward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async {}

  @override
  Future<dynamic> evaluate(String script) async => null;

  @override
  void addJsHandler(String name, JsHandlerCallback handler) {
    jsHandlers.add(name);
  }

  @override
  void removeJsHandler(String name) {
    jsHandlers.remove(name);
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
    final sorted = List.of(webTabs)
      ..sort((a, b) => a.order.compareTo(b.order));
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

  BrowserTabsController makeController({int maxTabs = 5, bool persist = true}) {
    return BrowserTabsController(
      repository: repo,
      engineFactory: ({String? initialUrl}) => FakeBrowserEngine(initialUrl: initialUrl),
      maxTabs: maxTabs,
      persist: persist,
    );
  }

  setUp(() {
    repo = InMemoryBrowserRepository();
  });

  group('BrowserTabsController', () {
    test('restore() opens the persisted strip, most recent order last', () async {
      repo.webTabs
        ..add(WebTabState(
          id: 't1',
          url: 'https://a.example',
          title: 'A',
          order: 1,
          lastActiveAt: DateTime(2025, 1, 2),
        ))
        ..add(WebTabState(
          id: 't0',
          url: 'https://b.example',
          title: 'B',
          order: 0,
          lastActiveAt: DateTime(2025, 1, 1),
        ));

      final controller = makeController();
      await controller.restore();

      expect(controller.tabs, hasLength(2));
      expect(controller.tabs.map((t) => t.id).toList(), ['t0', 't1']);
      expect(controller.tabs.first.engine.currentUrl.value, 'https://b.example');
      expect(controller.tabs.last.engine.currentUrl.value, 'https://a.example');
      expect(controller.activeIndex, 1);
      controller.dispose();
    });

    test('restore with no persisted tabs lands on the start page', () async {
      final controller = makeController();
      await controller.restore();

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.isOnStartPage, isTrue);
      controller.dispose();
    });

    test('addTab activates the new tab and persists it', () async {
      final controller = makeController(persist: false);
      await controller.addTab(url: 'https://c.example');

      expect(controller.tabs, hasLength(1));
      expect(controller.activeIndex, 0);
      expect(controller.activeTab!.engine.currentUrl.value, 'https://c.example');
      controller.dispose();
    });

    test('addTab respects the maxTabs ceiling', () async {
      final controller = makeController(maxTabs: 2, persist: false);
      await controller.addTab();
      await controller.addTab();
      await controller.addTab();

      expect(controller.tabs, hasLength(2));
      expect(controller.canAddTab, isFalse);
      controller.dispose();
    });

    test('close removes and renumbers persisted tabs', () async {
      final controller = makeController(persist: true);
      await controller.addTab(url: 'https://a.example');
      await controller.addTab(url: 'https://b.example');
      final survivingId = controller.tabs[1].id;

      await controller.close(0);

      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, survivingId);
      expect(repo.webTabs, hasLength(1));
      expect(repo.webTabs.single.order, 0);
      controller.dispose();
    });

    test('activate persists lastActiveAt', () async {
      final controller = makeController(persist: true);
      await controller.addTab();
      await controller.addTab();
      await controller.activate(0);

      expect(controller.activeIndex, 0);
      controller.dispose();
    });

    test('title falls back to "New tab" when empty', () async {
      final controller = makeController(persist: false);
      await controller.addTab();

      final fake = controller.tabs.single.engine as FakeBrowserEngine;
      fake.currentTitle.value = null;
      expect(controller.tabs.single.title, 'New tab');

      fake.currentTitle.value = 'Atlas';
      expect(controller.tabs.single.title, 'Atlas');
      controller.dispose();
    });

    test('dispose releases every engine', () async {
      final controller = makeController(persist: false);
      await controller.addTab();
      await controller.addTab();

      final engines = controller.tabs.map((t) => t.engine).toList();
      controller.dispose();

      expect(engines.map((e) => (e as FakeBrowserEngine).disposed), everyElement(isTrue));
    });
  });
}