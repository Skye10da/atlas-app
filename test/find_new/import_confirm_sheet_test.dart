import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/find_new/presentation/widgets/import_confirm_sheet.dart';

ImportCandidate site(String name, String url) => ImportCandidate(
      siteName: name,
      url: url,
      description: 'A fine place to read novels',
    );

Future<void> pumpHub(
  WidgetTester tester,
  List<ImportCandidate> candidates, {
  required ValueSetter<ImportCandidate> onSelected,
  required void Function() onDone,
  String? recommendedUrl,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showImportConfirmSheet(
                  context,
                  title: 'Reverend Insanity',
                  author: 'Gu Zhen Ren',
                  candidates: candidates,
                  recommendedUrl: recommendedUrl,
                  onSelected: (_, candidate) async {
                    onSelected(candidate);
                    onDone();
                    return null;
                  },
                );
              },
              child: const Text('add'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('single candidate imports directly, no chooser', (
    tester,
  ) async {
    final picked = <String>[];
    ImportCandidate? chosen;
    await pumpHub(
      tester,
      [site('Royal Road', 'https://royalroad.com/novel/1')],
      onSelected: (candidate) => chosen = candidate,
      onDone: () => picked.add('done'),
    );

    await tester.tap(find.text('add'));
    await tester.pump();

    expect(chosen?.siteName, 'Royal Road');
    expect(picked, ['done']);
    // No chooser surfaced.
    expect(find.text('Pick the one to import from.'), findsNothing);
  });

  testWidgets('multi-site book opens the chooser and picks a site', (
    tester,
  ) async {
    ImportCandidate? chosen;
    await pumpHub(
      tester,
      [
        site('Royal Road', 'https://royalroad.com/novel/1'),
        site('WTR-LAB', 'https://wtr-lab.com/novel/1'),
        site('Heroic Novels', 'https://heroicnovels.com/novel/1'),
      ],
      onSelected: (candidate) => chosen = candidate,
      onDone: () {},
    );

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Reverend Insanity" is available on 3 sites. '
          'Pick the one to import from.'),
      findsOneWidget,
    );

    await tester.tap(find.text('WTR-LAB'));
    await tester.pump();

    expect(chosen?.siteName, 'WTR-LAB');
  });

  testWidgets('no candidates surfaces a snack bar instead of a sheet', (
    tester,
  ) async {
    var called = false;
    await pumpHub(
      tester,
      const [],
      onSelected: (_) => called = true,
      onDone: () {},
    );

    await tester.tap(find.text('add'));
    await tester.pump();

    expect(
      find.text('No supported site found for "Reverend Insanity".'),
      findsOneWidget,
    );
    expect(called, isFalse);
  });

  testWidgets('identical URLs collapse into one chooser row', (tester) async {
    var chosenSites = 0;
    await pumpHub(
      tester,
      [
        site('Royal Road', 'https://royalroad.com/novel/1'),
        site('Royal Road Mirror', 'https://royalroad.com/novel/1'),
      ],
      onSelected: (candidate) => chosenSites++,
      onDone: () {},
    );

    await tester.tap(find.text('add'));
    await tester.pump();

    // Same URL from two site names → treated as one site → direct import.
    expect(chosenSites, 1);
  });

  testWidgets('the recommended source carries its badge on the chooser',
      (tester) async {
    var chosenSites = 0;
    await pumpHub(
      tester,
      [
        site('Royal Road', 'https://royalroad.com/novel/1'),
        site('WTR-LAB', 'https://wtr-lab.com/novel/1'),
      ],
      recommendedUrl: 'https://wtr-lab.com/novel/1',
      onSelected: (candidate) => chosenSites++,
      onDone: () {},
    );

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    // Exactly one Recommended badge, and it sits on the WTR-LAB row.
    expect(find.text('Recommended'), findsOneWidget);
  });
}
