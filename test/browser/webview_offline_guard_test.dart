import 'package:flutter/widgets.dart';

import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/services/webview_offline_guard.dart';

import 'package:flutter_test/flutter_test.dart';

/// Records every pause-relevant action the guard takes, without any plugin.
class FakeEngine implements BrowserWebEngine {
  FakeEngine();

  final List<String> actions = [];

  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  bool get blanked => actions.contains('load:about:blank');

  @override
  Future<void> stop() async {
    actions.add('stop');
  }

  @override
  Future<void> load(String url) async => actions.add('load:$url');

  // Interface boilerplate the guard never touches.
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
  Future<void> goBack() async {}
  @override
  Future<void> goForward() async {}
  @override
  Future<void> goHome() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<dynamic> evaluate(String script) async => null;
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
    void Function(WebSelection selection)? listener,
  ) async {}
  @override
  Future<void> clearSelection() async {}
  @override
  Future<void> selectAllInPage() async {}
  @override
  Future<void> setDownloadListener(
    void Function(String url, String? mimeType)? listener,
  ) async {}
  @override
  void addJsHandler(String name, JsHandlerCallback handler) {}
  @override
  void removeJsHandler(String name) {}
  @override
  Widget buildView() => const SizedBox.shrink();
  @override
  Future<void> dispose() async {
    _currentUrl.dispose();
    _currentTitle.dispose();
    _lastError.dispose();
    _progress.dispose();
    _canGoBack.dispose();
    _canGoForward.dispose();
    _isLoading.dispose();
  }
}

void main() {
  test('a failed probe pauses engines and marks the guard offline', () async {
    final guard = WebViewOfflineGuard.test()..probeOverride = () async => false;
    final visible = FakeEngine();
    final headless = FakeEngine();
    guard.watch(visible, OfflinePauseBehavior.userView);
    guard.watch(headless, OfflinePauseBehavior.headless);

    await guard.tick();

    expect(guard.isOffline, isTrue);
    // Both engines abort in-flight loads…
    expect(visible.actions, contains('stop'));
    expect(headless.actions, contains('stop'));
    // …but only the background engine is parked on about:blank.
    expect(visible.blanked, isFalse);
    expect(headless.blanked, isTrue);
  });

  test('two successful probes restore the guard to online', () async {
    var next = false;
    final guard = WebViewOfflineGuard.test()..probeOverride = () async => next;

    next = false;
    await guard.tick();
    expect(guard.isOffline, isTrue);

    // The first successful tick after the outage only preps recovery…
    next = true;
    await guard.tick();
    expect(guard.isOffline, isTrue);
    // …the second consecutive one confirms it.
    await guard.tick();
    expect(guard.isOffline, isFalse);
  });

  test('a failed probe while already offline does nothing new', () async {
    final guard = WebViewOfflineGuard.test()..probeOverride = () async => false;
    final engine = FakeEngine();
    guard.watch(engine, OfflinePauseBehavior.headless);

    await guard.tick();
    final afterFirst = List.of(engine.actions);
    await guard.tick();
    expect(engine.actions, afterFirst);
  });

  test('an engine registered during an outage is paused immediately',
      () async {
    final guard = WebViewOfflineGuard.test()..probeOverride = () async => false;
    await guard.tick();
    expect(guard.isOffline, isTrue);

    final engine = FakeEngine();
    guard.watch(engine, OfflinePauseBehavior.headless);
    // The immediate pause is fire-and-forget; give it a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(engine.actions, contains('stop'));
    expect(engine.blanked, isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('unwatched engines are left alone', () async {
    final guard = WebViewOfflineGuard.test()..probeOverride = () async => false;
    final engine = FakeEngine();
    guard.watch(engine, OfflinePauseBehavior.headless);
    guard.unwatch(engine);

    await guard.tick();

    expect(engine.actions, isEmpty);
    expect(guard.isOffline, isTrue);
  });
}
