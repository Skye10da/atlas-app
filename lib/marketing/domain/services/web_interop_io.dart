// Non-web (VM/Windows/desktop/mobile) stub of the landing page web interop.
//
// The landing page targets Flutter Web only; native targets compile this
// stub so the module links everywhere, while runtime calls degrade to the
// neutral paths (no probe, no download trigger) — callers fall back to the
// release page / external navigation accordingly.

import 'package:flutter/foundation.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';

/// The UA Client Hints payload (subset we need), already decoded to strings.
@immutable
class UaClientHints {
  const UaClientHints({
    this.platform,
    this.platformVersion,
    this.architecture,
    this.bitness,
  });

  final String? platform;
  final String? platformVersion;
  final String? architecture;
  final String? bitness;
}

Future<DeviceProbe?> collectDeviceProbe() async => null;

Future<UaClientHints?> fetchUaClientHints() async => null;

bool triggerBrowserDownload(String url, String suggestedFileName) {
  // No browser DOM on native targets; [AnchorDownloadLauncher] routes this
  // into a plain external navigation.
  return false;
}
