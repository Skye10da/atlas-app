import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/marketing/domain/entities/github_release.dart';

void main() {
  group('GitHubReleaseAsset', () {
    test('detects image assets', () {
      const png = GitHubReleaseAsset(
        name: 'atlas-screenshot-1.png',
        browserDownloadUrl: 'https://example.com/1.png',
        size: 1024,
      );
      const apk = GitHubReleaseAsset(
        name: 'atlas-android-arm64-v1.0.0.apk',
        browserDownloadUrl: 'https://example.com/app.apk',
        size: 48213,
      );

      expect(png.isImage, isTrue);
      expect(apk.isImage, isFalse);
    });
  });

  group('GitHubRelease', () {
    test('maps the latest-release JSON payload', () {
      final release = GitHubRelease.fromJson(<String, dynamic>{
        'tag_name': 'v1.0.7',
        'name': 'Atlas 1.0.7',
        'body': '## Atlas 1.0.7',
        'html_url': 'https://github.com/Skye10da/atlas-app/releases/tag/v1.0.7',
        'assets': <dynamic>[
          {
            'name': 'atlas-android-arm64-v1.0.0.apk',
            'browser_download_url':
                'https://github.com/Skye10da/atlas-app/releases/download/v1.0.7/atlas-android-arm64-v1.0.0.apk',
            'size': 48213,
          },
        ],
      });

      expect(release.tagName, 'v1.0.7');
      expect(release.versionLabel, '1.0.7');
      expect(release.name, 'Atlas 1.0.7');
      expect(release.body, '## Atlas 1.0.7');
      expect(release.assets, hasLength(1));
      expect(release.assets.first.isImage, isFalse);
      expect(
        release.releasePageUrl,
        'https://github.com/Skye10da/atlas-app/releases/tag/v1.0.7',
      );
    });

    test('defaults when the payload is sparse', () {
      final release = GitHubRelease.fromJson(<String, dynamic>{});
      expect(release.tagName, 'v1.0.7');
      expect(release.versionLabel, '1.0.7');
      expect(release.body, isNull);
      expect(release.assets, isEmpty);
    });

    test('picks the android artifact from release assets', () {
      const release = GitHubRelease(
        tagName: 'v1.0.7',
        name: 'Atlas 1.0.7',
        publishedAt: null,
        body: null,
        htmlUrl: 'https://github.com/Skye10da/atlas-app/releases/latest',
        assets: [
          GitHubReleaseAsset(
            name: 'atlas-android-arm64-v1.0.7.apk',
            browserDownloadUrl: 'https://example.com/android.apk',
            size: 123,
          ),
          GitHubReleaseAsset(
            name: 'atlas-screenshot-1.png',
            browserDownloadUrl: 'https://example.com/shot.png',
            size: 456,
          ),
        ],
      );

      expect(
        release.assetForPlatform('android')?.name,
        'atlas-android-arm64-v1.0.7.apk',
      );
      expect(release.assetForPlatform('ios'), isNull);
      expect(release.assetForPlatform('desktop'), isNull);
    });
  });
}
