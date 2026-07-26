import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:atlas_app/core/services/platform_service.dart';

class NativePlatformService implements PlatformService {
  @override
  void setBrightness(double value) {
    try {
      ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  @override
  void resetBrightness() {
    try {
      ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  @override
  void enableWakeLock() {
    WakelockPlus.enable();
  }

  @override
  void disableWakeLock() {
    WakelockPlus.disable();
  }
}
