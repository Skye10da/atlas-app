import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/updater/application/updater_controller.dart';
import 'package:atlas_app/updater/infrastructure/installers/android_apk_installer.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// Records the hand-off without touching a real MethodChannel.
class _FakeApkInstaller extends AndroidApkInstaller {
  String result = 'launched';
  Object? failWith;
  int requestCount = 0;
  int settingsCount = 0;
  String? requestedPath;

  @override
  Future<String> requestInstall(String apkPath) async {
    requestCount++;
    requestedPath = apkPath;
    final failure = failWith;
    if (failure != null) throw failure;
    return result;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    settingsCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File apk;
  late _FakeApkInstaller installer;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atlas_updater_test');
    apk = File('${tempDir.path}${Platform.pathSeparator}atlas.apk')
      ..writeAsBytesSync([1, 2, 3]);

    // A finished download restored from disk: build() lands in readyToInstall.
    SharedPreferences.setMockInitialValues({
      'app_update_downloaded_tag': 'v9.9.9+99',
      'app_update_downloaded_path': apk.path,
    });
    final prefs = await SharedPreferences.getInstance();

    PackageInfo.setMockInitialValues(
      appName: 'Atlas',
      packageName: 'com.atlasapp.sk.atlas_app',
      version: '1.0.10',
      buildNumber: '10',
      buildSignature: '',
      installerStore: null,
    );

    installer = _FakeApkInstaller();
    container = ProviderContainer(
      overrides: [
        updatePrefsStoreProvider.overrideWith((ref) async => prefs),
        // Host tests are never Android; force the Android install branch.
        updaterPlatformTargetProvider.overrideWithValue('android'),
        androidApkInstallerProvider.overrideWithValue(installer),
      ],
    );
    addTearDown(() {
      container.dispose();
      tempDir.deleteSync(recursive: true);
    });
  });

  Future<UpdaterState> readState() =>
      container.read(updaterControllerProvider.future);

  test('restores a downloaded update into readyToInstall', () async {
    final state = await readState();
    expect(state.phase, UpdaterPhase.readyToInstall);
    expect(state.downloadedTag, 'v9.9.9+99');
  });

  test('permission_needed opens the system settings and surfaces why',
      () async {
    await readState();
    installer.result = 'permission_needed';
    final notifier = container.read(updaterControllerProvider.notifier);

    await notifier.install();

    final state = container.read(updaterControllerProvider).value!;
    expect(installer.requestedPath, apk.path);
    expect(installer.requestCount, 1);
    // The tap must not dead-end: the settings screen is opened for the user.
    expect(installer.settingsCount, 1);
    // And the button is usable again for the second (successful) tap.
    expect(state.phase, UpdaterPhase.readyToInstall);
    expect(state.error, contains('Install unknown apps'));
  });

  test('a successful hand-off stays installing and retry re-runs it',
      () async {
    await readState();
    final notifier = container.read(updaterControllerProvider.notifier);

    await notifier.install();
    expect(
      container.read(updaterControllerProvider).value!.phase,
      UpdaterPhase.installing,
    );
    expect(installer.requestCount, 1);

    // The user dismissed the system installer without installing.
    await notifier.retryInstall();
    expect(installer.requestCount, 2);
    expect(
      container.read(updaterControllerProvider).value!.phase,
      UpdaterPhase.installing,
    );
  });

  test('a failing channel call leaves an error instead of hanging',
      () async {
    await readState();
    installer.failWith = Exception('channel died');
    final notifier = container.read(updaterControllerProvider.notifier);

    await notifier.install();

    final state = container.read(updaterControllerProvider).value!;
    expect(state.phase, UpdaterPhase.error);
    expect(state.error, isNotNull);
  });
}
