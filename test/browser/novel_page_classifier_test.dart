import 'package:atlas_app/browser/domain/utils/novel_page_classifier.dart';
import 'package:atlas_app/core/design_system/atoms/source_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyNovelPageUrl', () {
    group('novel detail pages are allowed', () {
      test('PluginSource-style path', () {
        expect(
          classifyNovelPageUrl('https://novelfull.net/novel/shadow-slave.html'),
          NovelPageKind.novelDetail,
        );
        expect(
          classifyNovelPageUrl('https://freewebnovel.com/novel-name'),
          NovelPageKind.novelDetail,
        );
      });

      test('Royal Road fiction path', () {
        expect(
          classifyNovelPageUrl('https://www.royalroad.com/fiction/61886/title'),
          NovelPageKind.novelDetail,
        );
      });

      test('query strings and fragments are tolerated', () {
        expect(
          classifyNovelPageUrl(
            'https://site.example/novel/name?utm_source=x#top',
          ),
          NovelPageKind.novelDetail,
        );
      });

      test('non-listing single-segment paths', () {
        expect(
          classifyNovelPageUrl('https://site.example/series/slug'),
          NovelPageKind.novelDetail,
        );
      });
    });

    group('homepages are rejected', () {
      test('site root', () {
        expect(
          classifyNovelPageUrl('https://freewebnovel.com/'),
          NovelPageKind.other,
        );
        expect(
          classifyNovelPageUrl('https://freewebnovel.com'),
          NovelPageKind.other,
        );
      });

      test('explicit home paths', () {
        expect(
          classifyNovelPageUrl('https://site.example/home'),
          NovelPageKind.other,
        );
        expect(
          classifyNovelPageUrl('https://site.example/index.html'),
          NovelPageKind.other,
        );
      });
    });

    group('category / genre / listing pages are rejected', () {
      const cases = [
        'https://site.example/category/xianxia',
        'https://site.example/categories',
        'https://site.example/genre/fantasy',
        'https://site.example/genres/top',
        'https://site.example/tag/martial',
        'https://site.example/novel-name/categories',
        'https://site.example/browse',
        'https://site.example/search?q=novel',
        'https://site.example/latest',
        'https://site.example/popular',
        'https://site.example/latest-update?page=3',
        'https://site.example/completed',
      ];
      for (final url in cases) {
        test(url, () {
          expect(classifyNovelPageUrl(url), NovelPageKind.other);
        });
      }
    });

    group('chapter pages are rejected', () {
      const cases = [
        'https://novelfull.net/shadow-slave/chapter-1245',
        'https://site.example/novels/name/chapter/12',
        'https://site.example/read/abc/12',
        'https://site.example/baca/kisah/ch-3',
        'https://site.example/novel/name/episode-7',
        'https://site.example/name/chapters',
        'https://site.example/book/title/chapter_9',
        'https://site.example/trailing/slug/123',
      ];
      for (final url in cases) {
        test(url, () {
          expect(classifyNovelPageUrl(url), NovelPageKind.chapter);
        });
      }
    });

    group('non-http pages are rejected', () {
      test('about:blank', () {
        expect(classifyNovelPageUrl('about:blank'), NovelPageKind.other);
      });

      test('garbage input', () {
        expect(classifyNovelPageUrl(''), NovelPageKind.other);
        expect(classifyNovelPageUrl('not a url'), NovelPageKind.other);
      });

      test('the engine start sentinel', () {
        expect(classifyNovelPageUrl('about:blank'), NovelPageKind.other);
      });
    });

    group('homeOriginUrl', () {
      test('reduces a page URL to its scheme+host origin', () {
        expect(
          homeOriginUrl('https://a.example/novel/1?x=2'),
          'https://a.example',
        );
        expect(
          homeOriginUrl('https://www.royalroad.com/fiction/61886'),
          'https://www.royalroad.com',
        );
      });

      test('rejects non-http and unparseable input', () {
        expect(homeOriginUrl(null), isNull);
        expect(homeOriginUrl('about:blank'), isNull);
        expect(homeOriginUrl(''), isNull);
      });
    });

    group('sourceHomeUrl', () {
      test('falls back to the scheme+host origin of the site page', () {
        expect(
          sourceHomeUrl('Site A', sitePageUrl: 'https://a.example/novel/1?x=2'),
          'https://a.example',
        );
        expect(
          sourceHomeUrl(
            'Novel Hub',
            sitePageUrl: 'https://live.mangabooth.com/novelreader/1',
          ),
          'https://live.mangabooth.com/novelreader',
        );
        expect(
          sourceHomeUrl(
            'MVLEMPYR',
            sitePageUrl: 'https://www.mvlempyr.io/series/1',
          ),
          'https://www.mvlempyr.io',
        );
      });

      test('prefers the declared plugin home when known', () {
        expect(
          sourceHomeUrl(
            'Novel Hub',
            declaredHomeUrl: 'https://live.mangabooth.com/novelreader',
          ),
          'https://live.mangabooth.com/novelreader',
        );
        expect(sourceHomeUrl('Royal Road'), 'https://www.royalroad.com');
      });

      test('rejects sources without a known home', () {
        expect(sourceHomeUrl('Unknown Site'), isNull);
        expect(sourceHomeUrl('not a host'), isNull);
      });
    });
  });
}
