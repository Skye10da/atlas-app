import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/reader/speech/pronunciation/apply_pronunciation_use_case.dart';
import 'package:atlas_app/reader/speech/pronunciation/models/pronunciation_rule.dart';

void main() {
  const useCase = ApplyPronunciationUseCase();

  group('ApplyPronunciationUseCase', () {
    test('replaces ... with natural pause', () {
      const rules = [PronunciationRule(id: 'ellipsis', pattern: '...', replacement: ', ')];
      expect(useCase.normalize('Hello... world', rules), 'Hello,  world');
    });

    test('replaces unicode ellipsis … with natural pause', () {
      const rules = [PronunciationRule(id: 'unicodeEllipsis', pattern: '…', replacement: ', ')];
      expect(useCase.normalize('Hello… world', rules), 'Hello,  world');
    });

    test('replaces -- with em dash', () {
      const rules = [PronunciationRule(id: 'emDash', pattern: '--', replacement: ' — ')];
      expect(useCase.normalize('test -- case', rules), 'test  —  case');
    });

    test('replaces """ with "', () {
      const rules = [PronunciationRule(id: 'quoteDouble', pattern: '"""', replacement: '"')];
      expect(useCase.normalize('say """hello"""', rules), 'say "hello"');
    });

    test('disabled rule is ignored', () {
      const rules = [PronunciationRule(id: 'ellipsis', pattern: '...', replacement: ' X ', isEnabled: false)];
      expect(useCase.normalize('a...b', rules), 'a...b');
    });

    test('regex rule works', () {
      const rules = [PronunciationRule(id: 'r', pattern: r'\d+', replacement: '#', isRegex: true)];
      expect(useCase.normalize('a1 b22 c333', rules), 'a# b# c#');
    });

    test('defaults are all enabled', () {
      expect(PronounCatalog.defaults.every((r) => r.isEnabled), true);
      expect(PronounCatalog.defaults.length, greaterThanOrEqualTo(8));
    });

    test('empty rules no-op', () {
      expect(useCase.normalize('hello', const []), 'hello');
    });
  });
}
