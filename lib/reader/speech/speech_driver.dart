import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Thin interface a TTS backend implements — in the same sense as a
/// database driver. Atlas's Speech Engine depends only on this interface,
/// never on flutter_tts (or any future backend) directly. See ASA §4 and
/// §13 for the deliberately narrow scope: this is the entire abstraction,
/// not a registry or plugin-discovery system.
abstract class SpeechDriver {
  /// Low-level events for the current utterance. SpeechEngine is the only
  /// consumer of this stream — it translates these into SpeechEvents.
  Stream<SpeechDriverEvent> get events;

  DriverState get state;
  Stream<DriverState> get stateStream;

  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
  });

  /// Speak a single SpeechItem. Drivers should treat each call as a fresh
  /// utterance — SpeechEngine owns chunking/sequencing, not the driver.
  Future<void> speak(SpeechItem item);

  Future<void> pause();

  /// Resume speaking [item] from wherever the driver left off. For drivers
  /// without native pause support, this may mean re-speaking from the
  /// start of [item] — acceptable imprecision is bounded to one sentence
  /// by design (ASA §4).
  Future<void> resume(SpeechItem item);

  Future<void> stop();

  Future<List<VoiceDescriptor>> listVoices();

  /// Re-initializes the underlying engine. Used by SpeechEngine's error
  /// recovery path (ASA §12) when a retry of the current item fails.
  Future<void> restart();

  Future<void> dispose();
}
