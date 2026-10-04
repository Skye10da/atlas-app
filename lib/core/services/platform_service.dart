import 'dart:async';

abstract class PlatformService {
  // Brightness — returns true on success, false on failure / unsupported.
  Future<bool> setBrightness(double value, {bool smooth});
  Future<double> getBrightness();
  Future<bool> resetBrightness();

  /// Whether native application brightness can be controlled on this platform.
  /// On web/Linux there is no native API — callers should use overlay fallback.
  Future<bool> get canControlNativeBrightness;

  Future<bool> get canChangeSystemBrightness;

  // Wake lock
  Future<void> setKeepScreenOn(bool value);

  // Battery awareness
  Future<double> getBatteryLevel();
  Future<bool> isLowPowerModeEnabled();
  Future<void> optimizeForLowBattery({double threshold, double targetBrightness});

  // Charging state
  Future<bool> isCharging();
  Stream<bool> get onChargingChanged;
}
