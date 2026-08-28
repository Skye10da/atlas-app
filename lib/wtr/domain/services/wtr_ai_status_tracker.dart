import 'package:flutter/foundation.dart';

import 'package:atlas_app/wtr/domain/services/wtr_ai_translate_service.dart';

/// What the AI+ path actually did for one novel's most recent fetch.
class WtrAiChapterOutcome {
  const WtrAiChapterOutcome.aiPlus() : fellBack = false, reason = null;

  const WtrAiChapterOutcome.fallback(this.reason) : fellBack = true;

  /// True when the chapter was translated by the user's AI provider; false
  /// when Atlas degraded to on-device Google translation.
  final bool fellBack;

  /// Why AI+ was skipped, when [fellBack] is true.
  final WtrAiFailureReason? reason;
}

/// Process-wide record of what the AI+ path last did per novel.
///
/// The content engine runs far below the widget layer, so the template
/// reports outcomes here and the translation selector listens — the same
/// pattern `SessionRefreshService` uses for session walls. In-memory only:
/// it describes the *current* reading session, nothing persistent.
class WtrAiStatusTracker {
  WtrAiStatusTracker._();

  static final WtrAiStatusTracker instance = WtrAiStatusTracker._();

  final ValueNotifier<Map<int, WtrAiChapterOutcome>> _outcomes = ValueNotifier(
    const <int, WtrAiChapterOutcome>{},
  );

  ValueListenable<Map<int, WtrAiChapterOutcome>> get outcomes => _outcomes;

  /// The latest outcome for [rawId], if any was reported this session.
  WtrAiChapterOutcome? outcomeFor(int rawId) => _outcomes.value[rawId];

  void reportSuccess(int rawId) => _outcomes.value = {
    ..._outcomes.value,
    rawId: const WtrAiChapterOutcome.aiPlus(),
  };

  void reportFallback(int rawId, WtrAiFailureReason reason) => _outcomes.value =
      {..._outcomes.value, rawId: WtrAiChapterOutcome.fallback(reason)};

  /// Forgets [rawId] (e.g. the user switched away from AI+).
  void clear(int rawId) {
    if (!_outcomes.value.containsKey(rawId)) return;
    _outcomes.value = {..._outcomes.value}..remove(rawId);
  }

  /// Test hook: wipes all recorded outcomes.
  void reset() => _outcomes.value = const {};
}
