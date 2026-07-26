import 'package:atlas_app/core/services/platform_service.dart';

class StubPlatformService implements PlatformService {
  @override
  void setBrightness(double value) {}

  @override
  void resetBrightness() {}

  @override
  void enableWakeLock() {}

  @override
  void disableWakeLock() {}
}
