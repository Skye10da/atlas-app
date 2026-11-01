/// Bump when the onboarding changes enough that returning users should see it
/// again (a new mandatory step, a re-worked account model, ...).
const int kOnboardingVersion = 1;

/// Persistence for "has this device finished the welcome flow?".
abstract interface class OnboardingRepositoryInterface {
  /// True once the user has completed (or skipped) an onboarding at least as
  /// new as [kOnboardingVersion].
  Future<bool> isCompleted();

  Future<void> markCompleted();

  /// Forgets completion so the flow shows again on next launch.
  Future<void> reset();
}
