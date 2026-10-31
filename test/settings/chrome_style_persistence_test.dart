import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/infrastructure/repositories/shared_prefs_settings_repository.dart';

/// Chrome-style persistence gate (reader glass pills plan phase 4): the new
/// `glass` value must round-trip, and corrupt values must keep defaulting to
/// translucent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repo = SharedPrefsSettingsRepository();
  const key = 'reader_chrome_style';

  test("'glass' round-trips through the chrome style pref", () async {
    SharedPreferences.setMockInitialValues({key: 'glass'});
    final loaded = await repo.load();
    expect(loaded.chromeStyle, ReaderChromeStyle.glass);

    await repo.save(loaded.copyWith(chromeStyle: ReaderChromeStyle.glass));
    await SharedPreferences.getInstance().then((prefs) {
      expect(prefs.getString(key), 'glass');
    });
  });

  test("legacy 'frosted' and unknown values keep their old mapping", () async {
    SharedPreferences.setMockInitialValues({key: 'frosted'});
    expect((await repo.load()).chromeStyle, ReaderChromeStyle.frosted);

    SharedPreferences.setMockInitialValues({key: 'bogus'});
    expect(
      (await repo.load()).chromeStyle,
      ReaderChromeStyle.translucent,
      reason: 'unknown strings must keep defaulting to translucent',
    );

    SharedPreferences.setMockInitialValues({});
    expect((await repo.load()).chromeStyle, ReaderChromeStyle.translucent);
  });
}
