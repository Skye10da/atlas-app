import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/mvlempyr_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

import 'test_fixtures.dart';

const _novelPage = '''
<html><head><title>Some Title</title>
<meta name="description" content="Meta desc">
</head><body>
<h1 class="novel-title">The Novel</h1>
<div id="novel-code">12345</div>
<div class="fieldtext">Author:</div><div>Jane Doe</div>
<div class="synopsis w-richtext"><p>A <strong>great</strong> story.</p></div>
<div class="novelstatustextlarge">Ongoing</div>
<img src="https://example.com/cover.jpg" class="novel-image">
</body></html>''';


void main() {
  group('MvlempyrTemplate.metadata', () {
    test('extracts page fields and enriches via the mvl-novels REST endpoint',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://www.mvlempyr.io/novel/some-slug', _novelPage)
        ..addJson('https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels',
            <Object?>[
              {
                'name': 'REST Title',
                'average-review': 4.5,
                'total-chapters': 120,
                'createdOn': '2024-01-15T00:00:00',
                'genre': ['Fantasy', 'Adventure'],
              },
            ]);
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      final meta = await const MvlempyrTemplate()
          .metadata(context, 'https://www.mvlempyr.io/novel/some-slug');

      expect(meta.title, 'The Novel');
      expect(meta.author, 'Jane Doe');
      expect(meta.description, contains('great'));
      expect(meta.status, 'Ongoing');
      expect(meta.coverUrl, 'https://example.com/cover.jpg');
      expect(meta.sourceId, '12345');
      expect(meta.rating, 4.5);
      expect(meta.chapterCount, 120);
      expect(meta.lastUpdated, DateTime(2024, 1, 15));
      expect(meta.genres, ['Fantasy', 'Adventure']);
    });
  });

  group('MvlempyrTemplate.chapterList', () {
    test('builds refs from the posts REST feed and sorts by chapter number',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://www.mvlempyr.io/novel/some-slug', _novelPage)
        ..addJson('https://chap.heliosarchive.online/wp-json/wp/v2/posts',
            <Object?>[
              {
                'acf': {
                  'chapter_number': 2,
                  'novel_code': '12345',
                  'ch_name': 'Second',
                },
                'date': '2024-02-01T00:00:00',
              },
              {
                'acf': {
                  'chapter_number': 1,
                  'novel_code': '12345',
                  'ch_name': 'First',
                },
                'date': '2024-01-01T00:00:00',
              },
            ]);
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      final refs = await const MvlempyrTemplate()
          .chapterList(context, 'https://www.mvlempyr.io/novel/some-slug');

      expect(refs, hasLength(2));
      expect(refs[0].title, 'First');
      expect(refs[0].url, 'https://www.mvlempyr.io/chapter/12345-1');
      expect(refs[0].publishedAt, DateTime(2024, 1, 1));
      expect(refs[1].title, 'Second');
    });

    test('paginates past the first full page', () async {
      final transport = _PagedPostsTransport();
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      final refs = await const MvlempyrTemplate()
          .chapterList(context, 'https://www.mvlempyr.io/novel/some-slug');

      expect(refs, hasLength(501));
      expect(refs.first.url, 'https://www.mvlempyr.io/chapter/12345-1');
      expect(refs.last.url, 'https://www.mvlempyr.io/chapter/12345-501');
    });

    test('falls back to generated refs when the REST feed is unavailable',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://www.mvlempyr.io/novel/some-slug', _novelPage)
        ..addJson('https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels',
            <Object?>[
              {'total-chapters': 3},
            ]);
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      final refs = await const MvlempyrTemplate()
          .chapterList(context, 'https://www.mvlempyr.io/novel/some-slug');

      expect(refs, hasLength(3));
      expect(refs[0].title, 'Chapter 1');
      expect(refs[0].url, 'https://www.mvlempyr.io/chapter/12345-1');
      expect(refs[2].url, 'https://www.mvlempyr.io/chapter/12345-3');
    });
  });

  group('MvlempyrTemplate.chapterContent', () {
    test('extracts oxy-stock content and runs it through the pipeline',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://www.mvlempyr.io/chapter/12345-1', '''
        <html><body>
          <h2 id="chapter-name"><span>Chapter One</span></h2>
          <span class="oxy-stock-content-styles">
            <p>First paragraph.</p><p>Second paragraph.</p>
          </span>
        </body></html>''');
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      final doc = await const MvlempyrTemplate()
          .chapterContent(context, 'https://www.mvlempyr.io/chapter/12345-1');

      expect(doc.title, 'Chapter One');
      final text = doc.renderToText();
      expect(text, contains('First paragraph.'));
      expect(text, contains('Second paragraph.'));
    });

    test('throws TransportException on a Cloudflare challenge', () async {
      final transport = FakeTransport()
        ..addHtml('https://www.mvlempyr.io/chapter/12345-1',
            '<html><head><title>Attention Required! | Cloudflare</title></head><body></body></html>');
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      await expectLater(
        const MvlempyrTemplate()
            .chapterContent(context, 'https://www.mvlempyr.io/chapter/12345-1'),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('MvlempyrTemplate capabilities', () {
    test('does not support search', () async {
      final context = buildContext(
        transport: FakeTransport(),
        manifest: buildManifest(
          templateId: 'mvlempyr',
          baseUrl: 'https://www.mvlempyr.io',
          capabilities: const [
            PluginCapability.chapterList,
            PluginCapability.chapterContent,
            PluginCapability.cover,
          ],
        ),
      );

      await expectLater(
        const MvlempyrTemplate().search(context, 'query'),
        throwsA(isA<PluginCapabilityException>()),
      );
    });

    test('is registered in the default template registry', () {
      expect(TemplateRegistry.defaults.resolve('mvlempyr'),
          isA<MvlempyrTemplate>());
    });
  });
}

/// Serves a full 500-post first page and a short second page, so the template's
/// pagination loop has to fetch twice and stop when a page is under-full.
class _PagedPostsTransport implements Transport {
  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    if (url.path == '/novel/some-slug') return _novelPage;
    throw TransportException('No fixture for $url');
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    if (url.path != '/wp-json/wp/v2/posts') {
      throw TransportException('No fixture for $url');
    }
    final page = int.tryParse(url.queryParameters['page'] ?? '1') ?? 1;
    if (page == 1) {
      return List.generate(
        500,
        (i) => {
          'acf': {
            'chapter_number': i + 1,
            'novel_code': '12345',
            'ch_name': 'Ch ${i + 1}',
          },
        },
      );
    }
    if (page == 2) {
      return [
        {
          'acf': {
            'chapter_number': 501,
            'novel_code': '12345',
            'ch_name': 'Ch 501',
          },
        },
      ];
    }
    return const [];
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    throw TransportException('No fixture for $url');
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    throw TransportException('No fixture for $url');
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    throw TransportException('No fixture for $url');
  }
}
