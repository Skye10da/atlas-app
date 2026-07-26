import 'package:flutter/foundation.dart';

import 'package:atlas_app/core/services/platform_service_native.dart';
import 'package:atlas_app/core/services/platform_service_stub.dart';

PlatformService createPlatformService() {
  if (kIsWeb) return StubPlatformService();
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    return StubPlatformService();
  }
  return NativePlatformService();
}

abstract class PlatformService {
  void setBrightness(double value);
  void resetBrightness();
  void enableWakeLock();
  void disableWakeLock();
}
