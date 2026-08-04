/// Core data models for the Atlas Speech subsystem. Driver-agnostic —
/// nothing here references flutter_tts, audio_service, or any Atlas
/// reader/database type.
library;

class SpeechItem {
  const SpeechItem({
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.sentenceIndex,
    required this.text,
    required this.language,
    this.voiceId,
    this.estimatedDuration,
  });

  final String bookId;
  final String chapterId;
  final int paragraphIndex;
  final int sentenceIndex;
  final String text;

  /// BCP-47 language tag, e.g. 'en-US'. Per-item rather than per-session so
  /// a chapter can mix languages (relevant for translated-novel content
  /// where source-language terms/names may warrant a different voice).
  final String language;

  final String? voiceId;
  final Duration? estimatedDuration;

  /// Stable identity for logging/debugging and for seeking a SpeechQueue
  /// back to a specific item (e.g. "jump to this paragraph").
  String get id => '${chapterId}_p${paragraphIndex}_s$sentenceIndex';

  @override
  String toString() => 'SpeechItem($id, "${_truncate(text, 40)}")';

  static String _truncate(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';
}

class VoiceDescriptor {
  const VoiceDescriptor({
    required this.id,
    required this.language,
    required this.locale,
    this.gender,
    this.quality,
  });

  factory VoiceDescriptor.fromJson(Map<String, dynamic> json) =>
      VoiceDescriptor(
        id: json['id'] as String,
        language: json['language'] as String? ?? 'en',
        locale: json['locale'] as String? ?? 'en-US',
        gender: json['gender'] as String?,
        quality: json['quality'] as String?,
      );

  final String id;
  final String language; // e.g. 'en'
  final String locale; // e.g. 'en-AU'
  final String? gender; // platform-reported where available
  final String? quality; // platform-reported where available

  Map<String, dynamic> toJson() => {
        'id': id,
        'language': language,
        'locale': locale,
        if (gender != null) 'gender': gender,
        if (quality != null) 'quality': quality,
      };

  @override
  String toString() => 'VoiceDescriptor($id, $locale)';
}

enum DriverState { ready, speaking, paused, stopped, error }
