import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/updater/application/updater_controller.dart';
import 'package:atlas_app/updater/infrastructure/github_release_repository.dart';
import 'package:atlas_app/updater/infrastructure/installers/android_apk_installer.dart';
import 'package:atlas_app/updater/infrastructure/installers/windows_updater.dart';
import 'package:atlas_app/updater/infrastructure/release_downloader.dart';

/// Raw SharedPreferences for the updater feature; main.dart pre-warms this
/// instance so resolution is instant at first read.
final updatePrefsStoreProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

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
