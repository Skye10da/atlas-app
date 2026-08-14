import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/browser/presentation/screens/session_refresh_screen.dart';

class _FakeRefreshEngine implements BrowserWebEngine {
  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);
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
  Future<void> load(String url) async {}
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
      void Function(WebSelection selection)? listener) async {}
  @override
  Future<void> clearSelection() async {}
  @override
  Future<void> selectAllInPage() async {}
  @override
  Future<void> setDownloadListener(
      void Function(String url, String? mimeType)? listener) async {}
  @override
  void addJsHandler(String name, JsHandlerCallback handler) {}
  @override
  void removeJsHandler(String name) {}
  @override
  Widget buildView() => const SizedBox.expand();
  @override
  void dispose() {
    disposed = true;
    for (final n in <ValueNotifier<Object?>>[
      _currentUrl,
      _currentTitle,
      _lastError,
      _progress,
      _canGoBack,
      _canGoForward,
      _isLoading,
    ]) {
      n.dispose();
    }
  }
}

class _CapturingStore implements BrowserSessionRepositoryInterface {
  final List<Uri> capturedOrigins = [];

  @override
  Future<void> captureForOrigin(Uri origin) async {
    capturedOrigins.add(origin);
  }

  @override
  Future<List<BrowserSessionCookie>> loadForOrigin(Uri origin) async => const [];
}

void main() {
  const origin = 'https://novelfull.net/';
  final seed = Uri.parse('https://novelfull.net/the-99th-divorce.html');

  /// Pushes [screen] on a Navigator and returns a notifier populated with the
  /// route's pop result.
  Future<ValueNotifier<bool?>> pumpAndPush(
    WidgetTester tester,
    SessionRefreshScreen screen,
  ) async {
    final result = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(builder: (_) => screen),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    // Bounded pumps: pumpAndSettle would never settle while the screen's
    // indeterminate spinner keeps scheduling frames.
    await tester.pump(const Duration(milliseconds: 600));
    return result;
  }

  group('SessionRefreshScreen', () {
    testWidgets('seeds the webview at the source URL and waits for '
        'verification', (tester) async {
      final engine = _FakeRefreshEngine();
      String? seeded;

      await tester.pumpWidget(
        MaterialApp(
          home: SessionRefreshScreen(
            origin: Uri.parse(origin),
            seedUrl: seed,
            engineFactory: ({String? initialUrl}) {
              seeded = initialUrl;
              return engine;
            },
            cookieProbe: (_) async => false,
            pollInterval: const Duration(seconds: 1),
          ),
        ),
      );
      await tester.pump();

      expect(seeded, seed.toString());
      expect(find.text('Waiting for verification…'), findsOneWidget);
    });

    testWidgets('pops with true and captures the fresh session once verified',
        (tester) async {
      final engine = _FakeRefreshEngine();
      final store = _CapturingStore();
      var verified = false;
      final result = await pumpAndPush(
        tester,
        SessionRefreshScreen(
          origin: Uri.parse(origin),
          seedUrl: seed,
          engineFactory: ({String? initialUrl}) => engine,
          sessionStore: store,
          cookieProbe: (_) async => verified,
          pollInterval: const Duration(milliseconds: 10),
        ),
      );

      verified = true;
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(result.value, isTrue);
      expect(store.capturedOrigins, [Uri.parse(origin)]);
      expect(engine.disposed, isTrue,
          reason: 'the quick view is torn down after verification');
    });

    testWidgets('times out and offers retry / cancel', (tester) async {
      final engine = _FakeRefreshEngine();
      final result = await pumpAndPush(
        tester,
        SessionRefreshScreen(
          origin: Uri.parse(origin),
          seedUrl: seed,
          engineFactory: ({String? initialUrl}) => engine,
          cookieProbe: (_) async => false,
          timeout: const Duration(milliseconds: 20),
          pollInterval: const Duration(milliseconds: 1),
        ),
      );

      // The 20ms timeout fires while the route settles; the view is now in its
      // timed-out state.
      expect(find.text('Verification timed out.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(result.value, isFalse);
    });

    testWidgets('closing the view cancels the flow', (tester) async {
      final engine = _FakeRefreshEngine();
      final result = await pumpAndPush(
        tester,
        SessionRefreshScreen(
          origin: Uri.parse(origin),
          seedUrl: seed,
          engineFactory: ({String? initialUrl}) => engine,
          cookieProbe: (_) async => false,
          pollInterval: const Duration(seconds: 1),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(result.value, isFalse);
      expect(engine.disposed, isTrue);
    });
  });
}