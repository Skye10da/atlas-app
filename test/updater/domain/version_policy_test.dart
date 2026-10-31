import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/domain/version_policy.dart';

AppRelease _release(String tag, int versionCode) {
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  return AppRelease(
    tag: tag,
    version: version,
    versionCode: versionCode,
    channel: VersionPolicy.isPrerelease(tag)
        ? UpdateChannel.beta
        : UpdateChannel.stable,
    publishedAt: DateTime.utc(2026, 10, 31),
    artifacts: const {},
  );
}

void main() {
  group('VersionPolicy.isUpdateAvailable', () {
    test('null release is never an update', () {
      expect(
        VersionPolicy.isUpdateAvailable(
          null,
          currentBuild: 7,
        ),
        isFalse,
      );
    });

    test('newer versionCode is an update', () {
      expect(
        VersionPolicy.isUpdateAvailable(
          _release('v1.0.8+8', 8),
          currentBuild: 7,
        ),
        isTrue,
      );
    });

    test('equal or older versionCode never nags', () {
      expect(
        VersionPolicy.isUpdateAvailable(
          _release('v1.0.7+7', 7),
          currentBuild: 7,
        ),
        isFalse,
      );
      expect(
        VersionPolicy.isUpdateAvailable(
          _release('v1.0.6+6', 6),
          currentBuild: 7,
        ),
        isFalse,
      );
    });

    test('same semver with higher build still updates', () {
      expect(
        VersionPolicy.isUpdateAvailable(
          _release('v1.0.7+9', 9),
          currentBuild: 7,
        ),
        isTrue,
      );
    });

    test('explicitly skipped tag is suppressed', () {
      expect(
        VersionPolicy.isUpdateAvailable(
          _release('v1.0.8+8', 8),
          currentBuild: 7,
          skippedTag: 'v1.0.8+8',
        ),
        isFalse,
      );
    });

    test('a newer version supersedes the skipped tag', () {
      expect(
        VersionPolicy.isUpdateAvailable(
          _release('v1.0.8+8', 8),
          currentBuild: 7,
          skippedTag: 'v1.0.7+7',
        ),
        isTrue,
      );
    });
  });

  group('VersionPolicy.compareVersions', () {
    test('major/minor/patch ordering', () {
      expect(VersionPolicy.compareVersions('1.0.7', '1.0.8'), lessThan(0));
      expect(VersionPolicy.compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(VersionPolicy.compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(VersionPolicy.compareVersions('1.0.8', '1.0.8'), 0);
    });

    test('misaligned component counts', () {
      expect(VersionPolicy.compareVersions('1.2', '1.2.0'), 0);
      expect(VersionPolicy.compareVersions('1.2', '1.2.1'), lessThan(0));
    });

    test('non-numeric components compare as zero', () {
      expect(VersionPolicy.compareVersions('1.0.x', '1.0.1'), lessThan(0));
    });
  });

  group('VersionPolicy.versionCodeOfTag', () {
    test('parses build suffix', () {
      expect(VersionPolicy.versionCodeOfTag('v1.0.8+8'), 8);
      expect(VersionPolicy.versionCodeOfTag('v1.0.9-rc.1+9'), 9);
      expect(VersionPolicy.versionCodeOfTag('1.0.8+42'), 42);
    });

    test('null without a build suffix', () {
      expect(VersionPolicy.versionCodeOfTag('v1.0.8'), isNull);
      expect(VersionPolicy.versionCodeOfTag('v1.0.8+'), isNull);
    });
  });

  group('VersionPolicy.isPrerelease', () {
    test('pure semver is stable', () {
      expect(VersionPolicy.isPrerelease('v1.0.8+8'), isFalse);
      expect(VersionPolicy.isPrerelease('1.0.8'), isFalse);
    });

    test('dash suffix in the semver portion marks a prerelease', () {
      expect(VersionPolicy.isPrerelease('v1.0.9-rc.1+9'), isTrue);
      expect(VersionPolicy.isPrerelease('1.0.9-beta.2'), isTrue);
    });
  });
}
