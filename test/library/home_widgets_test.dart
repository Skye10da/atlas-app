import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';
import 'package:atlas_app/library/presentation/widgets/home/continue_hero_card.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_controls_row.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_status_tabs.dart';
import 'package:atlas_app/library/presentation/widgets/home/weekly_activity_dots.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Report with a populated week so the hero + weekly rows are built:
/// 7 days, 0..6 chapters each, today (Sunday) read 6 chapters for 72 minutes.
ReadingAnalyticsReport _report() => ReadingAnalyticsReport(
  totalBooks: 3,
  totalChaptersRead: 40,
  totalReadingSeconds: 3600,
  currentStreak: 23,
  longestStreak: 23,
  weeklyActivity: [
    for (var i = 0; i < 7; i++)
      ReadingDayActivity(
        dayLabel: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
        date: DateTime(2026, 1, 5 + i),
        chaptersRead: i,
        readingMinutes: i * 12,
        isToday: i == 6,
      ),
  ],
  monthlyDailyActivity: const [],
  weeklyGoal: ReadingGoalEntity.initial(),
  timeOfDay: const ReadingTimeOfDayBreakdown(
    morningMinutes: 10,
    afternoonMinutes: 20,
    eveningMinutes: 30,
    nightMinutes: 40,
  ),
  genreStats: const [],
  formatRatio: const FormatReadRatio(
    novelMinutes: 60,
    bookMinutes: 40,
    novelChapters: 6,
    bookChapters: 4,
  ),
  recentSessions: const [],
  averagePaceMinutesPerChapter: 3.5,
);

/// Collects every exception raised so far, so one error does not hide another.
List<Object> _drainExceptions(WidgetTester tester) {
  final errors = <Object>[];
  while (true) {
    final error = tester.takeException();
    if (error == null) return errors;
    errors.add(error);
  }
}

BookEntity _book() => BookEntity(
  id: 'n1',
  title: "Villain's Path: Transmigrated with an SSS+ Luck Stat",
  author: 'A thought of storm',
  format: 'epub',
  totalChapters: 2164,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  progress: 0.99,
  lastOpenedAt: DateTime(2026, 1, 2),
);

/// A two-day week ending today lets every weekly widget show numerals.
List<ReadingDayActivity> _twoDayWeek() => [
  ReadingDayActivity(
    dayLabel: 'M',
    date: DateTime(2026, 4, 6),
    chaptersRead: 2,
    readingMinutes: 30,
    isToday: false,
  ),
  ReadingDayActivity(
    dayLabel: 'T',
    date: DateTime(2026, 4, 7),
    chaptersRead: 1,
    readingMinutes: 15,
    isToday: true,
  ),
];

/// One-day week where only today is active (14 chapters, 45 minutes).
List<ReadingDayActivity> _singleTodayWeek() => [
  ReadingDayActivity(
    dayLabel: 'T',
    date: DateTime(2026, 4, 7),
    chaptersRead: 14,
    readingMinutes: 45,
    isToday: true,
  ),
];

void main() {
  group('LibraryStatusTabs', () {
    testWidgets('renders every shelf bucket', (tester) async {
      await tester.pumpWidget(
        _host(
          LibraryStatusTabs(
            selected: LibraryStatusFilter.all,
            onSelected: (_) {},
          ),
        ),
      );

      for (final filter in LibraryStatusFilter.values) {
        expect(find.text(filter.label), findsOneWidget);
      }
    });

    testWidgets('reports taps with the tapped bucket', (tester) async {
      LibraryStatusFilter? tapped;
      await tester.pumpWidget(
        _host(
          LibraryStatusTabs(
            selected: LibraryStatusFilter.all,
            onSelected: (filter) => tapped = filter,
          ),
        ),
      );

      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      expect(tapped, LibraryStatusFilter.finished);
    });

    testWidgets('shows the update badge only when there are updates', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LibraryStatusTabs(
            selected: LibraryStatusFilter.all,
            onSelected: (_) {},
            updatedCount: 3,
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          LibraryStatusTabs(
            selected: LibraryStatusFilter.all,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
    });
  });

  group('WeeklyActivityDots (card)', () {
    testWidgets('renders dots with the This week numerals', (tester) async {
      await tester.pumpWidget(
        _host(
          WeeklyActivityDots(
            weeklyActivity: _twoDayWeek(),
            totalChapters: 3,
          ),
        ),
      );

      expect(find.text('Mon'), findsNothing); // strip uses day labels verbatim
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // chapters today numeral
      expect(find.text('chapter today'), findsOneWidget); // today reads 1
      expect(find.text('3'), findsOneWidget); // week total numeral
      expect(find.text('this week'), findsOneWidget);
      expect(_drainExceptions(tester), isEmpty);
    });

    testWidgets('collapses to nothing when there is no activity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WeeklyActivityDots(weeklyActivity: [], totalChapters: 0),
        ),
      );

      expect(find.text('This week'), findsNothing);
    });

    testWidgets('is tappable when a callback is supplied', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          WeeklyActivityDots(
            weeklyActivity: _singleTodayWeek(),
            totalChapters: 14,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('WeeklyActivityStrip (inline)', () {
    testWidgets('shows the chapters-today numeral without a card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          WeeklyActivityStrip(weeklyActivity: _singleTodayWeek()),
        ),
      );

      expect(find.text('14'), findsOneWidget);
      expect(find.text('chapters today'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('This week'), findsNothing);
      expect(find.text('this week'), findsNothing);
      expect(_drainExceptions(tester), isEmpty);
    });

    testWidgets('dots + numerals fit a very narrow strip', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 192,
            child: WeeklyActivityStrip(weeklyActivity: _singleTodayWeek()),
          ),
        ),
      );

      expect(_drainExceptions(tester), isEmpty);
    });
  });

  group('ContinueHeroCard', () {
    testWidgets('renders the dark card with a Resume pill', (tester) async {
      var resumed = false;
      await tester.pumpWidget(
        _host(
          ContinueHeroCard(
            book: _book(),
            onContinue: () => resumed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('99%'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(resumed, isTrue);
    });

    testWidgets('shows the author line', (tester) async {
      await tester.pumpWidget(_host(ContinueHeroCard(book: _book())));
      await tester.pumpAndSettle();

      expect(find.text('A thought of storm'), findsOneWidget);
      expect(_drainExceptions(tester), isEmpty);
    });

    testWidgets('falls back to a placeholder without a book', (tester) async {
      await tester.pumpWidget(
        _host(const ContinueHeroCard(book: null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE'), findsNothing);
      expect(find.textContaining('Nothing in progress'), findsOneWidget);
    });
  });

  group('LibraryControlsRow', () {
    testWidgets('renders the category toggle and circle buttons on mobile', (
      tester,
    ) async {
      var toggled = false;
      var checked = 0;

      final db = AppDatabase.memory();
      addTearDown(db.close);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: LibraryControlsRow(
                  wide: false,
                  inlineSearch: false,
                  searchActive: false,
                  onToggleSearch: () => toggled = true,
                  onCheckUpdates: () => checked++,
                  searchController: controller,
                  searchFocusNode: focus,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Novels'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);

      await tester.tap(find.byTooltip('Search library'));
      await tester.pump();
      expect(toggled, isTrue);

      await tester.tap(find.byTooltip('Check ongoing novels for updates'));
      await tester.pump();
      expect(checked, 1);

      // Unmount + drain so the database's background timers don't leak
      // into the test's end-of-run invariant check.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Library home composition', () {
    testWidgets(
      'desktop: hero and the insights weekly card render without crashing',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.memory();
        addTearDown(db.close);
        await db
            .into(db.books)
            .insert(
              BooksCompanion(
                id: const Value('n1'),
                title: const Value('Solo Leveling'),
                author: const Value('Chugong'),
                format: const Value('epub'),
                itemType: Value(ContentCategory.novel.name),
                filePath: const Value('/fake/path'),
                totalChapters: const Value(10),
                createdAt: Value(DateTime(2026, 1, 1)),
                updatedAt: Value(DateTime(2026, 1, 1)),
                lastOpenedAt: Value(DateTime(2026, 1, 2)),
              ),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              readingAnalyticsReportProvider.overrideWith((ref) => _report()),
            ],
            child: const MaterialApp(home: LibraryScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Both halves of the desktop layout rendered together — the
        // regression case.
        expect(find.text('CONTINUE'), findsOneWidget);
        expect(find.text('This week'), findsOneWidget);
        expect(_drainExceptions(tester), isEmpty);

        // Unmount + drain so the database's background timers don't leak
        // into the test's end-of-run invariant check.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets('tablet: hero row with the 280px weekly card fits', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(834, 1112);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db
          .into(db.books)
          .insert(
            BooksCompanion(
              id: const Value('n1'),
              title: const Value('Solo Leveling'),
              author: const Value('Chugong'),
              format: const Value('epub'),
              itemType: Value(ContentCategory.novel.name),
              filePath: const Value('/fake/path'),
              totalChapters: const Value(10),
              createdAt: Value(DateTime(2026, 1, 1)),
              updatedAt: Value(DateTime(2026, 1, 1)),
              lastOpenedAt: Value(DateTime(2026, 1, 2)),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            readingAnalyticsReportProvider.overrideWith((ref) => _report()),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('Chugong'), findsWidgets); // hero + book card author
      expect(find.text('This week'), findsOneWidget);
      expect(_drainExceptions(tester), isEmpty);

      // Unmount + drain so the database's background timers don't leak
      // into the test's end-of-run invariant check.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('mobile: inline stats strip and hero fit 390px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db
          .into(db.books)
          .insert(
            BooksCompanion(
              id: const Value('n1'),
              title: const Value('Solo Leveling'),
              author: const Value('Chugong'),
              format: const Value('epub'),
              itemType: Value(ContentCategory.novel.name),
              filePath: const Value('/fake/path'),
              totalChapters: const Value(10),
              createdAt: Value(DateTime(2026, 1, 1)),
              updatedAt: Value(DateTime(2026, 1, 1)),
              lastOpenedAt: Value(DateTime(2026, 1, 2)),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            readingAnalyticsReportProvider.overrideWith((ref) => _report()),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // chapters-today numeral
      expect(find.text('chapters today'), findsOneWidget);
      expect(_drainExceptions(tester), isEmpty);

      // Unmount + drain so the database's background timers don't leak
      // into the test's end-of-run invariant check.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
