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

    test('plain text falls back to a search query', () {
      expect(
        normalizeBrowserUrl('Atlas novel reading'),
        'https://www.google.com/search?q=Atlas+novel+reading',
      );
    });

    test('single word falls back to a search query', () {
      expect(
        normalizeBrowserUrl('gutenberg'),
        'https://www.google.com/search?q=gutenberg',
      );
    });

    test('passes known non-http schemes through untouched', () {
      expect(
        normalizeBrowserUrl('mailto:reader@atlas.app'),
        'mailto:reader@atlas.app',
      );
      expect(
        normalizeBrowserUrl('tel:+1234567890'),
        'tel:+1234567890',
      );
    });

    test('hosts with a port get https://', () {
      expect(
        normalizeBrowserUrl('localhost:8080'),
        'https://localhost:8080',
      );
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

  group('browserSearchUrl', () {
    test('encodes the query into a google search URL', () {
      expect(
        browserSearchUrl('Atlas novel reading'),
        'https://www.google.com/search?q=Atlas+novel+reading',
      );
    });
  });

  group('looksLikeEpubUrl', () {
    test('true for .epub paths', () {
      expect(
        looksLikeEpubUrl('https://example.com/books/download.epub'),
        isTrue,
      );
      expect(looksLikeEpubUrl('https://example.com/b.epub?token=abc'), isTrue);
    });

    test('false for non-epub paths', () {
      expect(looksLikeEpubUrl('https://example.com/book/123'), isFalse);
      expect(looksLikeEpubUrl('https://example.com/file.txt'), isFalse);
    });
  });

  group('looksLikePdfUrl', () {
    test('true for .pdf paths', () {
      expect(
        looksLikePdfUrl('https://example.com/books/download.pdf'),
        isTrue,
      );
      expect(looksLikePdfUrl('https://example.com/b.PDF?token=abc'), isTrue);
    });

    test('false for non-pdf paths', () {
      expect(looksLikePdfUrl('https://example.com/book/123'), isFalse);
      expect(looksLikePdfUrl('https://example.com/file.epub'), isFalse);
    });
  });
}
