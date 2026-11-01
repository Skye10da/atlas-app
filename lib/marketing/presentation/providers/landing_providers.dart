import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/entities/github_release.dart';
import 'package:atlas_app/marketing/domain/services/device_profile_service.dart';
import 'package:atlas_app/marketing/domain/services/download_launcher.dart';
import 'package:atlas_app/marketing/domain/services/github_release_service.dart';
import 'package:atlas_app/marketing/domain/services/release_asset_resolver.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';

final githubReleaseServiceProvider = Provider<GitHubReleaseService>((ref) {
  return GitHubReleaseService();
});

/// Live "latest GitHub release" for the landing page. Resolves to `null` while
/// loading or after a failed lookup; UI layers fall back to curated content.
final latestReleaseProvider = FutureProvider<GitHubRelease?>((ref) async {
  final service = ref.watch(githubReleaseServiceProvider);
  return service.fetchLatestRelease();
});

final deviceProfileServiceProvider = Provider<DeviceProfileService>(
  (ref) => const DeviceProfileService(),
);

/// The visitor's device, detected once per app run on the landing page.
final deviceProfileProvider = FutureProvider<DeviceProfile>(
  (ref) => ref.watch(deviceProfileServiceProvider).detect(),
);

final releaseAssetResolverProvider = Provider<ReleaseAssetResolver>(
  (ref) => const ReleaseAssetResolver(),
);

/// How release files are handed to the browser. Overridden in tests with a
/// recording fake (no real downloads in `flutter test`).
final downloadLauncherProvider = Provider<DownloadLauncher>(
  (ref) => const AnchorDownloadLauncher(),
);

/// Everything the smart download surfaces need in one immutable snapshot:
/// curated/live release, detected device profile, and the resolved artifact.
@immutable
class SmartDownloadState {
  const SmartDownloadState({
    required this.release,
    required this.profile,
    required this.resolved,
    required this.allDownloads,
  });

  final GitHubRelease release;
  final DeviceProfile profile;
  final ResolvedDownload resolved;

  /// Manual-override grid content (every downloadable asset, labeled).
  final List<ResolvedDownload> allDownloads;

  /// True when we confidently matched an actual release asset; false → the
  /// primary action opens the GitHub releases page instead.
  bool get isExactMatch => resolved.isExactMatch;
}

final smartDownloadProvider = Provider<SmartDownloadState>((ref) {
  final release =
      ref.watch(latestReleaseProvider).valueOrNull ?? fallbackGitHubRelease;
  final profile =
      ref.watch(deviceProfileProvider).valueOrNull ?? DeviceProfile.fallback;
  final resolver = ref.watch(releaseAssetResolverProvider);
  return SmartDownloadState(
    release: release,
    profile: profile,
    resolved: resolver.resolve(release: release, profile: profile),
    allDownloads: resolver.allDownloads(release),
  );
});
