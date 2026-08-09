import 'package:atlas_app/browser/domain/utils/browser_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBrowserUrl', () {
    test('prepends https to a bare host', () {
      expect(normalizeBrowserUrl('example.com'), 'https://example.com');
    });

    test('keeps an explicit scheme', () {
      expect(normalizeBrowserUrl('http://example.com'), 'http://example.com');
      expect(normalizeBrowserUrl('https://example.com'), 'https://example.com');
    });

    test('keeps about: pages as-is', () {
      expect(normalizeBrowserUrl('about:blank'), 'about:blank');
    });

    test('trims surrounding whitespace', () {
      expect(normalizeBrowserUrl('  example.com  '), 'https://example.com');
    });

    test('empty input is a no-op', () {
      expect(normalizeBrowserUrl(''), '');
    });
  });

  group('looksLikeBrowserUrl', () {
    test('true for URLs with a scheme', () {
      expect(looksLikeBrowserUrl('https://example.com/path'), isTrue);
    });

    test('true for about pages', () {
      expect(looksLikeBrowserUrl('about:blank'), isTrue);
    });

    test('false for a plain search query', () {
      expect(looksLikeBrowserUrl('Atlas novel reading'), isFalse);
    });

    test('false for a single word', () {
      expect(looksLikeBrowserUrl('gutenberg'), isFalse);
    });
  });
}