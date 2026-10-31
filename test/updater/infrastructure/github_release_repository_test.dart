import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/infrastructure/github_release_repository.dart';

const _manifestJson = <String, dynamic>{
  'version': '1.0.8',
  'versionCode': 8,
  'publishedAt': '2026-10-31T12:00:00Z',
  'artifacts': <String, dynamic>{
    'android': <String, dynamic>{
      'file': 'atlas-v1.0.8+8-android.apk',
      'sha256': 'hash-android',
    },
  },
};

Map<String, dynamic> _releaseJson({
  String tag = 'v1.0.8+8',
  bool prerelease = false,
  bool draft = false,
}) =>
    {
      'tag_name': tag,
      'html_url': 'https://github.com/Skye10da/atlas-app/releases/tag/$tag',
      'draft': draft,
      'prerelease': prerelease,
      'assets': [
        {
          'name': 'atlas-$tag-android.apk',
          'browser_download_url': 'https://example.com/atlas-$tag-android.apk',
        },
        {
          'name': 'manifest.json',
          'browser_download_url': 'https://example.com/manifest.json',
        },
      ],
    };

http.Response _releaseResponse({
  String tag = 'v1.0.8+8',
  bool prerelease = false,
  bool draft = false,
}) {
  final release = _releaseJson(tag: tag, prerelease: prerelease, draft: draft);
  return http.Response(
    json.encode(release),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('GithubReleaseRepository.fetchLatest', () {
    test('stable channel resolves release + manifest.json into one release',
        () async {
      final client = MockClient(
        (request) async {
          if (request.url.path.endsWith('/releases/latest')) {
            return _releaseResponse();
          }
          if (request.url.path.endsWith('/manifest.json')) {
            return http.Response(json.encode(_manifestJson), 200);
          }
          fail('unexpected request: ${request.url}');
        },
      );
      final repo = GithubReleaseRepository(client: client);
      final release = await repo.fetchLatest();

      expect(release, isNotNull);
      expect(release!.version, '1.0.8');
      expect(release.versionCode, 8);
      expect(release.releaseUrl, contains('releases/tag/v1.0.8'));
      expect(
        release.artifacts['android']!.downloadUrl,
        contains('atlas-v1.0.8+8-android.apk'),
      );
      expect(release.artifacts['android']!.sha256, 'hash-android');
    });

    test('404 means "no releases yet" — null, not an error', () async {
      final client = MockClient((request) async {
        return http.Response('{"message": "Not Found"}', 404);
      });
      final repo = GithubReleaseRepository(client: client);
      expect(await repo.fetchLatest(), isNull);
    });

    test('beta channel skips drafts and takes the newest usable entry',
        () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['per_page'] == '10') {
          final drafts = json.encode([
            {'tag_name': 'v1.0.9+9', 'draft': true, 'assets': []},
            _releaseJson(tag: 'v1.0.9-rc.2+11', prerelease: true),
            _releaseJson(tag: 'v1.0.8+8'),
          ]);
          return http.Response(drafts, 200);
        }
        if (request.url.path.endsWith('/manifest.json')) {
          return http.Response(
            json.encode({..._manifestJson, 'version': '1.0.9-rc.2',
              'versionCode': 11}),
            200,
          );
        }
        fail('unexpected request: ${request.url}');
      });
      final repo = GithubReleaseRepository(client: client);
      final release = await repo.fetchLatest(channel: UpdateChannel.beta);

      expect(release!.version, '1.0.9-rc.2');
      expect(release.versionCode, 11);
    });

    test('releases without a manifest.json asset are skipped', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response(
            json.encode(
              <String, dynamic>{
                'tag_name': 'v1.0.8+8',
                'assets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': 'atlas-v1.0.8+8-android.apk',
                    'browser_download_url': 'https://example.com/x.apk',
                  },
                ],
              },
            ),
            200,
          );
        }
        fail('unexpected request: ${request.url}');
      });
      final repo = GithubReleaseRepository(client: client);
      expect(await repo.fetchLatest(), isNull);
    });
  });
}
