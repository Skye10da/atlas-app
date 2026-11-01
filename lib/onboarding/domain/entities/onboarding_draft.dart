/// The choices made during onboarding. Nothing is persisted until the flow
/// finishes, so backing out or skipping never leaves half-applied state
/// (theme changes are the exception: they apply live as a preview).
class OnboardingDraft {
  const OnboardingDraft({
    this.displayName = '',
    this.avatarColorIndex = 0,
    this.weeklyChapterTarget,
    this.dailyMinuteTarget,
    this.enableUpdateNotifications = false,
  });

  /// Empty means "keep the default 'Reader'".
  final String displayName;

  /// Index into `kAvatarColors`.
  final int avatarColorIndex;

  /// Null = the user never touched it, so the stored goal is left alone.
  final int? weeklyChapterTarget;
  final int? dailyMinuteTarget;

  final bool enableUpdateNotifications;

  OnboardingDraft copyWith({
    String? displayName,
    int? avatarColorIndex,
    int? weeklyChapterTarget,
    int? dailyMinuteTarget,
    bool? enableUpdateNotifications,
  }) {
    return OnboardingDraft(
      displayName: displayName ?? this.displayName,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      weeklyChapterTarget: weeklyChapterTarget ?? this.weeklyChapterTarget,
      dailyMinuteTarget: dailyMinuteTarget ?? this.dailyMinuteTarget,
      enableUpdateNotifications:
          enableUpdateNotifications ?? this.enableUpdateNotifications,
    );
  }

  /// First name for greetings; falls back to "Reader".
  String get greetingName {
    final first = displayName.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Reader' : first;
  }

  String get avatarInitial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? 'R' : trimmed.substring(0, 1).toUpperCase();
  }
}
