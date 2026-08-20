import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

const _defaultSettings = NarrationSettings();

/// Picks a driver voice whose locale matches [code] (a 2-letter language code
/// like 'en' or a full BCP-47 tag like 'fr-FR'). Returns null when no exact
/// match exists, in which case the caller falls back to the driver default.
///
/// Voices come from [speechVoicesProvider] (persisted via VoiceCache), so
/// this is cheap to call repeatedly. `zh` prefers a mainland/TW regional
/// voice when both are installed.
Future<String?> resolveVoiceIdForLanguage(WidgetRef ref, String code) async {
  final normalized = code.toLowerCase();
  final voices = await ref
      .read(speechVoicesProvider.future)
      .catchError((_) => const <VoiceDescriptor>[]);
  if (voices.isEmpty) return null;

  VoiceDescriptor? exact;
  VoiceDescriptor? broad;
  VoiceDescriptor? regionalZh;
  for (final v in voices) {
    if (v.language.toLowerCase() == normalized) {
      exact ??= v;
      if (normalized == 'zh' &&
          (v.locale.startsWith('zh-CN') || v.locale.startsWith('zh-TW'))) {
        regionalZh ??= v;
      }
    } else if (v.locale.toLowerCase().startsWith('$normalized-')) {
      broad ??= v;
    }
  }
  if (normalized == 'zh' && regionalZh != null) return regionalZh.id;
  if (exact != null) return exact.id;
  if (broad != null) return broad.id;
  return null;
}

/// Speaks an arbitrary selected snippet one time, independent of the
/// narration [SpeechEngine] session. Used by the context-menu "Listen" action
/// in both the novel and PDF readers.
///
/// This deliberately does NOT touch `speechEngineProvider`'s session — the
/// narration queue (and its recovery checkpoints) only tracks full-chapter
/// narration, so a one-off selection read must not displace it.
class SelectionSpeaker {
  const SelectionSpeaker();

  Future<void> speak({
    required WidgetRef ref,
    required String bookId,
    required String chapterId,
    required String text,
    required String language,
    int paragraphIndex = 0,
    int sentenceIndex = 0,
    String? voiceId,
  }) async {
    if (text.trim().isEmpty) return;
    final settings =
        ref.read(narrationSettingsProvider).value ?? _defaultSettings;

    final driver = ref.read(speechDriverProvider);
    try {
      await driver.configure(
        rate: settings.speechRate,
        pitch: settings.speechPitch,
        volume: 1.0,
        voiceId: voiceId ?? settings.selectedVoiceId,
        language: language,
      );
      await driver.speak(
        SpeechItem(
          bookId: bookId,
          chapterId: chapterId,
          paragraphIndex: paragraphIndex,
          sentenceIndex: sentenceIndex,
          text: text,
          language: language,
          voiceId: voiceId ?? settings.selectedVoiceId,
        ),
      );
    } catch (_) {}
  }

  Future<void> stop(WidgetRef ref) => ref.read(speechDriverProvider).stop();
}
