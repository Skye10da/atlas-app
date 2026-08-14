import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/browser/domain/services/silent_web_view_service.dart';

/// Minimal [BrowserWebEngine] that stands in for the off-screen background
/// view: navigation records URLs and flaps [isLoading] like a real load, and
/// [evaluate] fires registered JS handlers (the in-page `fetch` bridge) with
/// configurable canned output.
class FakeBackgroundEngine implements BrowserWebEngine {
  FakeBackgroundEngine({this.loadBehavior = LoadBehavior.settle});

  /// settle: isLoading goes true then false after a microtask.
  /// stall: isLoading stays true forever (navigation never completes).
  /// throw: load() throws.
  final LoadBehavior loadBehavior;

  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  final List<String> loadedUrls = [];
  final Map<String, JsHandlerCallback> handlers = {};
  List<dynamic> cannedArgs = ['<html>from-background</html>'];

  /// When set, each `evaluate` call fires handlers with a *fresh* argument list
  /// (for challenge-retry scenarios where the page content changes per attempt).
  List<dynamic> Function()? cannedArgsBuilder;
  bool disposed = false;

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
    if (loadBehavior == LoadBehavior.throwOnLoad) {
      throw StateError('engine broken');
    }
    loadedUrls.add(url);
    _isLoading.value = true;
    await Future<void>.delayed(Duration.zero);
    if (loadBehavior == LoadBehavior.stall) return;
    _currentUrl.value = url;
    _isLoading.value = false;
  }

  @override
  Future<dynamic> evaluate(String script) async {
    final args = cannedArgsBuilder != null ? cannedArgsBuilder!() : cannedArgs;
    for (final entry in handlers.entries) {
      if (script.contains('"${entry.key}"')) {
        entry.value(List<dynamic>.from(args));
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
  }

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
  Widget buildView() => const SizedBox.shrink();

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

enum LoadBehavior { settle, stall, throwOnLoad }

class FakeSessionStore implements BrowserSessionRepositoryInterface {
  FakeSessionStore([this.cookies = const []])
      : capturedOrigins = <Uri>[];

  final List<BrowserSessionCookie> cookies;
  final List<Uri> capturedOrigins;

  @override
  Future<void> captureForOrigin(Uri origin) async {
    capturedOrigins.add(origin);
  }

  @override
  Future<List<BrowserSessionCookie>> loadForOrigin(Uri origin) async => cookies;
}

void main() {
  const originRoot = 'https://novelfull.net/';
  final chapter =
      Uri.parse('https://novelfull.net/legend-of-swordsman/chapter-1.html');
  final other = Uri.parse('https://readnovelfull.com/novel.html');

  group('SilentWebViewService', () {
    test('serves a same-origin fetch without navigating', () async {
      final engine = FakeBackgroundEngine()
        .._currentUrl.value = originRoot;
      final service = SilentWebViewService(engine: engine);

      final html = await service.fetchHtml(chapter);

      expect(html, '<html>from-background</html>');
      expect(engine.loadedUrls, isEmpty);
    });

    test('navigates to the origin root on an origin miss, then serves the '
        'fetch', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      final html = await service.fetchHtml(chapter);

      expect(html, '<html>from-background</html>');
      expect(engine.loadedUrls, [originRoot]);
      expect(engine.currentUrl.value, originRoot);
    });

    test('does not re-navigate once the background view is on the origin',
        () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      await service.fetchHtml(chapter);
      final second =
          await service.fetchHtml(Uri.parse('https://novelfull.net/chapter-2.html'));

      expect(second, '<html>from-background</html>');
      expect(engine.loadedUrls, [originRoot],
          reason: 'second fetch is same-origin -> no extra navigation');
    });

    test('returns null for a non-servable URL without navigating', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      expect(await service.fetchHtml(Uri.parse('about:blank')), isNull);
      expect(engine.loadedUrls, isEmpty);
    });

    test('retries through a Cloudflare challenge page before returning',
        () async {
      final engine = FakeBackgroundEngine();
      final sleeps = <Duration>[];
      final service = SilentWebViewService(
        engine: engine,
        sleep: (d) async => sleeps.add(d),
        challengeRetryDelay: const Duration(milliseconds: 5),
        maxChallengeRetries: 3,
      );
      const challenge = '<html><head><title>Just a moment...</title></head>'
          '<body class="challenge-platform">cf_chl</body></html>';

      // First attempt returns the challenge; subsequent attempts return the page.
      var calls = 0;
      engine.cannedArgsBuilder = () =>
          [(++calls == 1) ? challenge : '<html>real-chapter</html>'];
      final html = await service.fetchHtml(chapter);

      expect(html, '<html>real-chapter</html>');
      expect(sleeps, isNotEmpty, reason: 'waited between challenge retries');
    });

    test('gives up on an unresolved challenge and returns null', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(
        engine: engine,
        sleep: (_) async {},
        maxChallengeRetries: 2,
      );
      engine.cannedArgs = [
        '<html><head><title>Just a moment...</title></head></html>'
      ];

      expect(await service.fetchHtml(chapter), isNull);
    });

    test('returns null when the navigation never settles', () async {
      final engine = FakeBackgroundEngine(loadBehavior: LoadBehavior.stall);
      final service = SilentWebViewService(
        engine: engine,
        navigationTimeout: const Duration(milliseconds: 20),
      );

      expect(await service.fetchHtml(chapter), isNull);
    });

    test('returns null when the engine load throws', () async {
      final engine = FakeBackgroundEngine(
          loadBehavior: LoadBehavior.throwOnLoad);
      final service = SilentWebViewService(engine: engine);

      expect(await service.fetchHtml(chapter), isNull);
    });

    test('seeds the saved session cookies before navigating', () async {
      final engine = FakeBackgroundEngine();
      final store = FakeSessionStore([
        const BrowserSessionCookie(name: 'cf_clearance', value: 'abc'),
      ]);
      final seeded = <Uri>[];
      final service = SilentWebViewService(
        engine: engine,
        sessionStore: store,
        seeder: (origin, cookies) async {
          seeded.add(origin);
          expect(cookies.single.name, 'cf_clearance');
        },
      );

      await service.fetchHtml(chapter);

      expect(seeded, [Uri.parse(originRoot)],
          reason: 'session is seeded for the navigated origin');
    });

    test('serializes concurrent cross-origin navigations', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      final a = service.fetchHtml(chapter);
      final b = service.fetchHtml(other);

      expect(await a, '<html>from-background</html>');
      expect(await b, '<html>from-background</html>');
      // Both origins navigated, in request order, never interleaved.
      expect(engine.loadedUrls, [originRoot, 'https://readnovelfull.com/']);
    });
  });
}
