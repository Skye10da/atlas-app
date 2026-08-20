import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/services/wtr_term_preference_service.dart';

import '../content_engine/test_fixtures.dart';

/// Records the full URL of every `fetchJson` call.
class _RecordingTransport implements Transport {
  _RecordingTransport(this.inner);

  final Transport inner;
  final List<String> jsonGetUrls = [];

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) =>
      inner.fetchHtml(url, headers: headers);

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) => inner.fetchHtmlPost(url, headers: headers, form: form);

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonGetUrls.add(url.toString());
    return inner.fetchJson(url, headers: headers);
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) => inner.fetchJsonPost(url, headers: headers, jsonBody: jsonBody);

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) =>
      inner.fetchBytes(url, headers: headers);
}

void main() {
  final base = Uri.parse('https://wtr-lab.com');
  const preferencesUrl = 'https://wtr-lab.com/api/v2/term-preferences';

  group('WtrTermPreferenceService', () {
    test('parseTop returns the highest-counted replacement', () {
      expect(
        WtrTermPreferenceService.parseTop({
          'success': true,
          'data': [
            {'replacement': 'middle', 'count': 2},
            {'replacement': 'center', 'count': 5},
          ],
        }),
        'center',
      );
    });

    test('parseTop returns null without entries', () {
      expect(
        WtrTermPreferenceService.parseTop({'success': true, 'data': []}),
        isNull,
      );
      expect(WtrTermPreferenceService.parseTop({'success': false}), isNull);
      expect(WtrTermPreferenceService.parseTop(null), isNull);
    });

    test(
      'topPreference fetches the term, picks the top, and caches it',
      () async {
        final transport = _RecordingTransport(
          FakeTransport()..addJson(
            '$preferencesUrl?source_id=id.raw.29058&hash=%E4%B8%AD&lang=en',
            {
              'success': true,
              'data': [
                {'replacement': 'middle', 'count': 1},
                {'replacement': 'center', 'count': 4},
              ],
            },
          ),
        );
        final service = WtrTermPreferenceService();

        final first = await service.topPreference(
          transport,
          base,
          rawId: 29058,
          zh: '中',
          lang: 'en',
        );
        final second = await service.topPreference(
          transport,
          base,
          rawId: 29058,
          zh: '中',
          lang: 'en',
        );

        expect(first, 'center');
        expect(second, 'center');
        expect(transport.jsonGetUrls, hasLength(1));
        expect(
          transport.jsonGetUrls.single,
          contains('source_id=id.raw.29058'),
        );
        expect(transport.jsonGetUrls.single, contains('hash=%E4%B8%AD'));
        expect(transport.jsonGetUrls.single, contains('lang=en'));
      },
    );

    test('is fail-soft when the endpoint errors', () async {
      final service = WtrTermPreferenceService();

      final preference = await service.topPreference(
        FakeTransport(),
        base,
        rawId: 29058,
        zh: '中',
        lang: 'en',
      );

      expect(preference, isNull);
    });

    test('clear() forces a refetch', () async {
      final transport = _RecordingTransport(
        FakeTransport()..addJson(
          '$preferencesUrl?source_id=id.raw.29058&hash=%E4%B8%AD&lang=en',
          {
            'success': true,
            'data': [
              {'replacement': 'middle', 'count': 1},
            ],
          },
        ),
      );
      final service = WtrTermPreferenceService();

      await service.topPreference(
        transport,
        base,
        rawId: 29058,
        zh: '中',
        lang: 'en',
      );
      service.clear();
      await service.topPreference(
        transport,
        base,
        rawId: 29058,
        zh: '中',
        lang: 'en',
      );

      expect(transport.jsonGetUrls, hasLength(2));
    });
  });
}
