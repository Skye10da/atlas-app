import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:screen_brightness_pro/screen_brightness_pro.dart';

import 'package:atlas_app/core/services/platform_service.dart';

class ScreenBrightnessService implements PlatformService {
  final Battery _battery = Battery();

  bool _isOnPower(BatteryState state) {
    return state == BatteryState.charging ||
        state == BatteryState.full ||
        state == BatteryState.connectedNotCharging;
  }

  @override
  Future<bool> setBrightness(double value, {bool smooth = false}) async {
    try {
      await ScreenBrightnessPro.setBrightness(value, smooth: smooth);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> get canControlNativeBrightness async {
    // Fork handles Windows VM probe internally; return true where supported.
    try {
      // ScreenBrightnessPro throws on unsupported (VM without DDC/CI) — treat as false.
      await ScreenBrightnessPro.getBrightness();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> get canChangeSystemBrightness async => canControlNativeBrightness;

  @override
  Future<double> getBrightness() async {
    try {
      return await ScreenBrightnessPro.getBrightness();
    } catch (_) {
      return 1.0;
    }
  }

  @override
  Future<bool> resetBrightness() async {
    try {
      await ScreenBrightnessPro.resetBrightness();
      return true;
    } catch (_) {
      return false;
    }
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
  Future<void> optimizeForLowBattery({double threshold = 0.2, double targetBrightness = 0.45}) async {
    try {
      await ScreenBrightnessPro.optimizeForLowBattery();
    } catch (_) {}
  }

  @override
  Future<bool> isCharging() async {
    try {
      return _isOnPower(await _battery.batteryState);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onChargingChanged {
    return _battery.onBatteryStateChanged
        .map(_isOnPower)
        .handleError((Object _, StackTrace _) {});
  }
}
