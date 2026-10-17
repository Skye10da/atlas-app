import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/library/presentation/view_models/library_state.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_status_tabs.dart';
import 'package:atlas_app/library/presentation/widgets/home/weekly_activity_dots.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

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

  group('WeeklyActivityDots', () {
    testWidgets('renders one dot per day with a chapter total', (tester) async {
      await tester.pumpWidget(
        _host(
          WeeklyActivityDots(
            weeklyActivity: [
              ReadingDayActivity(
                dayLabel: 'Mon',
                date: DateTime(2026, 4, 6),
                chaptersRead: 2,
                readingMinutes: 30,
                isToday: false,
              ),
              ReadingDayActivity(
                dayLabel: 'Tue',
                date: DateTime(2026, 4, 7),
                chaptersRead: 0,
                readingMinutes: 0,
                isToday: true,
              ),
            ],
            totalChapters: 2,
          ),
        ),
      );

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('2 chapters'), findsOneWidget);
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
            weeklyActivity: [
              ReadingDayActivity(
                dayLabel: 'Mon',
                date: DateTime(2026, 4, 6),
                chaptersRead: 1,
                readingMinutes: 10,
                isToday: true,
              ),
            ],
            totalChapters: 1,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
