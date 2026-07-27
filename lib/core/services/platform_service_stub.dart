import 'package:atlas_app/core/services/platform_service.dart';

class StubPlatformService implements PlatformService {
  @override
  Future<void> setBrightness(double value, {bool smooth = false}) async {}

  @override
  Future<double> getBrightness() async => 1.0;

  @override
  Future<void> resetBrightness() async {}

  @override
  Future<void> setKeepScreenOn(bool value) async {}

  @override
  Future<double> getBatteryLevel() async => 1.0;

  @override
  Future<bool> isLowPowerModeEnabled() async => false;

  @override
  Future<void> optimizeForLowBattery() async {}
}
