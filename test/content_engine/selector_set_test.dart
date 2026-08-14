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
      expect(results[0].coverUrl, 'https://example.com/cover-a.jpg');
      expect(results[1].title, 'Novel B');
      expect(results[1].url, 'https://example.com/novel/slug-b');
    });

    test('parses search path and queryParam from JSON', () {
      final selectors = SelectorSet.fromJson({
        'search': {
          'resultItem': '.item',
          'path': '/fictions/search',
          'queryParam': 'title',
        },
      });

      expect(selectors.search!.path, '/fictions/search');
      expect(selectors.search!.queryParam, 'title');
      expect(selectors.search!.resultItem, '.item');
    });

    test('defaults queryParam to s when absent', () {
      const selectors = SelectorSet(search: SearchSelectors(resultItem: '.x'));

      expect(selectors.search!.queryParam, 's');
      expect(selectors.search!.path, isNull);
    });

    test('parses fixed extra query params', () {
      final selectors = SelectorSet.fromJson({
        'search': {
          'resultItem': '.item',
          'path': '/search',
          'queryParam': 's',
          'extraQueryParams': {'post_type': 'wp-manga'},
        },
      });

      expect(selectors.search!.extraQueryParams, {'post_type': 'wp-manga'});
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

    test('parses pagination and reverse fields from JSON', () {
      final selectors = SelectorSet.fromJson({
        'chapterList': {
          'item': '#idData li a',
          'pageParam': 'page',
          'maxPages': 7,
          'reverse': true,
        },
      });

      expect(selectors.chapterList!.pageParam, 'page');
      expect(selectors.chapterList!.maxPages, 7);
      expect(selectors.chapterList!.reverse, isTrue);
    });

    test('parses an ajaxPath for a single-request chapter archive', () {
      final selectors = SelectorSet.fromJson({
        'chapterList': {
          'item': 'ul.list-chapter li',
          'ajaxPath': '/ajax/chapter-archive',
        },
      });

      expect(selectors.chapterList!.ajaxPath, '/ajax/chapter-archive');
      expect(selectors.chapterList!.item, 'ul.list-chapter li');
    });

    test('parses an ajax archive override and pagination detection', () {
      final selectors = SelectorSet.fromJson({
        'chapterList': {
          'item': 'ul.list-chapter li',
          'ajaxPath': '/ajax-chapter-option',
          'ajaxArchive': {
            'item': 'select > option[value]',
            'title': '@text',
            'url': '@value',
          },
          'paginationSelector': 'ul.pagination, #barcon',
          'totalPagesSelector': '#truyen',
          'sortByChapterNumber': true,
        },
      });

      final chapterList = selectors.chapterList!;
      expect(chapterList.ajaxArchive!.item, 'select > option[value]');
      expect(chapterList.ajaxArchive!.title, '@text');
      expect(chapterList.ajaxArchive!.url, '@value');
      expect(chapterList.ajaxArchive!.novelIdSelector, '[data-novel-id]@data-novel-id');
      expect(chapterList.ajaxArchive!.method, 'GET');
      expect(chapterList.ajaxArchive!.form, isEmpty);
      expect(chapterList.ajaxArchive!.responseField, isNull);
      expect(chapterList.ajaxArchive!.ajaxBase, 'base');
      expect(chapterList.paginationSelector, 'ul.pagination, #barcon');
      expect(chapterList.totalPagesSelector, '#truyen');
      expect(chapterList.sortByChapterNumber, isTrue);
    });

    test('parses a Madara-style POST ajax archive override', () {
      final selectors = SelectorSet.fromJson({
        'chapterList': {
          'item': 'ul.wp-manga-chapter li a',
          'ajaxPath': '/wp-admin/admin-ajax.php',
          'ajaxArchive': {
            'item': 'li.wp-manga-chapter a',
            'novelIdSelector':
                '#manga-chapters-holder@data-id|#madara-chapters-holder@data-id',
            'method': 'POST',
            'form': {'action': 'manga_get_chapters', 'manga': '{novelId}'},
            'responseField': 'data.content',
            'ajaxBase': 'base',
          },
        },
      });

      final archive = selectors.chapterList!.ajaxArchive!;
      expect(archive.item, 'li.wp-manga-chapter a');
      expect(archive.novelIdSelector,
          '#manga-chapters-holder@data-id|#madara-chapters-holder@data-id');
      expect(archive.method, 'POST');
      expect(archive.form, {'action': 'manga_get_chapters', 'manga': '{novelId}'});
      expect(archive.responseField, 'data.content');
      expect(archive.ajaxBase, 'base');
    });

    test('defaults pagination fields', () {
      const selectors = SelectorSet(chapterList: ChapterListSelectors(item: 'li'));

      expect(selectors.chapterList!.pageParam, 'page');
      expect(selectors.chapterList!.maxPages, 1);
      expect(selectors.chapterList!.reverse, isFalse);
      expect(selectors.chapterList!.ajaxPath, isNull);
      expect(selectors.chapterList!.ajaxArchive, isNull);
      expect(selectors.chapterList!.paginationSelector, isNull);
      expect(selectors.chapterList!.totalPagesSelector, isNull);
      expect(selectors.chapterList!.sortByChapterNumber, isFalse);
    });
  });

  group('SelectorSet.extract', () {
    const selectors = SelectorSet();

    test('returns the first non-empty alternative for | specs', () {
      final doc = html_parser.parse('''
        <html><body>
          <li><a class="chapter-title">Chapter One</a></li>
          <li><a class="nchr-text">Chapter Two</a></li>
        </body></html>
      ''');
      final items = doc.body!.querySelectorAll('li');

      expect(
        selectors.extract(items[0], '.chapter-title@text|.nchr-text@text'),
        'Chapter One',
      );
      expect(
        selectors.extract(items[1], '.chapter-title@text|.nchr-text@text'),
        'Chapter Two',
      );
    });

    test('does not split attribute selectors on |', () {
      final doc = html_parser.parse(
        '<html><body><a href="https://example.com/a|b" data-t="1">X</a></body></html>',
      );

      expect(selectors.extract(doc.body!, 'a[href*="|"]@text'), 'X');
    });

    test('returns null when no alternative matches', () {
      final doc = html_parser.parse('<html><body><a>Nothing</a></body></html>');
      final item = doc.body!.querySelector('a')!;

      expect(selectors.extract(item, '.missing@text|.also-missing@text'), isNull);
    });
  });

  group('SelectorSet.extractAll', () {
    const selectors = SelectorSet();

    test('collects the text of every matching element', () {
      final doc = html_parser.parse('''
        <html><body>
          <div class="genres-content">
            <a href="/g/1">Romance</a>
            <a href="/g/2">Drama</a>
            <a href="/g/3">Romance</a>
          </div>
        </body></html>
      ''');

      expect(
        selectors.extractAll(
            doc.body!, '.genres-content a@text'),
        ['Romance', 'Drama'],
      );
    });

    test('collects attribute values when requested', () {
      final doc = html_parser.parse('''
        <html><body>
          <span data-tag="Action"></span>
          <span data-tag="Adventure"></span>
        </body></html>
      ''');

      expect(selectors.extractAll(doc.body!, 'span@data-tag'),
          ['Action', 'Adventure']);
    });

    test('returns an empty list when nothing matches', () {
      final doc = html_parser.parse('<html><body><a>X</a></body></html>');

      expect(selectors.extractAll(doc.body!, '.missing a@text'), isEmpty);
    });
  });

  group('SelectorSet.metadata', () {
    test('parses css and info-row metadata fields', () {
      final selectors = SelectorSet.fromJson({
        'metadata': {
          'author': {'label': 'Author:'},
          'genres': {'labels': ['Genres:', 'Genre:'], 'links': true},
          'description': '.desc-text p',
          'coverUrl': 'img@src',
        },
      });

      expect(selectors.metadata!.author, isA<InfoRowMetadataField>());
      expect(selectors.metadata!.genres, isA<InfoRowMetadataField>());
      expect(selectors.metadata!.description, isA<CssMetadataField>());
      expect(selectors.metadata!.coverUrl, isA<CssMetadataField>());
      expect(selectors.metadata!.status, isNull);

      final genres = selectors.metadata!.genres as InfoRowMetadataField;
      expect(genres.labels, ['Genres:', 'Genre:']);
      expect(genres.links, isTrue);
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
