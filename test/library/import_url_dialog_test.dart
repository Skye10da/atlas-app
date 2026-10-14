import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

const _novelUrl = 'https://novelfull.net/legend-of-swordsman.html';

/// The message `HttpTransport` produces for a Cloudflare bot-check, wrapped the
/// way `ImportService` wraps a failed fetch.
String _botCheckMessage() =>
    'Import failed for "$_novelUrl": TransportException: novelfull.net blocked '
    'this request with a bot-check challenge (Cloudflare). That site does not '
    'allow automated imports, so Atlas cannot fetch it with a plain HTTP client '
    '— try another source.';

NovelModel _novel() => const NovelModel(
  title: 'Legend of the Swordsman',
  author: 'Author',
  source: 'NovelFull',
  sourceId: 'novelfull',
  sourceUrl: _novelUrl,
  category: ContentCategory.novel,
);

void main() {
  final session = SessionRefreshService.instance;

  setUp(() {
    session.clearInvalid();
    session.driver = null;
  });

  tearDown(() {
    session.clearInvalid();
    session.driver = null;
  });

  /// Pumps a fixed number of frames. The sheet drives a repeating progress
  /// animation, so `pumpAndSettle` never settles — drive the clock instead.
  Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Opens the sheet with [initialUrl] prefilled, backed by an engine whose
  /// metadata fetch behaves as [onFetch].
  Future<void> pumpSheet(
    WidgetTester tester, {
    required Future<NovelModel> Function(Uri url) onFetch,
  }) async {
    final engine = _FakeEngine(onFetch);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentAcquisitionEngineProvider.overrideWithValue(engine)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showImportUrlSheet(
                  context,
                  initialUrl: _novelUrl,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpFrames(tester);
  }

  group('ImportUrlSheet Cloudflare recovery', () {
    testWidgets(
      'a bot-check failure opens the re-verify screen, then retries the fetch',
      (tester) async {
        var fetchCount = 0;
        SessionRefreshRequest? seen;
        session.driver = (request) async {
          seen = request;
          return true;
        };

        await pumpSheet(
          tester,
          // First attempt is challenged; the retry (after re-verify) succeeds.
          onFetch: (_) async {
            fetchCount++;
            if (fetchCount == 1) {
              throw ImportException(_botCheckMessage());
            }
            return _novel();
          },
        );

        await tester.tap(find.text('Import'));
        await pumpFrames(tester);

        expect(seen, isNotNull, reason: 'the re-verify driver was invoked');
        expect(seen?.origin.toString(), 'https://novelfull.net/');
        expect(seen?.seedUrl.toString(), _novelUrl);
        expect(
          fetchCount,
          2,
          reason: 'the fetch is retried once re-verification succeeds',
        );
        expect(
          find.text('Legend of the Swordsman'),
          findsOneWidget,
          reason: 'the preview stage is reached after recovery',
        );
      },
    );

    testWidgets(
      'a cancelled re-verify leaves the error visible and does not retry',
      (tester) async {
        var fetchCount = 0;
        session.driver = (request) async => false;

        await pumpSheet(
          tester,
          onFetch: (_) async {
            fetchCount++;
            throw ImportException(_botCheckMessage());
          },
        );

        await tester.tap(find.text('Import'));
        await pumpFrames(tester);

        expect(find.textContaining('bot-check challenge'), findsOneWidget);
        expect(
          fetchCount,
          1,
          reason: 'a cancelled verification does not re-fetch',
        );
        expect(
          find.text('Re-verify session'),
          findsOneWidget,
          reason: 'the manual re-verify action stays available',
        );
      },
    );

    testWidgets(
      'the manual re-verify action retries after the one-shot auto gate',
      (tester) async {
        var fetchCount = 0;
        session.driver = (request) async => true;

        await pumpSheet(
          tester,
          onFetch: (_) async {
            fetchCount++;
            // Always challenged, so the retry itself cannot advance the sheet —
            // what this asserts is that a manual tap is still allowed to run
            // the re-verify flow after the automatic attempt consumed its gate.
            throw ImportException(_botCheckMessage());
          },
        );

        await tester.tap(find.text('Import'));
        await pumpFrames(tester);
        expect(
          fetchCount,
          2,
          reason: 'one automatic re-verify + retry, then no further auto pass',
        );

        await tester.tap(find.text('Re-verify session'));
        await pumpFrames(tester);

        expect(
          fetchCount,
          3,
          reason: 'the manual action bypasses the one-shot auto gate',
        );
      },
    );

    testWidgets('a non-challenge failure offers no re-verify action', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        onFetch: (_) async => throw const ImportException(
          'No source plugin available for: $_novelUrl',
        ),
      );

      await tester.tap(find.text('Import'));
      await pumpFrames(tester);

      expect(find.textContaining('No source plugin'), findsOneWidget);
      expect(find.text('Re-verify session'), findsNothing);
    });
  });
}

/// Stands in for [ContentAcquisitionEngine] — the sheet only uses
/// `fetchMetadata` on this path.
class _FakeEngine implements ContentAcquisitionEngine {
  _FakeEngine(this._onFetch);

  final Future<NovelModel> Function(Uri url) _onFetch;

  @override
  Future<NovelModel> fetchMetadata(String url) => _onFetch(Uri.parse(url));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}