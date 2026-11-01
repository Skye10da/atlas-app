import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/design_system/molecules/app_toast.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/batch_download_sheet.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

const _origin = 'https://novelfull.net/';

BookEntity _book() => BookEntity(
  id: 'book-1',
  title: 'Legend of the Swordsman',
  format: 'txt',
  totalChapters: 3,
  sourceName: 'NovelFull',
  sourceId: 'novelfull',
  sourceUrl: '$_origin/legend-of-swordsman.html',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

List<ChapterEntity> _chapters(int count) => List.generate(
  count,
  (i) => ChapterEntity(
    id: 'ch-$i',
    bookId: 'book-1',
    index: i,
    title: 'Chapter ${i + 1}',
    contentPath: '/fake/ch-$i.txt',
    totalChapters: count,
  ),
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

  Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Opens the sheet the way the app does — a modal bottom sheet over a host
  /// scaffold, so a dismissal pops back to a live tree.
  Future<void> pumpSheet(
    WidgetTester tester,
    ChapterDownloadService service,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chapterDownloadServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BatchDownloadSheet.show(
                  context,
                  book: _book(),
                  chapters: _chapters(3),
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

  group('BatchDownloadSheet bot-check recovery', () {
    testWidgets(
      'a bot-check failure keeps the sheet open and offers re-verify + retry',
      (tester) async {
        final service = _FakeDownloadService(failAll: true);
        // The transport stack latches the blocked origin before the failure
        // surfaces; the sheet keys off that latch to recognise a bot check.
        session.markInvalid(Uri.parse(_origin));

        await pumpSheet(tester, service);
        await tester.tap(find.text('All Remaining (3 chs)'));
        await pumpFrames(tester);

        expect(
          find.text('3 chapters blocked by a bot check.'),
          findsOneWidget,
        );
        expect(find.text('Re-verify session & retry'), findsOneWidget);
        expect(
          find.text('Downloaded 3 chapters successfully.'),
          findsNothing,
          reason: 'failures are never reported as a successful download',
        );
      },
    );

    testWidgets(
      're-verify re-runs only the failed chapters',
      (tester) async {
        final service = _FakeDownloadService(failAll: true);
        session.markInvalid(Uri.parse(_origin));
        var requests = 0;
        session.driver = (request) async {
          requests++;
          return true;
        };

        await pumpSheet(tester, service);
        await tester.tap(find.text('All Remaining (3 chs)'));
        await pumpFrames(tester);
        expect(service.attempted, [0, 1, 2]);

        // The bot check is gone now — the retry should succeed.
        service.failAll = false;
        await tester.tap(find.text('Re-verify session & retry'));
        await pumpFrames(tester);

        expect(requests, 1, reason: 'one re-verify per recovery');
        expect(
          service.attempted,
          [0, 1, 2, 0, 1, 2],
          reason: 'only the previously failed chapters are retried',
        );
      },
    );

    testWidgets(
      'a plain fetch failure reports the count without a re-verify offer',
      (tester) async {
        final service = _FakeDownloadService(failAll: true);
        // No origin latched — the failure is not a recognised bot check.

        await pumpSheet(tester, service);
        await tester.tap(find.text('All Remaining (3 chs)'));
        await pumpFrames(tester);

        expect(find.text('Failed to download 3 chapters.'), findsOneWidget);
        expect(find.text('Re-verify session & retry'), findsNothing);
      },
    );
  });
}

/// Stands in for [ChapterDownloadService] — the sheet only calls
/// `downloadChapter` on this path.
class _FakeDownloadService implements ChapterDownloadService {
  _FakeDownloadService({required this.failAll});

  bool failAll;

  /// Chapter indices in the order they were requested.
  final attempted = <int>[];

  @override
  Future<Result<void>> downloadChapter(
    String bookId,
    int chapterIndex, {
    String? targetLanguage,
    bool force = false,
  }) async {
    attempted.add(chapterIndex);
    if (failAll) {
      return const Failure(NetworkException('blocked'));
    }
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}