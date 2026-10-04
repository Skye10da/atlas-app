import 'dart:async';

import 'package:atlas_app/core/services/platform_service.dart';

class StubPlatformService implements PlatformService {
  @override
  Future<bool> setBrightness(double value, {bool smooth = false}) async => false;

  @override
  Future<double> getBrightness() async => 1.0;

  @override
  Future<bool> resetBrightness() async => false;

  @override
  Future<bool> get canControlNativeBrightness async => false;

  @override
  Future<bool> get canChangeSystemBrightness async => false;

  @override
  Future<void> setKeepScreenOn(bool value) async {}

  @override
  Future<double> getBatteryLevel() async => 1.0;

  @override
  Future<bool> isLowPowerModeEnabled() async => false;

  @override
  Future<void> optimizeForLowBattery({double threshold = 0.2, double targetBrightness = 0.45}) async {}

  @override
  Future<bool> isCharging() async => false;

  @override
  Stream<bool> get onChargingChanged => const Stream.empty();
}
