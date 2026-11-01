import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/updater/application/updater_controller.dart';
import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';
import 'package:atlas_app/updater/infrastructure/changelog_store.dart';
import 'package:atlas_app/updater/infrastructure/github_release_repository.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';
import 'package:atlas_app/updater/presentation/screens/whats_new_screen.dart';

class _FakeUpdaterController extends UpdaterController {
  @override
  Future<UpdaterState> build() async => const UpdaterState(
        currentVersion: '1.0.9',
        currentBuild: 9,
      );
}

ChangelogEntry _entry(int build, String notes) => ChangelogEntry(
      tag: 'v1.0.$build+$build',
      version: '1.0.$build',
      versionCode: build,
      publishedAt: DateTime.utc(2026, 10, 31),
      notes: notes,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<ChangelogEntry> Function(ChangelogStore store) seed,
  Future<http.Response> Function(http.Request request)? httpHandler,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ChangelogStore(prefs);
  await store.save(seed(store));

  final container = ProviderContainer(
    overrides: [
      updatePrefsStoreProvider.overrideWith((ref) async => prefs),
      appUpdateRepositoryProvider.overrideWithValue(
        GithubReleaseRepository(
          client: MockClient(
            httpHandler ?? (request) async => http.Response('[]', 200),
          ),
        ),
      ),
      updaterControllerProvider.overrideWith(_FakeUpdaterController.new),
    ],
  );
  addTearDown(container.dispose);
  // Resolve the provider's own load before the UI reads it, so the test (not
  // an initState microtask race) governs when the refresh merges.
  await container.read(changelogControllerProvider.future);
  await container.read(changelogControllerProvider.notifier).refresh();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WhatsNewScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rendered note bodies (SelectableText, so find.text never sees them).
String _renderedNotes(WidgetTester tester) {
  final notes = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((selectable) => selectable.data ?? '')
      .join('\n');
  return notes;
}

void main() {
  testWidgets('renders seeded entries newest first with the installed badge',
      (tester) async {
    await _pump(
      tester,
      seed: (_) => [
        _entry(9, '# Fixed\n- crash on boot'),
        _entry(8, 'older'),
      ],
    );

    expect(find.text('Atlas 1.0.9'), findsOneWidget);
    expect(find.text('Atlas 1.0.8'), findsOneWidget);
    expect(find.text('Installed on this device'), findsOneWidget);
    expect(_renderedNotes(tester), contains('Fixed'));
    expect(_renderedNotes(tester), contains('crash on boot'));
  });

  testWidgets('shows the empty state before any release was recorded',
      (tester) async {
    await _pump(tester, seed: (_) => const []);

    expect(
      find.textContaining('No release notes recorded yet'),
      findsOneWidget,
    );
  });

  testWidgets('nothing cached yet but refresh fetches the newest notes',
      (tester) async {
    await _pump(
      tester,
      seed: (_) => const [],
      httpHandler: (_) async => http.Response(
        json.encode([
          {
            'tag_name': 'v1.0.9+9',
            'body': '# Fixed\n- crash on boot',
            'published_at': '2026-10-31T12:00:00Z',
          },
        ]),
        200,
      ),
    );

    expect(find.textContaining('No release notes'), findsNothing);
    expect(find.text('Atlas 1.0.9'), findsOneWidget);
    expect(_renderedNotes(tester), contains('Fixed'));
  });
}
