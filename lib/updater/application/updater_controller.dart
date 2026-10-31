import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/domain/repositories/app_update_repository.dart';
import 'package:atlas_app/updater/domain/version_policy.dart';
import 'package:atlas_app/updater/infrastructure/release_downloader.dart';
import 'package:atlas_app/updater/infrastructure/update_prefs_store.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// Lifecycle of the self-updater, surfaced verbatim by the UI.
enum UpdaterPhase {
  /// Fresh state; nothing checked yet in this session.
  idle,

  /// Querying the GitHub Releases feed.
  checking,

  /// Checked: already on the newest available release.
  upToDate,

  /// A newer release is downloadable.
  available,

  /// Artifact is downloading ([UpdaterState.downloadProgress] tracks it).
  downloading,

  /// The verified install file is on disk, waiting for the user's tap.
  readyToInstall,

  /// Installer handed off to the OS (Android) or swap script (Windows).
  installing,

  /// Terminal failure of the last operation; message in [UpdaterState.error].
  error,
}

@immutable
class UpdaterState {
  const UpdaterState({
    this.phase = UpdaterPhase.idle,
    this.release,
    this.currentVersion = '',
    this.currentBuild = 0,
    this.downloadProgress = 0,
    this.error,
    this.autoCheck = true,
    this.channel = UpdateChannel.stable,
    this.skippedTag,
    this.installAvailable = true,
    this.downloadedTag,
  });

  final UpdaterPhase phase;

  /// Newest release fetched from GitHub (set from `available` onwards).
  final AppRelease? release;

  /// Version of the currently installed binary (PackageInfo).
  final String currentVersion;
  final int currentBuild;

  /// 0.0 … 1.0 while [UpdaterPhase.downloading].
  final double downloadProgress;

  /// User-presentable failure message for [UpdaterPhase.error].
  final String? error;

  /// Mirrors the persisted user settings.
  final bool autoCheck;
  final UpdateChannel channel;
  final String? skippedTag;

  /// False on platforms without an in-app installer yet (macOS, Linux, iOS,
  /// web): those show a "view releases on GitHub" affordance instead.
  final bool installAvailable;

  /// Tag of an update already downloaded & verified on disk.
  final String? downloadedTag;

  bool get canAct =>
      phase != UpdaterPhase.checking && phase != UpdaterPhase.downloading;

  /// Sentinel for "no change" so [copyWith] can also clear nullable fields.
  static const _unset = Object();

  UpdaterState copyWith({
    UpdaterPhase? phase,
    AppRelease? release,
    String? currentVersion,
    int? currentBuild,
    double? downloadProgress,
    Object? error = _unset,
    bool? autoCheck,
    UpdateChannel? channel,
    String? skippedTag,
    bool? installAvailable,
    Object? downloadedTag = _unset,
  }) =>
      UpdaterState(
        phase: phase ?? this.phase,
        release: release ?? this.release,
        currentVersion: currentVersion ?? this.currentVersion,
        currentBuild: currentBuild ?? this.currentBuild,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        error: error == _unset ? this.error : error as String?,
        autoCheck: autoCheck ?? this.autoCheck,
        channel: channel ?? this.channel,
        skippedTag: skippedTag ?? this.skippedTag,
        installAvailable: installAvailable ?? this.installAvailable,
        downloadedTag: downloadedTag == _unset
            ? this.downloadedTag
            : downloadedTag as String?,
      );
}

/// Owns the check → download → install state machine. State that survives a
/// process restart (a previously downloaded, hash-verified file) is restored
/// in `build()`.
class UpdaterController extends AsyncNotifier<UpdaterState> {
  late UpdatePrefsStore _prefs;

  @override
  Future<UpdaterState> build() async {
    final store = UpdatePrefsStore(
      await ref.watch(updatePrefsStoreProvider.future),
    );
    _prefs = store;

    final packageInfo = await PackageInfo.fromPlatform();
    final platformTarget = _platformTarget();
    final installAvailable =
        platformTarget == 'android' || platformTarget == 'windows';

    final initialState = UpdaterState(
      currentVersion: packageInfo.version,
      currentBuild: int.tryParse(packageInfo.buildNumber) ?? 0,
      autoCheck: store.autoCheck,
      channel: store.channel,
      skippedTag: store.skippedTag,
      installAvailable: installAvailable,
      downloadedTag: store.downloadedTag,
    );

    // Restore a finished-but-not-installed download across process restarts.
    final downloadedPath = store.downloadedPath;
    if (store.downloadedTag != null && downloadedPath != null) {
      if (await File(downloadedPath).exists()) {
        return initialState.copyWith(
          phase: UpdaterPhase.readyToInstall,
          downloadedTag: store.downloadedTag,
        );
      }
      // The temp file aged out (OS cleanup): fall back to a fresh check.
      store
        ..downloadedTag = null
        ..downloadedPath = null;
    }

    return initialState;
  }

  /// Silent startup path: only acts when auto-check is on and the last check
  /// is older than the 24-hour throttle window. Failures are swallowed
  /// deliberately — a background check must never surface errors.
  Future<void> maybeAutoCheck() async {
    if (!_prefs.autoCheck) return;
    final last = _prefs.lastCheckedAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 24)) {
      return;
    }
    try {
      await _check(manual: false);
    } on AppUpdateException {
      // Expected whenever offline; nothing to do.
    } catch (e, st) {
      AppLogger.error('Updater: background check crashed', e, st);
    }
  }

  /// User-initiated "Check now" — surfaces errors in the UI on failure.
  Future<void> checkNow() => _check(manual: true);

  Future<void> _check({required bool manual}) async {
    final current = state.valueOrNull ?? const UpdaterState();
    if (!current.canAct) return;

    state = AsyncData(current.copyWith(phase: UpdaterPhase.checking, error: null));

    final AppRelease? release;
    try {
      release =
          await ref.read(appUpdateRepositoryProvider).fetchLatest(
                channel: _prefs.channel,
              );
    } on AppUpdateException catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          phase: UpdaterPhase.error,
          error: e.userMessage,
        ),
      );
      if (manual) rethrow; // the caller (screen) also shows a snackbar
      return;
    }

    _prefs.lastCheckedAt = DateTime.now();

    final updateReady = VersionPolicy.isUpdateAvailable(
      release,
      currentBuild: current.currentBuild,
      skippedTag: _prefs.skippedTag,
    );

    state = AsyncData(
      (state.valueOrNull ?? current).copyWith(
        phase: updateReady ? UpdaterPhase.available : UpdaterPhase.upToDate,
        release: release,
        error: null,
      ),
    );
  }

  /// "Skip this version" — remembered until a newer one appears.
  Future<void> skipThisVersion() async {
    final release = state.valueOrNull?.release;
    if (release == null) return;
    _prefs.skippedTag = release.tag;
    state = AsyncData(
      (state.valueOrNull ?? const UpdaterState())
          .copyWith(skippedTag: release.tag, phase: UpdaterPhase.upToDate),
    );
  }

  Future<void> setAutoCheck(bool value) async {
    _prefs.autoCheck = value;
    state = AsyncData(
      (state.valueOrNull ?? const UpdaterState()).copyWith(autoCheck: value),
    );
  }

  Future<void> setChannel(UpdateChannel value) async {
    _prefs.channel = value;
    state = AsyncData(
      (state.valueOrNull ?? const UpdaterState()).copyWith(channel: value),
    );
  }

  /// Streams the platform artifact (if any) into the verified temp location.
  Future<void> startDownload() async {
    final current = state.valueOrNull;
    final release = current?.release;
    if (current == null || release == null || !current.canAct) return;

    final artifact = release.artifactFor(_platformTarget());
    if (artifact == null) {
      throw AppUpdateException(
        'No ${_platformTarget()} artifact was attached to this release.',
      ); // surfaced by the caller as a snackbar; state stays available
    }

    state = AsyncData(
      current.copyWith(phase: UpdaterPhase.downloading, downloadProgress: 0),
    );
    try {
      await for (final event
          in ref.read(releaseDownloaderProvider).download(artifact)) {
        switch (event) {
          case DownloadProgress(fraction: final value):
            state = AsyncData(
              (state.valueOrNull ?? current).copyWith(downloadProgress: value),
            );
          case DownloadDone(filePath: final path):
            _prefs
              ..downloadedTag = release.tag
              ..downloadedPath = path;
            state = AsyncData(
              (state.valueOrNull ?? current).copyWith(
                phase: UpdaterPhase.readyToInstall,
                downloadedTag: release.tag,
                downloadProgress: 1,
              ),
            );
        }
      }
    } on AppUpdateException catch (e, st) {
      AppLogger.error('Updater: download failed', e, st);
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          phase: UpdaterPhase.error,
          error: e.userMessage,
        ),
      );
    }
  }

  /// Hands the verified file to the platform installer. On Android 8+ the OS
  /// may bounce the user to "install unknown apps"; the native side guides
  /// that flow and the state machine re-arms for a second tap.
  Future<void> install() async {
    final current = state.valueOrNull;
    final path = _prefs.downloadedPath;
    if (current == null ||
        current.phase != UpdaterPhase.readyToInstall ||
        path == null) {
      return;
    }

    state = AsyncData(current.copyWith(phase: UpdaterPhase.installing));

    final target = _platformTarget();
    String result;
    switch (target) {
      case 'android':
        result = await ref.read(androidApkInstallerProvider).requestInstall(path);
      case 'windows':
        // swap-on-restart: spawn the swap script, then let the process exit so
        // it can replace files while no Atlas process holds them.
        await ref.read(windowsUpdaterProvider).apply(path);
        state = AsyncData(current.copyWith(phase: UpdaterPhase.installing));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        exit(0); // Never returns — the swap script takes over.
      default:
        result = 'unsupported';
    }

    state = AsyncData(
      switch (result) {
        'launched' => current.copyWith(phase: UpdaterPhase.installing),
        'permission_needed' => current.copyWith(
            phase: UpdaterPhase.readyToInstall,
            error:
                'Grant "Install unknown apps" for Atlas in the next screen, '
                'then tap Install again.',
          ),
        'missing' => current.copyWith(
            phase: UpdaterPhase.error,
            error: 'The downloaded update file is gone — check again.',
          ),
        _ => current.copyWith(
            phase: UpdaterPhase.error,
            error: 'Could not start the system installer for this update.',
          ),
      },
    );
  }

  /// Discards a downloaded file (user changed mind or the file aged out).
  Future<void> discardDownload() async {
    final path = _prefs.downloadedPath;
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
    _prefs
      ..downloadedTag = null
      ..downloadedPath = null;
    state = AsyncData(
      (state.valueOrNull ?? const UpdaterState()).copyWith(
        phase: UpdaterPhase.idle,
        downloadedTag: null,
        downloadProgress: 0,
        error: null,
      ),
    );
  }

  /// Returns to the neutral "update available" phase, dropping an error.
  void dismissError() {
    final current = state.valueOrNull ?? const UpdaterState();
    state = AsyncData(
      current.copyWith(
        phase: current.release != null
            ? UpdaterPhase.available
            : UpdaterPhase.upToDate,
        error: null,
      ),
    );
  }
}

/// `android` / `windows` / `macos` / `linux` / `ios` / `web` — matches the
/// artifact keys produced by tool/generate_manifest.py.
String _platformTarget() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
