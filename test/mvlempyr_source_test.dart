// ignore_for_file: avoid_dynamic_calls

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/sources/mvlempyr_source.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group('MvlempyrSource', () {
    late _MockHttpClient client;
    late MvlempyrSource source;

    setUp(() {
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(const <String, String>{});
      client = _MockHttpClient();
      source = MvlempyrSource(client: client);
    });

    test('produces a novel-category model', () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('<html><body></body></html>', 200));

      final novel = await source.getMetadata(
        Uri.parse('https://www.mvlempyr.io/novel/some-slug'),
      );

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'MVLEMPYR');
    });
  });
}
