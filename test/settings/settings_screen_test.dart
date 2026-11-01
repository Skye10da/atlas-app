import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/settings/presentation/screens/settings_screen.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// The Settings footer must render the *installed* version from
/// `appVersionProvider` (PackageInfo) rather than a hardcoded string, so the
/// "Version X • …" line always reflects the real binary.
void main() {
  testWidgets('settings footer renders the installed version dynamically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAccountSummaryProvider.overrideWithValue(
            const LocalAccountEntity(displayName: 'Reader'),
          ),
          appVersionProvider.overrideWith((ref) async => '1.0.7'),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The footer lives at the very bottom of a lazy ListView; scroll it into
    // the built range before asserting on it.
    await tester.scrollUntilVisible(
      find.text('Version 1.0.7 • Offline-first sanctuary for readers'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Version 1.0.7 • Offline-first sanctuary for readers'),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'settings footer shows the tagline only while the version is unresolved',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localAccountSummaryProvider.overrideWithValue(
              const LocalAccountEntity(displayName: 'Reader'),
            ),
            appVersionProvider.overrideWith((ref) {
              final completer = Completer<String>();
              return completer.future;
            }),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Offline-first sanctuary for readers'),
        300.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline-first sanctuary for readers'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    },
  );
}
