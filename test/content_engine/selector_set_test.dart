import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';

void main() {
  group('SelectorSet.applySearch', () {
    const selectors = SelectorSet(search: SearchSelectors(
      resultItem: '.search-result',
      title: '.title',
      coverUrl: 'img@src',
      detailUrl: 'a@href',
    ));

    test('extracts items with @attr extraction instructions', () {
      final doc = html_parser.parse('''
        <html><body>
          <div class="search-result">
            <a href="/novel/slug-a"><span class="title">Novel A</span></a>
            <img src="/cover-a.jpg" alt="">
          </div>
          <div class="search-result">
            <a href="https://example.com/novel/slug-b">
              <span class="title">Novel B</span>
            </a>
            <img src="/cover-b.jpg" alt="">
          </div>
          <div class="search-result"><span class="title">No link</span></div>
        </body></html>
      ''');

      final results =
          selectors.applySearch(doc, baseUrl: 'https://example.com');

      expect(results, hasLength(2));
      expect(results[0].title, 'Novel A');
      expect(results[0].url, 'https://example.com/novel/slug-a');
      expect(results[0].coverUrl, '/cover-a.jpg');
      expect(results[1].title, 'Novel B');
      expect(results[1].url, 'https://example.com/novel/slug-b');
    });
  });

  group('SelectorSet.applyChapterList', () {
    const selectors = SelectorSet(chapterList: ChapterListSelectors(
      item: '.chapter-list li a',
      title: '@text',
      url: '@href',
    ));

    test('extracts title and url using the @text/@href item-level defaults', () {
      final doc = html_parser.parse('''
        <html><body>
          <ul class="chapter-list">
            <li><a href="/chapter/1">Chapter 1</a></li>
            <li><a href="/chapter/2">Chapter 2</a></li>
          </ul>
        </body></html>
      ''');

      final refs = selectors.applyChapterList(doc);

      expect(refs, hasLength(2));
      expect(refs[0].title, 'Chapter 1');
      expect(refs[0].url, '/chapter/1');
      expect(refs[1].title, 'Chapter 2');
      expect(refs[1].url, '/chapter/2');
    });
  });

  group('SelectorSet.applyContentContainer', () {
    test('returns the matching container element', () {
      const selectors = SelectorSet(chapterContent: ChapterContentSelectors(
        container: '#chapter-content',
      ));
      final doc = html_parser.parse('''
        <html><body><div id="chapter-content"><p>Body</p></div></body></html>
      ''');

      expect(selectors.applyContentContainer(doc)?.id, 'chapter-content');
    });

    test('falls back to the document body when the container is missing', () {
      const selectors = SelectorSet(chapterContent: ChapterContentSelectors(
        container: '#nope',
      ));
      final doc = html_parser.parse('<html><body><p>Body</p></body></html>');

      expect(selectors.applyContentContainer(doc), same(doc.body));
    });
  });
}
