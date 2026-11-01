import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';
import 'package:atlas_app/updater/infrastructure/changelog_store.dart';

ChangelogEntry _entry(int build, {String notes = 'notes'}) => ChangelogEntry(
      tag: 'v1.0.$build+$build',
      version: '1.0.$build',
      versionCode: build,
      publishedAt: DateTime.utc(2026, 10, 31),
      notes: notes,
    );

void main() {
  group('ChangelogStore', () {
    test('save/load roundtrips entries', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ChangelogStore(await SharedPreferences.getInstance());
      final entries = [_entry(9), _entry(8)];

      await store.save(entries);

      expect(store.load(), hasLength(2));
      final loaded = store.load();
      expect(loaded.first.tag, 'v1.0.9+9');
      expect(loaded.first.version, '1.0.9');
      expect(loaded.first.versionCode, 9);
      expect(loaded.first.notes, 'notes');
      expect(loaded.first.publishedAt, DateTime.utc(2026, 10, 31));
    });

    test('empty / corrupt payloads load as nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChangelogStore(prefs);

      expect(store.load(), isEmpty);

      await prefs.setString('app_changelog_entries', 'not-json{');
      expect(store.load(), isEmpty);

      await prefs.setString(
        'app_changelog_entries',
        '[{"tag":"v1.0.9+9","version":"1.0.9","versionCode":"nine",'
            '"publishedAt":"bogus","notes":"x"}]',
      );
      expect(store.load(), isEmpty);
    });

    test('lastSeenVersionCode pillars the once-per-version banner', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ChangelogStore(await SharedPreferences.getInstance());

      expect(store.lastSeenVersionCode, isNull);
      store.lastSeenVersionCode = 8;
      expect(store.lastSeenVersionCode, 8);
      store.lastSeenVersionCode = null;
      expect(store.lastSeenVersionCode, isNull);
    });
  });
}
