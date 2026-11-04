import 'dart:io';

import 'package:flutter/foundation.dart';

/// `android` / `windows` / `macos` / `linux` / `ios` / `web` — matches the
/// artifact keys produced by tool/generate_manifest.py.
///
/// Kept as a plain function (rather than inlined in [UpdaterController]) so
/// tests can drive the Android install path on a desktop host by overriding
/// `updaterPlatformTargetProvider`.
String platformTargetForCurrentDevice() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
