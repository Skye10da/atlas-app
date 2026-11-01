/// The pages of the welcome flow, in order.
enum OnboardingStep {
  // Introduction slides.
  welcome,
  read,
  discover,
  companion,
  // Setup steps (each one optional).
  profile,
  appearance,
  preferences,
  // Wrap-up.
  ready;

  bool get isIntro => index <= OnboardingStep.companion.index;

  bool get isSetup => !isIntro && this != OnboardingStep.ready;

  static const int count = 8;
}

/// Where the user lands once onboarding finishes.
enum OnboardingDestination { library, sources, importBook }
