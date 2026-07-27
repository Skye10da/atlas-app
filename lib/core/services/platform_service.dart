abstract class PlatformService {
  // Brightness
  Future<void> setBrightness(double value, {bool smooth});
  Future<double> getBrightness();
  Future<void> resetBrightness();

  // Wake lock
  Future<void> setKeepScreenOn(bool value);

  // Battery awareness
  Future<double> getBatteryLevel();
  Future<bool> isLowPowerModeEnabled();
  Future<void> optimizeForLowBattery();
}
