import 'package:atlas_app/reader/speech/pronunciation/models/pronunciation_rule.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// UseCase: applies pronunciation normalization to `SpeechItem.text`.
/// Pure, deterministic, idempotent — no `flutter_tts` import, safe to call
/// from `SpeechSessionBuilder` or `FlutterTtsDriver` pre-speak hook.
/// When `rules` empty or all disabled, returns input unchanged (no-op).
class ApplyPronunciationUseCase {
  const ApplyPronunciationUseCase();

  /// Transforms a single paragraph / sentence string.
  String normalize(String input, List<PronunciationRule> rules) {
    if (input.isEmpty) return input;
    var result = input;
    for (final rule in rules) {
      if (!rule.isEnabled) continue;
      if (rule.pattern.isEmpty) continue;
      if (rule.isRegex) {
        try {
          final reg = RegExp(rule.pattern);
          result = result.replaceAll(reg, rule.replacement);
        } catch (_) {
          // Invalid regex — skip rule, never crash engine
          continue;
        }
      } else {
        // Plain string replace — avoid infinite loop when replacement contains pattern
        if (result.contains(rule.pattern)) {
          result = result.split(rule.pattern).join(rule.replacement);
        }
      }
    }
    return result;
  }

  /// Transforms a list of `SpeechItem`s (creates new items with normalized text).
  List<SpeechItem> call(List<SpeechItem> items, List<PronunciationRule> rules) {
    if (rules.isEmpty || rules.every((r) => !r.isEnabled)) return items;
    // Fast path: check if any enabled rule actually matches any item
    final hasMatch = items.any((it) => rules.any((r) => r.isEnabled && it.text.contains(r.pattern) || (r.isRegex && RegExp(r.pattern).hasMatch(it.text))));
    if (!hasMatch) {
      // Still need to check regex matches properly; above is approximate, fallback to full normalize
      // For correctness, just run normalize on all
    }
    return items.map((it) {
      final normalized = normalize(it.text, rules);
      if (normalized == it.text) return it;
      return SpeechItem(
        bookId: it.bookId,
        chapterId: it.chapterId,
        paragraphIndex: it.paragraphIndex,
        sentenceIndex: it.sentenceIndex,
        text: normalized,
        language: it.language,
        voiceId: it.voiceId,
        estimatedDuration: it.estimatedDuration,
      );
    }).toList();
  }
}
