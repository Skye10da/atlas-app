import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/intelligence/application/extraction/character_extractor.dart';
import 'package:atlas_app/intelligence/application/extraction/confidence_scorer.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/transliteration_matcher.dart';

void main() {
  late CharacterExtractor extractor;
  late TransliterationMatcher matcher;

  setUp(() {
    extractor = CharacterExtractor();
    matcher = const TransliterationMatcher();
  });

  group('CharacterExtractor', () {
    test('extracts characters from dialogue tags and honorifics', () {
      const sampleChapter = '''
        The wind howled across the Great Wasteland.
        "This trial will not be easy," said Lin Dong with a grim expression.
        Suddenly, Young Master Chen stepped forward and sneered, "A mere branch family member dares compete?"
        Elder Mo stroked his beard and nodded gently.
        Golden Core stage energy burst into the sky, but However it quickly subsided.
      ''';

      final candidates = extractor.extract(sampleChapter);
      final names = candidates.map((c) => c.name).toList();

      // Expected characters
      expect(names, containsAll(['Lin Dong', 'Chen', 'Mo']));

      // Stoplist should prevent these from becoming characters
      expect(names.contains('Great Wasteland'), isFalse);
      expect(names.contains('Golden Core'), isFalse);
      expect(names.contains('However'), isFalse);
      expect(names.contains('Suddenly'), isFalse);

      // Verify Lin Dong has dialogue tag signal
      final linDong = candidates.firstWhere((c) => c.name == 'Lin Dong');
      expect(linDong.signals, contains(ExtractionSignalType.dialogueTag));
      expect(linDong.evidence.first, contains('said Lin Dong'));

      // Verify Chen has honorific signal
      final chen = candidates.firstWhere((c) => c.name == 'Chen');
      expect(chen.signals, contains(ExtractionSignalType.honorificMention));
    });
  });

  group('TransliterationMatcher', () {
    test('matches hyphenated and separated transliterations', () {
      expect(matcher.isPotentialAlias('Lin Dong', 'Lin-dong'), isTrue);
      expect(matcher.isPotentialAlias('Xiao Yan', 'Xiao-yan'), isTrue);
      expect(matcher.isPotentialAlias('Fang Yuan', 'Fangyuan'), isTrue);
    });

    test('does not match distinct names', () {
      expect(matcher.isPotentialAlias('Lin Dong', 'Xiao Yan'), isFalse);
      expect(matcher.isPotentialAlias('Meng Hao', 'Bai Xiaochun'), isFalse);
    });
  });
}

