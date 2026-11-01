import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/entities/github_release.dart';
import 'package:atlas_app/marketing/domain/services/release_asset_resolver.dart';

/// Asset-name fixtures over both the canonical contract
/// (`atlas-<version>-<platform>[-<arch>].<ext>`) and legacy names.
GitHubRelease releaseWith(List<GitHubReleaseAsset> assets) =>
    const GitHubRelease(
      tagName: 'v1.0.8',
      name: 'Atlas 1.0.8',
      publishedAt: null,
      body: null,
      htmlUrl: 'https://github.com/Skye10da/atlas-app/releases/latest',
      assets: [],
    ).copyAssets(assets);

extension _ReleaseCopy on GitHubRelease {
  GitHubRelease copyAssets(List<GitHubReleaseAsset> assets) => GitHubRelease(
    tagName: tagName,
    name: name,
    publishedAt: publishedAt,
    body: body,
    htmlUrl: htmlUrl,
    assets: assets,
  );
}

GitHubReleaseAsset asset(String name, {int size = 1024}) => GitHubReleaseAsset(
  name: name,
  browserDownloadUrl: 'https://example.com/$name',
  size: size,
);

void main() {
  const resolver = ReleaseAssetResolver();

  group('ReleaseAssetResolver.resolve', () {
    test('picks the exact platform+arch artifact (windows x64)', () {
      final release = releaseWith([
        asset('atlas-v1.0.8-wide-screenshot.png'),
        asset('atlas-v1.0.8-android.apk'),
        asset('atlas-v1.0.8-windows-x64.zip'),
      ]);
      const profile = DeviceProfile(
        os: DeviceOs.windows,
        arch: DeviceArch.x64,
        osVersion: 'Windows 11',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.downloadUrl, contains('windows-x64.zip'));
      expect(resolved.isExactMatch, isTrue);
      expect(resolved.fileName, 'atlas-v1.0.8-windows-x64.zip');
      expect(resolved.label, 'Atlas 1.0.8 for Windows (x64)');
    });

    test('prefers the arch-tagged asset over universal for arm64 android', () {
      final release = releaseWith([
        asset('atlas-v1.0.8-android.apk'),
        asset('atlas-v1.0.8-android-arm64-v8a.apk'),
      ]);
      const profile = DeviceProfile(
        os: DeviceOs.android,
        arch: DeviceArch.arm64,
        osVersion: '',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.downloadUrl, contains('android-arm64-v8a'));
      expect(resolved.isExactMatch, isTrue);
    });

    test('falls back to the universal android apk on unknown arch', () {
      final release = releaseWith([
        asset('atlas-v1.0.8-android.apk'),
        asset('atlas-v1.0.8-android-arm64-v8a.apk'),
      ]);
      const profile = DeviceProfile(
        os: DeviceOs.android,
        arch: DeviceArch.unknown,
        osVersion: '',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.downloadUrl, contains('v1.0.8-android.apk'));
      expect(resolved.isExactMatch, isTrue);
    });

    test('legacy android names still match on arch tokens', () {
      final release = releaseWith([
        asset('atlas-android-arm64-v1.0.7.apk', size: 48213),
      ]);
      const profile = DeviceProfile(
        os: DeviceOs.android,
        arch: DeviceArch.arm64,
        osVersion: '',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.downloadUrl, contains('atlas-android-arm64-v1.0.7.apk'));
      expect(humanizeBytes(resolved.sizeBytes ?? 0), '47.1 KB');
    });

    test('macos arm64 profile picks the macos artifact', () {
      final release = releaseWith([
        asset('atlas-v1.0.8-macos-arm64.zip'),
        asset('atlas-v1.0.8-windows-x64.zip'),
      ]);
      const profile = DeviceProfile(
        os: DeviceOs.macos,
        arch: DeviceArch.arm64,
        osVersion: 'macOS 14',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.downloadUrl, contains('macos-arm64'));
      expect(resolved.label, 'Atlas 1.0.8 for macOS (arm64)');
    });

    test('windows-ARM device still downloads the x64 zip (emulation run)', () {
      final release = releaseWith([asset('atlas-v1.0.8-windows-x64.zip')]);
      const profile = DeviceProfile(
        os: DeviceOs.windows,
        arch: DeviceArch.arm64,
        osVersion: 'Windows 11',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.downloadUrl, contains('windows-x64.zip'));
      expect(resolved.isExactMatch, isTrue);
    });

    test('iOS / unknown devices get the honest release-page fallback', () {
      final release = releaseWith([asset('atlas-v1.0.8-android.apk')]);
      const iosProfile = DeviceProfile(
        os: DeviceOs.ios,
        arch: DeviceArch.unknown,
        osVersion: '',
      );

      final resolved = resolver.resolve(release: release, profile: iosProfile);

      expect(resolved.isExactMatch, isFalse);
      expect(resolved.downloadUrl, release.releasePageUrl);
      expect(resolved.label, contains('see all downloads'));

      // Undetected (UA probe failed) is the same honest path.
      final fallback = resolver.resolve(
        release: release,
        profile: DeviceProfile.fallback,
      );
      expect(fallback.isExactMatch, isFalse);
    });

    test('images, manifests and hashes never masquerade as downloads', () {
      final release = releaseWith([
        asset('atlas-screenshot-01.png'),
        asset('manifest.json'),
        asset('atlas-v1.0.8-android.apk.sha256sum'),
        asset('atlas-v1.0.8-android.apk'),
      ]);
      const profile = DeviceProfile(
        os: DeviceOs.android,
        arch: DeviceArch.arm64,
        osVersion: '',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      // Only the .apk matches; .sha256sum (wrong ext) must not win.
      expect(resolved.downloadUrl.endsWith('.apk'), isTrue);
      expect(resolved.downloadUrl.contains('.sha256'), isFalse);
    });

    test('no usable assets → release page fallback', () {
      final release = releaseWith(const []);
      const profile = DeviceProfile(
        os: DeviceOs.windows,
        arch: DeviceArch.x64,
        osVersion: '',
      );

      final resolved = resolver.resolve(release: release, profile: profile);

      expect(resolved.isExactMatch, isFalse);
      expect(resolved.downloadUrl, release.releasePageUrl);
    });
  });

  group('ReleaseAssetResolver.allDownloads', () {
    test('labels every downloadable artifact for the manual grid', () {
      final release = releaseWith([
        asset('atlas-v1.0.8-android.apk'),
        asset('atlas-v1.0.8-android-arm64-v8a.apk'),
        asset('atlas-v1.0.8-windows-x64.zip'),
        asset('atlas-v1.0.8-whatsnew.jpg'),
      ]);

      final downloads = resolver.allDownloads(release);

      expect(downloads, hasLength(3));
      final labels = downloads.map((d) => d.label).toSet();
      expect(labels, contains('Android (arm64)'));
      expect(labels, contains('Windows (x64)'));
    });
  });

  group('humanizeBytes', () {
    test('scales binary units', () {
      expect(humanizeBytes(48213), '47.1 KB');
      expect(humanizeBytes(85 * 1024 * 1024), '85 MB');
      expect(humanizeBytes(0), '');
      expect(humanizeBytes(512), '512 B');
    });
  });
}
