import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/updater/application/changelog_controller.dart';
import 'package:atlas_app/updater/application/updater_controller.dart';
import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';
import 'package:atlas_app/updater/infrastructure/github_release_repository.dart';
import 'package:atlas_app/updater/infrastructure/installers/android_apk_installer.dart';
import 'package:atlas_app/updater/infrastructure/installers/windows_updater.dart';
import 'package:atlas_app/updater/infrastructure/release_downloader.dart';

/// Raw SharedPreferences for the updater feature; main.dart pre-warms this
/// instance so resolution is instant at first read.
final updatePrefsStoreProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// The installed app version straight from `PackageInfo.version` (public
/// semver from pubspec, e.g. "1.0.7") — no update-check side effects. The
/// footer and "what's new" badges read this instead of hardcoding versions.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// GitHub Releases feed client. Override the polled repo per build via
/// `--dart-define=UPDATER_REPO=owner/repo` (forks must do this).
final appUpdateRepositoryProvider = Provider<GithubReleaseRepository>((ref) {
  return GithubReleaseRepository(client: ref.watch(httpClientProvider));
});

/// Torrent-free, plain HTTP downloader for release artifacts (reuses the
/// app-wide hardened [http.Client]).
final releaseDownloaderProvider = Provider<ReleaseDownloader>((ref) {
  return ReleaseDownloader(client: ref.watch(httpClientProvider));
});

final androidApkInstallerProvider = Provider<AndroidApkInstaller>(
  (ref) => AndroidApkInstaller(),
);

final windowsUpdaterProvider = Provider<WindowsUpdater>(
  (ref) => WindowsUpdater(),
);

/// Root handle the screens watch: `ref.watch(updaterControllerProvider)`
/// (async) with `ref.read(updaterControllerProvider.notifier)` for actions.
final updaterControllerProvider =
    AsyncNotifierProvider<UpdaterController, UpdaterState>(
      UpdaterController.new,
    );

/// Release-note history for the What's-new screen: cached list first, then
/// [ChangelogController.refresh] merges the live GitHub listing into it.
final changelogControllerProvider =
    AsyncNotifierProvider<ChangelogController, List<ChangelogEntry>>(
      ChangelogController.new,
    );
