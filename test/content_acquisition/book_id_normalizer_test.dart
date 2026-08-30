import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/content_acquisition/utils/book_id_normalizer.dart';

void main() {
  group('BookIdNormalizer', () {
    test('normalizes standard English title to lowercase underscored slug', () {
      expect(
        BookIdNormalizer.normalize('Lord of the Mysteries'),
        equals('lord_of_the_mysteries'),
      );
      expect(
        BookIdNormalizer.normalize('The Beginning After the End'),
        equals('the_beginning_after_the_end'),
      );
    });

    test('preserves CJK characters and does not produce empty string', () {
      final chineseId = BookIdNormalizer.normalize('诡秘之主');
      expect(chineseId, isNotEmpty);
      expect(chineseId, equals('诡秘之主'));

      final mixedCjk = BookIdNormalizer.normalize('斗破苍穹: 绝世唐门');
      expect(mixedCjk, equals('斗破苍穹_绝世唐门'));

      final japaneseId = BookIdNormalizer.normalize('ソードアート・オンライン');
      expect(japaneseId, isNotEmpty);
      expect(japaneseId, equals('ソードアート_オンライン'));

      final koreanId = BookIdNormalizer.normalize('나 혼자만 레벨업');
      expect(koreanId, isNotEmpty);
      expect(koreanId, equals('나_혼자만_레벨업'));
    });

    test('preserves Cyrillic and other Unicode scripts', () {
      expect(
        BookIdNormalizer.normalize('Война и мир'),
        equals('война_и_мир'),
      );
    });

    test('falls back safely when title is pure punctuation or emojis', () {
      final fallback = BookIdNormalizer.normalize('   ??? !!! --- ...   ');
      expect(fallback, startsWith('book_'));
      expect(fallback.length, greaterThan(5));

      final emojiFallback = BookIdNormalizer.normalize('🔥📖⭐');
      expect(emojiFallback, startsWith('book_'));
    });

    test('truncates overly long titles to at most 48 chars plus hash', () {
      final longTitle = 'A' * 100;
      final normalized = BookIdNormalizer.normalize(longTitle);
      expect(normalized.length, lessThanOrEqualTo(60));
      expect(normalized, contains('_'));
    });
  });
}

