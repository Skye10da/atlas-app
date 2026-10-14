import 'dart:convert';

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
  final List<String> evaluated = [];
  List<dynamic> cannedArgs = const [
    '{"b":"<html>from-background</html>","s":200,"u":"https://novelfull.net/"}',
  ];

  /// When set, each `evaluate` call fires handlers with a *fresh* argument list
  /// (for challenge-retry scenarios where the page content changes per attempt).
  List<dynamic> Function()? cannedArgsBuilder;

  /// Returned by `evaluate('document.documentElement.outerHTML')` — i.e. the
  /// DOM of whatever the view is currently showing. Null means "no DOM
  /// available", which is what a navigated view returns when the capture is not
  /// what a test is about.
  String? domHtml;

  /// What the in-page fetch's bridge probe reports. `'ok'` means
  /// `window.flutter_inappwebview.callHandler` exists, so the fetch result can
  /// come back; `'no-bridge'` means it cannot.
  String probeResult = 'ok';

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
    evaluated.add(script);
    if (script.contains('document.documentElement.outerHTML')) {
      return domHtml;
    }
    // The probe rides out on the same evaluate that starts the fetch, so both
    // the probe value and the handler call-back have to happen.
    final isProbe = script.contains('no-bridge');
    final args = cannedArgsBuilder != null ? cannedArgsBuilder!() : cannedArgs;
    for (final entry in handlers.entries) {
      if (script.contains('"${entry.key}"')) {
        entry.value(List<dynamic>.from(args));
      }
    }
    return isProbe ? probeResult : null;
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
  FakeSessionStore([this.cookies = const []]) : capturedOrigins = <Uri>[];

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
  final chapter = Uri.parse(
    'https://novelfull.net/legend-of-swordsman/chapter-1.html',
  );
  final other = Uri.parse('https://readnovelfull.com/novel.html');

  group('SilentWebViewService', () {
    test(
      'engages the background web view on every platform, including Windows',
      () async {
        // Regression: the service used to short-circuit with
        // `if (Platform.isWindows) return null` before touching the pool, which
        // left Windows with no automatic Cloudflare recovery at all — the
        // transport stack latched the failure and nothing solved the challenge.
        // `HeadlessWebEngine` handles the COM-init race internally, so the pool
        // must always be reachable.
        final engine = FakeBackgroundEngine();
        final service = SilentWebViewService(engine: engine);

        final result = await service.fetchHtml(chapter);

        expect(result?.body, '<html>from-background</html>');
        expect(
          engine.loadedUrls,
          [originRoot],
          reason: 'the origin is navigated even on Windows',
        );
      },
    );

    test('serves a same-origin fetch without navigating', () async {
      final engine = FakeBackgroundEngine().._currentUrl.value = originRoot;
      final service = SilentWebViewService(engine: engine);

      final html = await service.fetchHtml(chapter);

      expect(html?.body, '<html>from-background</html>');
      expect(engine.loadedUrls, isEmpty);
    });

    test('navigates to the origin root on an origin miss, then serves the '
        'fetch', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      final html = await service.fetchHtml(chapter);

      expect(html?.body, '<html>from-background</html>');
      expect(engine.loadedUrls, [originRoot]);
      expect(engine.currentUrl.value, originRoot);
    });

    test(
      'does not re-navigate once the background view is on the origin',
      () async {
        final engine = FakeBackgroundEngine();
        final service = SilentWebViewService(engine: engine);

        await service.fetchHtml(chapter);
        final second = await service.fetchHtml(
          Uri.parse('https://novelfull.net/chapter-2.html'),
        );

        expect(second?.body, '<html>from-background</html>');
        expect(
          engine.loadedUrls,
          [originRoot],
          reason: 'second fetch is same-origin -> no extra navigation',
        );
      },
    );

    test(
      'serves a same-origin JSON POST through the background view',
      () async {
        final engine = FakeBackgroundEngine();
        final service = SilentWebViewService(engine: engine);
        final reader = Uri.parse('https://wtr-lab.com/api/reader/get');

        final result = await service.fetchHtml(
          reader,
          method: 'POST',
          jsonBody: {'raw_id': 29058, 'chapter_no': 639},
        );

        expect(result?.body, '<html>from-background</html>');
        expect(
          engine.loadedUrls,
          ['https://wtr-lab.com/'],
          reason: 'the background view syncs to the API origin first',
        );
        expect(engine.evaluated, isNotEmpty);
        final script = engine.evaluated.single;
        expect(script, contains('"POST"'));
        expect(script, contains('raw_id'));
        expect(script, contains('29058'));
        expect(script, contains('chapter_no'));
        expect(script, contains('639'));
      },
    );

    test('returns null for a non-servable URL without navigating', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      expect(await service.fetchHtml(Uri.parse('about:blank')), isNull);
      expect(engine.loadedUrls, isEmpty);
    });

    test(
      'retries through a Cloudflare challenge page before returning',
      () async {
        final engine = FakeBackgroundEngine();
        final sleeps = <Duration>[];
        final service = SilentWebViewService(
          engine: engine,
          sleep: (d) async => sleeps.add(d),
          challengeRetryDelay: const Duration(milliseconds: 5),
          maxChallengeRetries: 3,
        );
        const challenge =
            '<html><head><title>Just a moment...</title></head>'
            '<body class="challenge-platform">cf_chl</body></html>';

        // First attempt returns the challenge; subsequent attempts return the page.
        var calls = 0;
        engine.cannedArgsBuilder = () => [
          (++calls == 1)
              ? '{"b":${jsonEncode(challenge)},'
                    '"s":403,"u":"https://novelfull.net/"}'
              : '{"b":${jsonEncode('<html>real-chapter</html>')},'
                    '"s":200,"u":"https://novelfull.net/"}',
        ];
        final html = await service.fetchHtml(chapter);

        expect(html?.body, '<html>real-chapter</html>');
        expect(sleeps, isNotEmpty, reason: 'waited between challenge retries');
      },
    );

    test(
      'escalates a challenged in-page fetch to a real navigation of the target',
      () async {
        // A chapter page is not a `/novel/` path, so it is first requested as an
        // in-page `fetch()` from the origin root. When Cloudflare refuses that
        // XHR, re-issuing it can only fail again — the challenge has to be run
        // in a document. So the service navigates the view to the chapter URL
        // itself and serves the rendered DOM. This is the path the reader's
        // chapter download depends on.
        final engine = FakeBackgroundEngine();
        final service = SilentWebViewService(
          engine: engine,
          sleep: (_) async {},
          challengeRetryDelay: const Duration(milliseconds: 1),
          maxChallengeRetries: 1,
        );
        const challengeBody =
            '<html><head><title>Just a moment...</title></head>'
            '<body class="challenge-platform">cf_chl</body></html>';
        engine.cannedArgs = [
          '{"b":${jsonEncode(challengeBody)},"s":403,"u":"$chapter"}',
        ];
        engine.domHtml = '<html><body>Chapter one text</body></html>';

        final html = await service.fetchHtml(chapter);

        expect(html?.body, '<html><body>Chapter one text</body></html>');
        expect(
          engine.loadedUrls,
          [originRoot, '$chapter'],
          reason: 'the challenged target is navigated directly',
        );
      },
    );

    test(
      'fails fast without waiting on the timeout when the page has no JS bridge',
      () async {
        // A headless view with no `window.flutter_inappwebview` can never deliver
        // the fetch result. Before this probe the fetcher sat on its full 45s
        // timeout on every attempt (and every chapter), logging the same opaque
        // "returned null" as a genuine challenge.
        final engine = FakeBackgroundEngine()..probeResult = 'no-bridge';
        // One attempt only, so this measures the probe rather than the retry
        // delay between attempts.
        final service = SilentWebViewService(
          engine: engine,
          maxChallengeRetries: 0,
        );

        final sw = Stopwatch()..start();
        final html = await service.fetchHtml(chapter);
        sw.stop();

        expect(html, isNull);
        expect(
          sw.elapsed,
          lessThan(const Duration(seconds: 5)),
          reason: 'a missing bridge is detected from the probe, not by waiting '
              'out the fetch timeout',
        );
        expect(
          engine.evaluated.where((s) => s.contains('no-bridge')),
          isNotEmpty,
          reason: 'the fetch is never issued when the bridge is absent',
        );
      },
    );

    test(
      'falls back to navigating the target when the in-page fetch never '
      'returns a result at all',
      () async {
        // `pageFetcher returned null` covers a missing JS bridge, an undecodable
        // payload and an expired timeout alike. None of those should be allowed
        // to fail the request outright: navigating the target and reading the
        // DOM needs only `evaluateJavascript`, so it still serves the chapter.
        // This is the path the reader's chapter download depends on.
        final engine = FakeBackgroundEngine();
        final service = SilentWebViewService(
          engine: engine,
          sleep: (_) async {},
          challengeRetryDelay: const Duration(milliseconds: 1),
          maxChallengeRetries: 0,
        );
        engine.domHtml = '<html><body>Chapter one text</body></html>';
        // Empty arg list = the handler fires but hands back nothing usable,
        // which is what a broken round trip looks like from here.
        engine.cannedArgs = const [];

        final html = await service.fetchHtml(chapter);

        expect(html?.body, '<html><body>Chapter one text</body></html>');
        expect(
          engine.loadedUrls,
          [originRoot, '$chapter'],
          reason: 'the target is navigated directly when the fetch comes back '
              'empty',
        );
      },
    );

    test('gives up on an unresolved challenge and returns null', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(
        engine: engine,
        sleep: (_) async {},
        maxChallengeRetries: 2,
      );
      engine.cannedArgs = [
        '{"b":"<html><head><title>Just a moment...</title></head></html>",'
            '"s":403,"u":"https://novelfull.net/"}',
      ];

      expect(await service.fetchHtml(chapter), isNull);
    });

    test(
      'gives up immediately on an auth wall without challenge retries',
      () async {
        final engine = FakeBackgroundEngine().._currentUrl.value = originRoot;
        final sleeps = <Duration>[];
        final service = SilentWebViewService(
          engine: engine,
          sleep: (d) async => sleeps.add(d),
          challengeRetryDelay: const Duration(milliseconds: 5),
        );
        engine.cannedArgs = const [
          '{"b":"<html>sign in</html>","s":401,"u":"https://novelfull.net/login"}',
        ];

        expect(await service.fetchHtml(chapter), isNull);
        expect(
          sleeps,
          isEmpty,
          reason: 'an auth wall is not a passable challenge -> no retries',
        );
      },
    );

    test('persists a fresh solve back into the session store', () async {
      final engine = FakeBackgroundEngine().._currentUrl.value = originRoot;
      final store = FakeSessionStore();
      final service = SilentWebViewService(engine: engine, sessionStore: store);

      await service.fetchHtml(chapter);

      expect(store.capturedOrigins, [Uri.parse(originRoot)]);
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
        loadBehavior: LoadBehavior.throwOnLoad,
      );
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

      expect(seeded, [
        Uri.parse(originRoot),
      ], reason: 'session is seeded for the navigated origin');
    });

    test('serializes concurrent cross-origin navigations', () async {
      final engine = FakeBackgroundEngine();
      final service = SilentWebViewService(engine: engine);

      final a = service.fetchHtml(chapter);
      final b = service.fetchHtml(other);

      expect((await a)?.body, '<html>from-background</html>');
      expect((await b)?.body, '<html>from-background</html>');
      // Both origins navigated, in request order, never interleaved.
      expect(engine.loadedUrls, [originRoot, 'https://readnovelfull.com/']);
    });
  });
}
