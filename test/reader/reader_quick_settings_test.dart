import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_quick_settings_sheet.dart';

void _noop() {}

Widget _sheetHarness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: ReaderQuickSettingsSheet(onAllSettings: _noop),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('layout switch shows Pages / Scroll / Flip with mode selected',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_sheetHarness(container));
    await tester.pumpAndSettle();

    // All three segments render; default mode (page) is selected.
    expect(find.text('Pages'), findsOneWidget);
    expect(find.text('Scroll'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    final mode = container
        .read(readingSettingsProvider)
        .valueOrNull!
        .readingMode;
    expect(mode, ReadingMode.page);
  });

  testWidgets('tapping Scroll switches to the continuous layout',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_sheetHarness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scroll'));
    await tester.pumpAndSettle();

    final mode = container
        .read(readingSettingsProvider)
        .valueOrNull!
        .readingMode;
    expect(mode, ReadingMode.continuous);
  });

  testWidgets('tapping Flip switches to the page-flip layout', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_sheetHarness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flip'));
    await tester.pumpAndSettle();

    final mode = container
        .read(readingSettingsProvider)
        .valueOrNull!
        .readingMode;
    expect(mode, ReadingMode.realFlip);
  });
}
