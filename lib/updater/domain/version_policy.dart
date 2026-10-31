import 'package:atlas_app/updater/domain/entities/app_release.dart';

/// Pure version logic for the self-updater. Deliberately dependency-free so
/// it can be exhaustively unit-tested and reused from both the controller and
/// background isolate contexts.
class VersionPolicy {
  const VersionPolicy._();

  /// True when [release] should actually be offered to the user.
  ///
  /// The versionCode (the `+<build>` number) is the primary discriminator —
  /// it increases monotonically. Ties on versionCode never count as updates,
  /// so re-publishing the same build does not nag anyone.
  ///
  /// A release the user explicitly skipped ([skippedTag]) is never offered
  /// again until an even newer version appears.
  static bool isUpdateAvailable(
    AppRelease? release, {
    required int currentBuild,
    String? skippedTag,
  }) {
    if (release == null) return false;
    if (release.versionCode <= currentBuild) return false;
    if (skippedTag != null && skippedTag == release.tag) return false;
    return true;
  }

  /// Component-wise comparison of two `MAJOR.MINOR.PATCH` semver strings.
  ///
  /// Returns a negative number, zero, or a positive number as [a] sorts
  /// before, equal to, or after [b]. Unparseable components compare as 0 and
  /// shorter strings as "older", mirroring dotted numeric ordering.
  static int compareVersions(String a, String b) {
    final aParts = a.split('.');
    final bParts = b.split('.');
    final len = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;
    for (var i = 0; i < len; i++) {
      final aNum = int.tryParse(i < aParts.length ? aParts[i] : '') ?? 0;
      final bNum = int.tryParse(i < bParts.length ? bParts[i] : '') ?? 0;
      if (aNum != bNum) return aNum.compareTo(bNum);
    }
    return 0;
  }

  /// Extracts the numeric build number from a tag like `v1.0.8+8` (null when
  /// the tag carries no `+<build>` suffix).
  static int? versionCodeOfTag(String tag) {
    final plus = tag.indexOf('+');
    if (plus < 0 || plus == tag.length - 1) return null;
    return int.tryParse(tag.substring(plus + 1));
  }

  /// True when the tag is a prerelease (`v1.0.9-rc.1+9` style): the semver
  /// portion (between `v` and `+`) contains a `-` suffix. These belong to the
  /// beta channel only.
  static bool isPrerelease(String tag) {
    final semver = tag
        .startsWith('v')
        ? tag.substring(1)
        : tag;
    final plus = semver.indexOf('+');
    final core = plus > 0 ? semver.substring(0, plus) : semver;
    return core.contains('-');
  }
}
