import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/index/tokenizer.dart';

void main() {
  group('Tokenizer', () {
    test('lowercases, splits on non-alphanumerics, keeps hyphenated words', () {
      const tokenizer = Tokenizer();
      expect(
        tokenizer.tokenize('Hello, World! The quick-brown fox.'),
        ['hello', 'world', 'quick-brown', 'fox'],
      );
    });

    test('strips possessives', () {
      const tokenizer = Tokenizer();
      expect(tokenizer.tokenize("John's dog ran"), ['john', 'dog', 'ran']);
    });

    test('drops default stopwords', () {
      const tokenizer = Tokenizer();
      expect(tokenizer.tokenize('the and of a to for'), isEmpty);
    });

    test('keeps words shorter than 2 letters out', () {
      const tokenizer = Tokenizer();
      expect(tokenizer.tokenize('a b c d ee'), ['ee']);
    });

    test('honors a custom stopword set', () {
      const tokenizer = Tokenizer(stopwords: {'custom'});
      expect(tokenizer.tokenize('custom word'), ['word']);
      // Default stopwords no longer apply.
      expect(tokenizer.tokenize('the and'), ['the', 'and']);
    });
  });
}
