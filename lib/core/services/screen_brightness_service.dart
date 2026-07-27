import 'package:screen_brightness_pro/screen_brightness_pro.dart';

import 'package:atlas_app/core/services/platform_service.dart';

class ScreenBrightnessService implements PlatformService {
  @override
  Future<void> setBrightness(double value, {bool smooth = false}) async {
    try {
      await ScreenBrightnessPro.setBrightness(value, smooth: smooth);
    } catch (_) {}
  }

  @override
  Future<double> getBrightness() async {
    try {
      return await ScreenBrightnessPro.getBrightness();
    } catch (_) {
      return 1.0;
    }
  }

  @override
  Future<void> resetBrightness() async {
    try {
      await ScreenBrightnessPro.resetBrightness();
    } catch (_) {}
  }

  @override
  Future<void> setKeepScreenOn(bool value) async {
    try {
      await ScreenBrightnessPro.setKeepScreenOn(value);
    } catch (_) {}
  }

  @override
  Future<double> getBatteryLevel() async {
    try {
      return await ScreenBrightnessPro.getBatteryLevel();
    } catch (_) {
      return 1.0;
    }
  }

  @override
  Future<bool> isLowPowerModeEnabled() async {
    try {
      return await ScreenBrightnessPro.isLowPowerModeEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> optimizeForLowBattery() async {
    try {
      await ScreenBrightnessPro.optimizeForLowBattery();
    } catch (_) {}
  }
}
