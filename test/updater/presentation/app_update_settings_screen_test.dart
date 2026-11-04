import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/updater/application/updater_controller.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';
import 'package:atlas_app/updater/presentation/screens/app_update_settings_screen.dart';

class _StaticUpdaterController extends UpdaterController {
  _StaticUpdaterController(this.initial);

  final UpdaterState initial;

  @override
  Future<UpdaterState> build() async => initial;
}

Future<void> _pump(WidgetTester tester, UpdaterState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updaterControllerProvider.overrideWith(
          () => _StaticUpdaterController(state),
        ),
      ],
      child: const MaterialApp(home: AppUpdateSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('readyToInstall surfaces a permission error instead of silence',
      (tester) async {
    await _pump(
      tester,
      const UpdaterState(
        phase: UpdaterPhase.readyToInstall,
        currentVersion: '1.0.10',
        currentBuild: 10,
        installAvailable: true,
        error:
            'Grant "Install unknown apps" for Atlas in the next screen, '
            'then tap Install again.',
      ),
    );

    expect(find.textContaining('Install unknown apps'), findsOneWidget);
    expect(find.text('Install now'), findsOneWidget);
  });

  testWidgets('installing phase offers a retry path', (tester) async {
    await _pump(
      tester,
      const UpdaterState(
        phase: UpdaterPhase.installing,
        currentVersion: '1.0.10',
        currentBuild: 10,
        installAvailable: true,
      ),
    );

    expect(find.text('Installer did not open? Try again'), findsOneWidget);
  });
}
