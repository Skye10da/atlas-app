import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/find_new/presentation/widgets/search_summary_line.dart';
import 'package:atlas_app/search/domain/federated_search.dart';

SiteSearchStatus st(String name, SiteSearchState state, {int count = 0}) =>
    SiteSearchStatus(sourceName: name, state: state, resultCount: count);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('searching shows running count and progress', (tester) async {
    await tester.pumpWidget(wrap(SearchSummaryLine(
      statuses: [
        st('A', SiteSearchState.done, count: 3),
        st('B', SiteSearchState.empty),
        st('C', SiteSearchState.loading),
      ],
      matchCount: 3,
      onRetry: () {},
    )));

    expect(find.textContaining('Searching'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('all reached shows the finished summary without retry',
      (tester) async {
    await tester.pumpWidget(wrap(SearchSummaryLine(
      statuses: [
        st('A', SiteSearchState.done, count: 2),
        st('B', SiteSearchState.empty),
      ],
      matchCount: 2,
      onRetry: () {},
    )));

    expect(find.textContaining('2 sites searched'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('unreachable sites get counted quietly with a Retry action',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(wrap(SearchSummaryLine(
      statuses: [
        st('A', SiteSearchState.done, count: 2),
        st('B', SiteSearchState.error),
        st('C', SiteSearchState.skipped),
      ],
      matchCount: 2,
      onRetry: () => retried = true,
    )));

    expect(find.textContaining('1 of 3 sites searched'), findsOneWidget);
    // Blocks/timeouts are never surfaced as technical errors.
    expect(find.textContaining('403'), findsNothing);
    expect(find.textContaining('Timed out'), findsNothing);

    final retry = find.widgetWithText(TextButton, 'Retry');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(retried, isTrue);
  });

  testWidgets('expanding the detail shows per-site quiet labels',
      (tester) async {
    await tester.pumpWidget(wrap(SearchSummaryLine(
      statuses: [
        st('A', SiteSearchState.done, count: 1),
        st('BlockedSite', SiteSearchState.skipped),
      ],
      matchCount: 1,
      onRetry: () {},
    )));

    // Collapsed by default: the tile's own heading, but no site names.
    expect(find.text("1 site couldn't be reached"), findsOneWidget);
    expect(find.textContaining('BlockedSite'), findsNothing);
    await tester.tap(find.text("1 site couldn't be reached"));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('BlockedSite — '),
      findsOneWidget,
    );
  });
}
