import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';

void main() {
  Map<String, Object?> validJson() => {
    'id': 'mvlempyr',
    'name': 'Mvlempyr',
    'sourceName': 'Mvlempyr',
    'version': '1.2.3',
    'language': 'en',
    'templateId': 'wordpress-api',
    'transport': 'stealth',
    'baseUrl': 'https://example-novel-site.com',
    'capabilities': ['search', 'chapterList', 'chapterContent', 'cover'],
  };

  group('PluginManifest.fromJson', () {
    test('parses a valid manifest', () {
      final manifest = PluginManifest.fromJson(validJson());

      expect(manifest.id, 'mvlempyr');
      expect(manifest.name, 'Mvlempyr');
      expect(manifest.sourceName, 'Mvlempyr');
      expect(
        manifest.version,
        const PluginVersion(major: 1, minor: 2, patch: 3),
      );
      expect(manifest.templateId, 'wordpress-api');
      expect(manifest.transport, 'stealth');
      expect(manifest.language, 'en');
      expect(manifest.baseUrl, 'https://example-novel-site.com');
      expect(manifest.capabilities, hasLength(4));
      expect(manifest.requiresJsRendering, isFalse);
    });

    test('applies defaults for omitted fields', () {
      final manifest = PluginManifest.fromJson({
        'id': 'minimal',
        'version': '1.0.0',
        'templateId': 'html',
        'baseUrl': 'https://min.example',
      });

      expect(manifest.name, 'minimal');
      expect(manifest.sourceName, 'minimal');
      expect(manifest.transport, 'http');
      expect(manifest.language, 'en');
      expect(manifest.capabilities, containsAll(PluginCapability.values));
      expect(manifest.selectorsFile, 'selectors.json');
      expect(manifest.filtersFile, 'filters.json');
    });

    test('missing id throws', () {
      final json = validJson()..remove('id');
      expect(() => PluginManifest.fromJson(json), throwsPluginManifest);
    });

    test('missing templateId throws', () {
      final json = validJson()..remove('templateId');
      expect(() => PluginManifest.fromJson(json), throwsPluginManifest);
    });

    test('invalid version throws', () {
      final json = validJson()..['version'] = 'not-semver';
      expect(() => PluginManifest.fromJson(json), throwsPluginManifest);
    });

    test('missing baseUrl throws', () {
      final json = validJson()..remove('baseUrl');
      expect(() => PluginManifest.fromJson(json), throwsPluginManifest);
    });

    test('unknown capability throws', () {
      final json = validJson()..['capabilities'] = ['search', 'teleport'];
      expect(() => PluginManifest.fromJson(json), throwsPluginManifest);
    });

    test('empty capability list throws', () {
      final json = validJson()..['capabilities'] = <String>[];
      expect(() => PluginManifest.fromJson(json), throwsPluginManifest);
    });
  });

  group('PluginVersion', () {
    test('tryParse accepts plain and prerelease semver', () {
      expect(
        PluginVersion.tryParse('1.0.0'),
        const PluginVersion(major: 1, minor: 0, patch: 0),
      );
      expect(
        PluginVersion.tryParse('2.3.4-beta.1'),
        const PluginVersion(major: 2, minor: 3, patch: 4),
      );
    });

    test('tryParse rejects garbage', () {
      expect(PluginVersion.tryParse('1.2'), isNull);
      expect(PluginVersion.tryParse('abc'), isNull);
      expect(PluginVersion.tryParse(''), isNull);
    });

    test('comparison orders by major then minor then patch', () {
      expect(
        const PluginVersion(
          major: 2,
          minor: 0,
          patch: 0,
        ).compareTo(const PluginVersion(major: 1, minor: 9, patch: 9)),
        greaterThan(0),
      );
      expect(
        const PluginVersion(
          major: 1,
          minor: 2,
          patch: 0,
        ).compareTo(const PluginVersion(major: 1, minor: 1, patch: 9)),
        greaterThan(0),
      );
      expect(
        const PluginVersion(
          major: 1,
          minor: 1,
          patch: 2,
        ).compareTo(const PluginVersion(major: 1, minor: 1, patch: 1)),
        greaterThan(0),
      );
      expect(
        const PluginVersion(
          major: 1,
          minor: 1,
          patch: 1,
        ).compareTo(const PluginVersion(major: 1, minor: 1, patch: 1)),
        0,
      );
    });
  });

  group('PluginVerifier', () {
    test('matchesChecksum verifies sha256 of content', () {
      const verifier = PluginVerifier();
      final checksum = verifier.sha256Of('hello');
      expect(verifier.matchesChecksum('hello', checksum), isTrue);
      expect(verifier.matchesChecksum('hell0', checksum), isFalse);
    });
  });
}

final throwsPluginManifest = throwsA(isA<PluginManifestException>());
