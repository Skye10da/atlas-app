import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// SpeechDriver implementation backed by flutter_tts. This is the only
/// file in the Speech subsystem that imports flutter_tts directly — every
/// other file talks to SpeechDriver, never this class.
class FlutterTtsDriver implements SpeechDriver {
  FlutterTtsDriver([FlutterTts? tts]) : _tts = tts ?? FlutterTts() {
    _wireCallbacks();
  }

  FlutterTts _tts;
  DriverState _state = DriverState.stopped;

  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _stateController = StreamController<DriverState>.broadcast();

  @override
  Stream<SpeechDriverEvent> get events => _events.stream;

  @override
  DriverState get state => _state;

  @override
  Stream<DriverState> get stateStream => _stateController.stream;

  void _wireCallbacks() {
    _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      _setState(DriverState.speaking);
      _events.add(const DriverStarted());
    });

    _tts.setPauseHandler(() {
      _setState(DriverState.paused);
      _events.add(const DriverPaused());
    });

    _tts.setContinueHandler(() {
      _setState(DriverState.speaking);
      _events.add(const DriverResumed());
    });

    _tts.setCompletionHandler(() {
      _setState(DriverState.ready);
      _events.add(const DriverCompleted());
    });

    _tts.setCancelHandler(() {
      _setState(DriverState.stopped);
    });

    _tts.setErrorHandler((dynamic msg) {
      _setState(DriverState.error);
      _events.add(DriverError(msg?.toString() ?? 'Unknown TTS error'));
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      _events.add(DriverWordBoundary(start, end, word));
    });
  }

  void _setState(DriverState s) {
    _state = s;
    _stateController.add(s);
  }

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
  }) async {
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    if (voiceId != null) {
      // flutter_tts identifies voices by a {name, locale} map, not a bare
      // id — callers should pass voiceId as 'name@locale' and this driver
      // splits it, OR (simpler for now) callers pass the full map via a
      // future overload. Left explicit rather than silently no-op'ing so
      // this gap is visible once real voice-selection UI is wired up.
      final parts = voiceId.split('@');
      if (parts.length == 2) {
        await _tts.setVoice({'name': parts[0], 'locale': parts[1]});
      }
    }
  }

  @override
  Future<void> speak(SpeechItem item) async {
    await _tts.speak(item.text);
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> resume(SpeechItem item) async {
    // flutter_tts has no native "resume from offset" — Android's pause is
    // itself a workaround (re-speak from a tracked onRangeStart offset).
    // Since SpeechItems are sentence-sized (ASA §4), re-speaking the whole
    // item on resume is an acceptable, bounded imprecision.
    await _tts.speak(item.text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _setState(DriverState.stopped);
  }

  @override
  Future<List<VoiceDescriptor>> listVoices() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((v) => VoiceDescriptor(
              id: '${v['name']}@${v['locale']}',
              language: (v['locale'] as String?)?.split('-').first ?? 'en',
              locale: v['locale'] as String? ?? 'en-US',
              gender: v['gender'] as String?,
              quality: v['quality']?.toString(),
            ))
        .toList();
  }

  @override
  Future<void> restart() async {
    await _tts.stop();
    _tts = FlutterTts();
    _wireCallbacks();
    _setState(DriverState.ready);
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
    await _events.close();
    await _stateController.close();
  }
}
