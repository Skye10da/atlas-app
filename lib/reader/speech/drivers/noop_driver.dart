import 'dart:async';

import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// No-op driver for Windows debug — avoids SAPI crash (Lost connection
/// after loadSession). Holds session in memory but produces no audio.
/// Pronoun/custom-voice disabled per revert; this is stable flutter_tts fallback.
class NoopDriver implements SpeechDriver {
  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _stateController = StreamController<DriverState>.broadcast();
  DriverState _state = DriverState.stopped;

  @override
  Stream<SpeechDriverEvent> get events => _events.stream;
  @override
  DriverState get state => _state;
  @override
  Stream<DriverState> get stateStream => _stateController.stream;
  @override
  String get displayName => 'Noop';

  @override
  Future<void> configure({required double rate, required double pitch, required double volume, String? voiceId, String? language}) async {}

  @override
  Future<void> speak(SpeechItem item) async {
    // Simulate immediate completion to avoid gapless loop, but don't emit
    // DriverCompleted so engine doesn't fast-loop title-to-title on Windows.
    // Keep silent — engine will stay in isPlaying until stop().
  }

  @override
  Future<void> warmup(SpeechItem item) async {}
  @override
  Future<List<int>?> synthesizeToBytes(SpeechItem item) async => null;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume(SpeechItem item) async {}
  @override
  Future<void> stop() async {
    _state = DriverState.stopped;
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  @override
  Future<List<VoiceDescriptor>> listVoices() async => const [];
  @override
  Future<void> restart() async {}
  @override
  Future<void> dispose() async {
    if (!_events.isClosed) await _events.close();
    if (!_stateController.isClosed) await _stateController.close();
  }
}
