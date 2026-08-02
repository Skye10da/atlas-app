import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/templates/wordpress_api_template.dart';

import 'test_fixtures.dart';

void main() {
  group('WordPressApiTemplate.chapterContent', () {
    test('uses content.rendered from the REST post when available', () async {
      final transport = FakeTransport()
        ..addJson('https://example.com/wp-json/wp/v2/posts', <Object?>[
          {
            'title': {'rendered': 'REST Chapter Title'},
            'content': {'rendered': '<p>REST <em>content</em> here.</p>'},
            'date': '2024-06-01T10:00:00',
            'link': 'https://example.com/novel/rest-chapter',
          },
        ]);
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(templateId: 'wordpress-api'),
      );

      final doc = await const WordPressApiTemplate()
          .chapterContent(context, 'https://example.com/novel/rest-chapter');

      expect(doc.title, 'REST Chapter Title');
      expect(doc.renderToText(), contains('REST content here.'));
    });

    test('falls back to scraping when the REST endpoint is unavailable',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/scraped',
            '<html><body><p>Scraped fallback text.</p></body></html>');
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(templateId: 'wordpress-api'),
      );

      final doc = await const WordPressApiTemplate()
          .chapterContent(context, 'https://example.com/novel/scraped');

      expect(doc.renderToText(), contains('Scraped fallback text.'));
    });
  });

  group('WordPressApiTemplate.metadata', () {
    test('prefers REST post title over the scraped page', () async {
      final transport = FakeTransport()
        ..addJson('https://example.com/wp-json/wp/v2/posts', <Object?>[
          {
            'title': {'rendered': 'REST Novel Title'},
            'link': 'https://example.com/novel/rest-title',
          },
        ]);
      final context = buildContext(
        transport: transport,
        manifest: buildManifest(templateId: 'wordpress-api'),
      );

      final metadata = await const WordPressApiTemplate()
          .metadata(context, 'https://example.com/novel/rest-title');

      expect(metadata.title, 'REST Novel Title');
      expect(metadata.sourceId, 'https://example.com/novel/rest-title');
    });
  });
}
