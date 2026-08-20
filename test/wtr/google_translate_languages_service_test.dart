import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';
import 'package:atlas_app/wtr/domain/services/google_translate_languages_service.dart';

class _FakeTransport implements Transport {
  _FakeTransport(this.json);

  final Object? json;

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async =>
      json;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) => throw UnimplementedError();

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) => throw UnimplementedError();

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
}

class _ThrowingTransport implements Transport {
  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) =>
      throw const TransportException('boom');

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) => throw UnimplementedError();

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) => throw UnimplementedError();

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
}

void main() {
  const service = GoogleTranslateLanguagesService();

  group('GoogleTranslateLanguagesService', () {
    test('parses the current object shape from the tl map', () async {
      final transport = _FakeTransport({
        'sl': {'auto': 'Detect language', 'en': 'English'},
        'tl': {
          'en': 'English',
          'es': 'Spanish',
          'zh-CN': 'Chinese (Simplified)',
        },
        'al': <String, String>{},
      });

      final languages = await service.fetchSupportedLanguages(transport);

      expect(languages.length, 3);
      expect(languages.map((l) => l.code).toList(), ['zh-CN', 'en', 'es']);

      final english = languages.firstWhere((l) => l.code == 'en');
      expect(english.name, 'English');
      expect(english.nativeName, 'English');
      expect(english.flag, '🇺🇸');

      final zh = languages.firstWhere((l) => l.code == 'zh-CN');
      expect(zh.name, 'Chinese (Simplified)');
      expect(zh.flag, '🇨🇳');

      final spanish = languages.firstWhere((l) => l.code == 'es');
      expect(spanish.nativeName, 'Español');
    });

    test('uses the neutral globe for languages without a known flag', () async {
      final transport = _FakeTransport({
        'tl': {'ace': 'Acehnese', 'en': 'English'},
      });

      final languages = await service.fetchSupportedLanguages(transport);
      final acehnese = languages.firstWhere((l) => l.code == 'ace');
      expect(acehnese.name, 'Acehnese');
      expect(acehnese.flag, '🌐');
    });

    test('still parses the legacy flat-list shape', () async {
      final transport = _FakeTransport([
        ['en', 'English'],
        ['es', 'Spanish'],
      ]);

      final languages = await service.fetchSupportedLanguages(transport);
      expect(languages.map((l) => l.code).toList(), ['en', 'es']);
      expect(languages.first.flag, '🇺🇸');
    });

    test('falls back to defaults on a malformed response', () async {
      final transport = _FakeTransport('not json at all');
      expect(
        await service.fetchSupportedLanguages(transport),
        SupportedLanguage.defaults,
      );
    });

    test('falls back to defaults when the transport throws', () async {
      expect(
        await service.fetchSupportedLanguages(_ThrowingTransport()),
        SupportedLanguage.defaults,
      );
    });
  });
}
