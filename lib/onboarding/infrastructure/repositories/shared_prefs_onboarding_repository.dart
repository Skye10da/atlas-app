import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/onboarding/domain/repository_interfaces/onboarding_repository_interface.dart';

final class SharedPrefsOnboardingRepository
    implements OnboardingRepositoryInterface {
  const SharedPrefsOnboardingRepository();

  static const _key = 'onboarding_completed_version';

  @override
  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_key) ?? 0) >= kOnboardingVersion;
  }

  @override
  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, kOnboardingVersion);
  }

  @override
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
