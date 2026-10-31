import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/infrastructure/manifest_codec.dart';

const Map<String, dynamic> _validManifest = <String, dynamic>{
  'version': '1.0.8',
  'versionCode': 8,
  'publishedAt': '2026-10-31T12:00:00Z',
  'artifacts': <String, dynamic>{
    'android': <String, dynamic>{
      'file': 'atlas-v1.0.8+8-android.apk',
      'sha256': 'abc123def456',
      'size': 48123895,
    },
    'windows': <String, dynamic>{
      'file': 'atlas-v1.0.8+8-windows.zip',
      'sha256': 'deadbeef00ff',
      'size': 88123895,
    },
  },
};

const List<Map<String, dynamic>> _assetList = <Map<String, dynamic>>[
  <String, dynamic>{
    'name': 'atlas-v1.0.8+8-android.apk',
    'browser_download_url':
        'https://github.com/Skye10da/atlas-app/releases/download/v1.0.8%2B8/atlas-v1.0.8%2B8-android.apk',
  },
  <String, dynamic>{
    'name': 'atlas-v1.0.8+8-windows.zip',
    'browser_download_url':
        'https://github.com/Skye10da/atlas-app/releases/download/v1.0.8%2B8/atlas-v1.0.8%2B8-windows.zip',
  },
  <String, dynamic>{
    'name': 'manifest.json',
    'browser_download_url':
        'https://github.com/Skye10da/atlas-app/releases/download/v1.0.8%2B8/manifest.json',
  },
];

void main() {
  late ManifestCodec codec;
  setUp(() => codec = const ManifestCodec());

  group('findManifestJson', () {
    test('returns the manifest asset URL', () {
      expect(codec.findManifestJson(_assetList), contains('manifest.json'));
    });

    test('null when the release has no manifest asset', () {
      final assets = _assetList
          .where((a) => a['name'] != 'manifest.json')
          .toList();
      expect(codec.findManifestJson(assets), isNull);
    });
  });

  group('parseManifest', () {
    test('parses a well-formed manifest', () {
      final release = codec.parseManifest(_validManifest);
      expect(release, isNotNull);
      expect(release!.version, '1.0.8');
      expect(release.versionCode, 8);
      expect(release.tag, 'v1.0.8');
      expect(release.channel, UpdateChannel.stable);
      expect(release.publishedAt, DateTime.utc(2026, 10, 31, 12));
      expect(release.artifacts.keys, containsAll(['android', 'windows']));
      expect(release.artifacts['android']!.sha256, 'abc123def456');
    });

    test('beta channel for prerelease semver', () {
      final release = codec.parseManifest({
        ..._validManifest,
        'version': '1.0.9-rc.1',
      });
      expect(release!.channel, UpdateChannel.beta);
      expect(release.tag, 'v1.0.9-rc.1');
    });

    test('malformed manifests degrade to null instead of throwing', () {
      expect(codec.parseManifest({}), isNull);
      expect(
        codec.parseManifest({..._validManifest, 'version': ''}),
        isNull,
      );
      expect(
        codec.parseManifest({..._validManifest, 'versionCode': 'eight'}),
        isNull,
      );
      expect(
        codec.parseManifest({..._validManifest, 'artifacts': {}}),
        isNull,
      );
      expect(
        codec.parseManifest({..._validManifest, 'artifacts': null}),
        isNull,
      );
      expect(
        codec.parseManifest({..._validManifest, 'publishedAt': 'yesterday'}),
        isNull,
      );
      // Artifact record missing its hash.
      expect(
        codec.parseManifest({
          ..._validManifest,
          'artifacts': {
            'android': {'file': 'x.apk'},
          },
        }),
        isNull,
      );
    });
  });

  group('withAssetUrls', () {
    test('pairs manifest filenames with real download URLs', () {
      final release = codec.parseManifest(_validManifest)!;
      final patched = codec.withAssetUrls(release, _assetList);
      expect(
        patched.artifacts['android']!.downloadUrl,
        contains('atlas-v1.0.8%2B8-android.apk'),
      );
      expect(
        patched.artifacts['windows']!.downloadUrl,
        contains('atlas-v1.0.8%2B8-windows.zip'),
      );
    });

    test('drops artifacts missing from the release assets', () {
      final release = codec.parseManifest(_validManifest)!;
      // Asset list only carries the Android file.
      final androidOnly = [
        _assetList.first,
      ];
      final patched = codec.withAssetUrls(release, androidOnly);
      expect(patched.artifacts.keys, ['android']);
    });
  });
}
