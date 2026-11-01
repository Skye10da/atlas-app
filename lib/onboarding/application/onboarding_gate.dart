import 'package:atlas_app/onboarding/domain/repository_interfaces/onboarding_repository_interface.dart';

/// Decides whether the welcome flow should run on this launch.
///
/// Existing installs that update into a build with onboarding already have a
/// library; showing them a "welcome" would be noise, so they are marked as
/// done silently. A brand-new install has no books yet.
class OnboardingGate {
  const OnboardingGate({
    required OnboardingRepositoryInterface repository,
    required Future<bool> Function() hasLibraryContent,
  }) : _repository = repository,
       _hasLibraryContent = hasLibraryContent;

  final OnboardingRepositoryInterface _repository;
  final Future<bool> Function() _hasLibraryContent;

  Future<bool> shouldShow() async {
    if (await _repository.isCompleted()) return false;
    if (await _hasLibraryContent()) {
      await _repository.markCompleted();
      return false;
    }
    return true;
  }
}
