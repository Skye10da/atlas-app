import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/infrastructure/repositories/shared_prefs_translation_repository.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsTranslationRepository', () {
    test('saves and reloads the target language', () async {
      const repo = SharedPrefsTranslationRepository();
      expect(await repo.loadTargetLanguage('b1'), isNull);

      final spanish = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'es',
      );
      await repo.saveTargetLanguage('b1', spanish);
      expect(await repo.loadTargetLanguage('b1'), spanish);
    });

    test('persists the enabled flag', () async {
      const repo = SharedPrefsTranslationRepository();
      expect(await repo.loadEnabled('b1'), isFalse);

      await repo.saveEnabled('b1', true);
      expect(await repo.loadEnabled('b1'), isTrue);

      await repo.saveEnabled('b1', false);
      expect(await repo.loadEnabled('b1'), isFalse);
    });

    test('keeps each book isolated', () async {
      const repo = SharedPrefsTranslationRepository();
      final french = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'fr',
      );
      final korean = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'ko',
      );
      await repo.saveTargetLanguage('b1', french);
      await repo.saveTargetLanguage('b2', korean);
      await repo.saveEnabled('b1', true);

      expect(await repo.loadTargetLanguage('b1'), french);
      expect(await repo.loadTargetLanguage('b2'), korean);
      expect(await repo.loadEnabled('b1'), isTrue);
      expect(await repo.loadEnabled('b2'), isFalse);
    });
  });
}
