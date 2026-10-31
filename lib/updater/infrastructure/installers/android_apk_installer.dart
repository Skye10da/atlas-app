import 'package:flutter/services.dart';

import 'package:atlas_app/core/logging/logger.dart';

/// Thin bridge to the Android side of the self-update flow
/// (MainActivity's `com.atlasapp/update_install` channel).
///
/// Dart does all network + hashing work; this class only hands an already
/// verified APK to the system installer and surfaces the per-app
/// "install unknown apps" consent state on Android 8+.
class AndroidApkInstaller {
  static const _channel = MethodChannel('com.atlasapp/update_install');

  /// True when the OS will actually show the install dialog without first
  /// bouncing the user to system settings.
  Future<bool> canRequestInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestInstall') ?? false;
    } on PlatformException catch (e, st) {
      AppLogger.error('Updater: canRequestInstall failed', e, st);
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } on PlatformException catch (e, st) {
      AppLogger.error('Updater: openInstallPermissionSettings failed', e, st);
    }
  }

  /// Fires the system "Install this app?" dialog for [apkPath]. Returns the
  /// bare result token from the native side:
  /// `launched` / `permission_needed` / `missing` / `error:<msg>`.
  Future<String> requestInstall(String apkPath) async {
    try {
      return await _channel.invokeMethod<String>('installApk', apkPath) ??
          'error:no_response';
    } on PlatformException catch (e, st) {
      AppLogger.error('Updater: installApk failed', e, st);
      return 'error:${e.code}';
    }
  }
}
