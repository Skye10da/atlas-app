import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_catalog.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';

PluginCatalogEntry _entry({
  String id = 'mvlempyr',
  String version = '1.0.0',
  Map<String, String> checksums = const {'plugin.json': 'abc'},
}) => PluginCatalogEntry.fromJson({
  'id': id,
  'version': version,
  'checksums': checksums,
});

void main() {
  group('PluginCatalogEntry.fromJson', () {
    test('parses a well-formed entry', () {
      final entry = _entry(
        version: '2.1.3',
        checksums: const {'plugin.json': 'a1', 'filters.json': 'b2'},
      );
      expect(entry.id, 'mvlempyr');
      expect(entry.version, const PluginVersion(major: 2, minor: 1, patch: 3));
      expect(entry.checksums['filters.json'], 'b2');
    });

    test('rejects a missing id', () {
      expect(
        () => PluginCatalogEntry.fromJson({
          'version': '1.0.0',
          'checksums': {'plugin.json': 'a'},
        }),
        throwsA(isA<PluginCatalogException>()),
      );
    });

    test('rejects a non-semver version', () {
      expect(
        () => _entry(version: 'latest'),
        throwsA(isA<PluginCatalogException>()),
      );
    });

    test('rejects missing or empty checksums', () {
      expect(
        () => _entry(checksums: const {}),
        throwsA(isA<PluginCatalogException>()),
      );
      expect(
        () => _entry(checksums: {'plugin.json': ''}),
        throwsA(isA<PluginCatalogException>()),
      );
    });
  });

  group('PluginCatalog', () {
    test('parses from json and finds entries by id', () {
      final catalog = PluginCatalog.fromJson({
        'plugins': [
          {
            'id': 'a',
            'version': '1.0.0',
            'checksums': {'plugin.json': 'a'},
          },
          {
            'id': 'b',
            'version': '0.9.0',
            'checksums': {'plugin.json': 'b'},
          },
        ],
      });
      expect(catalog.plugins, hasLength(2));
      expect(
        catalog.entryFor('a')?.version,
        const PluginVersion(major: 1, minor: 0, patch: 0),
      );
      expect(catalog.entryFor('missing'), isNull);
    });

    test('rejects a catalog without a plugins list', () {
      expect(
        () => PluginCatalog.fromJson({'foo': []}),
        throwsA(isA<PluginCatalogException>()),
      );
      expect(
        () => PluginCatalog.fromJson({'plugins': 'nope'}),
        throwsA(isA<PluginCatalogException>()),
      );
    });

    test('round-trips through json', () {
      final catalog = PluginCatalog.fromJson({
        'plugins': [
          {
            'id': 'a',
            'version': '1.2.3',
            'checksums': {'plugin.json': 'a'},
          },
        ],
      });
      final roundTripped = PluginCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, Object?>,
      );
      expect(roundTripped.plugins.single.id, 'a');
      expect(
        roundTripped.plugins.single.version,
        const PluginVersion(major: 1, minor: 2, patch: 3),
      );
    });
  });
}
