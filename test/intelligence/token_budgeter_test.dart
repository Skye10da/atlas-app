import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/intelligence/orchestrator/context/token_budgeter.dart';

void main() {
  group('TokenBudgeter.estimateTokens', () {
    const budgeter = TokenBudgeter();

    test('pure latin text keeps the legacy ~4 chars/token behavior', () {
      expect(budgeter.estimateTokens(''), 0);
      expect(budgeter.estimateTokens('abcd'), 1);
      expect(budgeter.estimateTokens('abcde'), 2);
      expect(budgeter.estimateTokens('a' * 400), 100);
    });

    test('CJK runes cost approximately one token each', () {
      expect(budgeter.estimateTokens('林动与应欢欢'), 6); // 6 ideographs
      // 6 CJK runes + 4 latin chars = 6 + 1
      expect(budgeter.estimateTokens('林动与应欢欢abcd'), 7);
    });

    test('mixed CJK and latin text combines both accounting rules', () {
      expect(budgeter.estimateTokens('武动乾坤 The Great'), 4 + 3);
    });
  });

  group('TokenBudgeter.truncateToBudget', () {
    const budgeter = TokenBudgeter();

    test('short text is returned unchanged', () {
      const text = 'line one\nline two';
      expect(budgeter.truncateToBudget(text, 1000), text);
    });

    test('multi-line text cuts at a line boundary, keeping earlier lines', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 50; i++) {
        buffer.writeln('Item line number $i with some padding text.');
      }
      final truncated =
          const TokenBudgeter().truncateToBudget(buffer.toString(), 30);

      expect(truncated.length, lessThan(buffer.length));
      expect(truncated.split('\n').length, greaterThan(1));
      // Never ends halfway through a kept line's final punctuation.
      final lastNonEmpty =
          truncated.split('\n').lastWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      expect(lastNonEmpty.trimRight().endsWith('.'), isTrue);
    });

    test('CJK-heavy text truncates by token count, not character count', () {
      final text = '武' * 100; // 100 runes ≈ 100 tokens
      final truncated = budgeter.truncateToBudget(text, 10);
      expect(truncated.runes.length, 10);
    });

    test('a single oversized line is hard-trimmed to the budget', () {
      final text = 'longline' * 100;
      final truncated = budgeter.truncateToBudget(text, 8);
      expect(truncated, isNotEmpty);
      expect(truncated.length, lessThan(text.length));
      expect(truncated.length, lessThanOrEqualTo(8 * 4 + 1));
    });

    test('zero budget returns empty', () {
      expect(budgeter.truncateToBudget('anything', 0), '');
    });
  });
}
