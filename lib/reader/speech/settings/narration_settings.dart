/// Narration-specific settings, kept separate from ReadingSettingsEntity
/// (visual reading preferences) since these govern the Speech subsystem
/// specifically.
class NarrationSettings {
  const NarrationSettings({
    this.speechRate = 1.0,
    this.speechPitch = 1.0,
    this.selectedVoiceId,
    this.sleepTimer,
    this.syncScrollToNarration = false,
    this.autoAdvanceChapter = true,
    this.activeProfile,
  });

  factory NarrationSettings.fromJson(Map<String, dynamic> json) =>
      NarrationSettings(
        speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1.0,
        speechPitch: (json['speechPitch'] as num?)?.toDouble() ?? 1.0,
        selectedVoiceId: json['selectedVoiceId'] as String?,
        sleepTimer: json['sleepTimer'] is Map<String, dynamic>
            ? SleepTimerConfig.fromJson(
                Map<String, dynamic>.from(json['sleepTimer'] as Map))
            : null,
        syncScrollToNarration: json['syncScrollToNarration'] as bool? ?? false,
        autoAdvanceChapter: json['autoAdvanceChapter'] as bool? ?? true,
        activeProfile: json['activeProfile'] as String?,
      );

  final double speechRate;
  final double speechPitch;
  final String? selectedVoiceId;
  final SleepTimerConfig? sleepTimer;
  final bool syncScrollToNarration;
  final bool autoAdvanceChapter;

  /// Name of the active NarrationProfile, or null if the values above have
  /// been manually adjusted since a profile was last applied (i.e. "Custom").
  final String? activeProfile;

  NarrationSettings copyWith({
    double? speechRate,
    double? speechPitch,
    String? selectedVoiceId,
    SleepTimerConfig? sleepTimer,
    bool? syncScrollToNarration,
    bool? autoAdvanceChapter,
    String? activeProfile,
    bool clearActiveProfile = false,
    bool clearSleepTimer = false,
  }) {
    return NarrationSettings(
      speechRate: speechRate ?? this.speechRate,
      speechPitch: speechPitch ?? this.speechPitch,
      selectedVoiceId: selectedVoiceId ?? this.selectedVoiceId,
      sleepTimer: clearSleepTimer ? null : (sleepTimer ?? this.sleepTimer),
      syncScrollToNarration: syncScrollToNarration ?? this.syncScrollToNarration,
      autoAdvanceChapter: autoAdvanceChapter ?? this.autoAdvanceChapter,
      activeProfile: clearActiveProfile ? null : (activeProfile ?? this.activeProfile),
    );
  }

  Map<String, dynamic> toJson() => {
        'speechRate': speechRate,
        'speechPitch': speechPitch,
        if (selectedVoiceId != null) 'selectedVoiceId': selectedVoiceId,
        if (sleepTimer != null) 'sleepTimer': sleepTimer!.toJson(),
        'syncScrollToNarration': syncScrollToNarration,
        'autoAdvanceChapter': autoAdvanceChapter,
        if (activeProfile != null) 'activeProfile': activeProfile,
      };
}

enum SleepTimerBoundary { immediate, endOfSentence, endOfParagraph, endOfChapter }

class SleepTimerConfig {
  const SleepTimerConfig({required this.duration, required this.boundary});

  factory SleepTimerConfig.fromJson(Map<String, dynamic> json) =>
      SleepTimerConfig(
        duration: Duration(milliseconds: json['durationMs'] as int),
        boundary: SleepTimerBoundary.values.byName(json['boundary'] as String),
      );

  final Duration duration;
  final SleepTimerBoundary boundary;

  Map<String, dynamic> toJson() => {
        'durationMs': duration.inMilliseconds,
        'boundary': boundary.name,
      };
}

/// A named preset of (speechRate, speechPitch, selectedVoiceId). Applying
/// one just writes those three fields onto NarrationSettings and sets
/// activeProfile — no new architecture, per ASA §9.
class NarrationProfile {
  const NarrationProfile({
    required this.name,
    required this.speechRate,
    required this.speechPitch,
    this.voiceId,
  });

  final String name;
  final double speechRate;
  final double speechPitch;
  final String? voiceId;

  static const natural = NarrationProfile(name: 'Natural', speechRate: 1.0, speechPitch: 1.0);
  static const fastReading = NarrationProfile(name: 'Fast Reading', speechRate: 1.35, speechPitch: 1.0);
  static const slowReading = NarrationProfile(name: 'Slow Reading', speechRate: 0.8, speechPitch: 1.0);
  static const nightMode = NarrationProfile(name: 'Night Mode', speechRate: 0.9, speechPitch: 0.95);

  static const defaults = [natural, fastReading, slowReading, nightMode];

  NarrationSettings applyTo(NarrationSettings settings) => settings.copyWith(
        speechRate: speechRate,
        speechPitch: speechPitch,
        selectedVoiceId: voiceId,
        activeProfile: name,
      );
}
