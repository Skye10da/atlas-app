import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/updater/infrastructure/changelog_store.dart';
import 'package:atlas_app/updater/infrastructure/github_release_repository.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// Pairs a fully-wired [ProviderContainer] (mocked prefs + GitHub client) with
/// the store the test seeds/inspects across cases.
Future<(ProviderContainer, ChangelogStore)> _container(
  http.Client client,
) async {
  // Mock the plugin so getInstance() never touches a real channel.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      updatePrefsStoreProvider.overrideWith((ref) async => prefs),
      appUpdateRepositoryProvider.overrideWithValue(
        GithubReleaseRepository(client: client),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container, ChangelogStore(prefs));
}

Map<String, dynamic> _release(
  String tag, {
  String body = '',
  bool draft = false,
}) =>
    {
      'tag_name': tag,
      'body': body,
      'published_at': '2026-10-31T12:00:00Z',
      'draft': draft,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build() serves the cached store immediately and refresh() merges', () async {
    final (container, store) = await _container(
      MockClient(
        (request) async => http.Response(
          json.encode([
            _release('v1.0.9+9', body: '# Fixed\n- crash'),
            _release('v1.0.8+8', body: 'older'),
          ]),
          200,
        ),
      ),
    );
    await store.save(const []);

    final initial = await container.read(changelogControllerProvider.future);
    expect(initial, isEmpty);

    final merged = await container
        .read(changelogControllerProvider.notifier)
        .refresh();

    expect(merged, hasLength(2));
    expect(merged.first.tag, 'v1.0.9+9');
    expect(merged.first.version, '1.0.9');
    expect(merged.first.notes, '# Fixed\n- crash');
    expect(merged[1].tag, 'v1.0.8+8');
    // Persisted for offline runs.
    expect(store.load().first.tag, 'v1.0.9+9');
  });

  test('first-ever run acknowledges silently (no banner entry)', () async {
    final (container, store) = await _container(
      MockClient((request) async => fail('no network calls expected')),
    );
    await store.save(const []);

    final entry = await container
        .read(changelogControllerProvider.notifier)
        .detectInstalledVersionChange(currentBuild: 8, currentVersion: '1.0.8');

    expect(entry, isNull);
    expect(store.lastSeenVersionCode, 8);
    expect(store.load(), isEmpty);
  });

  test('a new build fetches its notes, records them and bumps the sentinel',
      () async {
    final (container, store) = await _container(
      MockClient(
        (request) async => http.Response(
          json.encode([
            _release('v1.0.9+9', body: '# Fixed\n- crash'),
            _release('v1.0.8+8', body: 'older'),
          ]),
          200,
        ),
      ),
    );
    await store.save(const []);
    store.lastSeenVersionCode = 7;

    final entry = await container
        .read(changelogControllerProvider.notifier)
        .detectInstalledVersionChange(
          currentBuild: 9,
          currentVersion: '1.0.9',
        );

    expect(entry, isNotNull);
    expect(entry!.tag, 'v1.0.9+9');
    expect(entry.notes, '# Fixed\n- crash');
    expect(store.lastSeenVersionCode, 9);
    final saved = store.load();
    expect(saved, hasLength(2));
    expect(saved.first.tag, 'v1.0.9+9');
  });

  test('updating while offline writes a placeholder entry', () async {
    final (container, store) = await _container(
      MockClient((request) async => throw Exception('offline')),
    );
    await store.save(const []);
    store.lastSeenVersionCode = 7;

    final entry = await container
        .read(changelogControllerProvider.notifier)
        .detectInstalledVersionChange(
          currentBuild: 8,
          currentVersion: '1.0.8',
        );

    expect(entry, isNotNull);
    expect(entry!.versionCode, 8);
    expect(entry.notes, 'Atlas 1.0.8 is installed.');
    expect(store.lastSeenVersionCode, 8);
  });

  test('a repeat boot on the same build never re-offers anything', () async {
    final (container, store) = await _container(
      MockClient((request) async => fail('no network calls expected')),
    );
    await store.save(const []);
    store.lastSeenVersionCode = 8;

    final entry = await container
        .read(changelogControllerProvider.notifier)
        .detectInstalledVersionChange(currentBuild: 8, currentVersion: '1.0.8');

    expect(entry, isNull);
    expect(store.load(), isEmpty);
  });
}
