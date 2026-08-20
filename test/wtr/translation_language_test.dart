import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

void main() {
  group('SupportedLanguage', () {
    test('exposes a stable ISO code and names', () {
      final english = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'en',
      );
      final spanish = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'es',
      );
      final japanese = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'ja',
      );

      expect(english.code, 'en');
      expect(spanish.code, 'es');
      expect(japanese.code, 'ja');
      expect(english.name, 'English');
      expect(japanese.nativeName, '日本語');
      expect(english.flag, '🇺🇸');
    });

    test('round-trips through its code', () {
      for (final language in SupportedLanguage.defaults) {
        expect(SupportedLanguage.fromCode(language.code), language);
      }
    });

    test('fromCode returns null for unknown or empty values', () {
      expect(SupportedLanguage.fromCode(null), isNull);
      expect(SupportedLanguage.fromCode(''), isNull);
      expect(SupportedLanguage.fromCode('xx'), isNull);
    });
  });
}
