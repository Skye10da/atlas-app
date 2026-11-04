import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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
  String? _selectedVoiceId;

  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _stateController = StreamController<DriverState>.broadcast();

  /// Upper bound on a single utterance. flutter_tts's Android side re-queues
  /// `speak` whenever the OS TextToSpeech connection is dead ("not bound to
  /// TTS engine") and only resolves the future after a successful re-init —
  /// so when the engine keeps failing, `await speak()` hangs forever and no
  /// DriverError is ever emitted. The timeout converts that silent hang into
  /// a DriverError so SpeechEngine's retry/restart recovery can run.
  static const _speakTimeout = Duration(seconds: 60);

  @override
  Stream<SpeechDriverEvent> get events => _events.stream;

  @override
  DriverState get state => _state;

  @override
  Stream<DriverState> get stateStream => _stateController.stream;

  void _wireCallbacks() {
    try {
      _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    try {
      _tts.setStartHandler(() {
        _setState(DriverState.speaking);
        _addEvent(const DriverStarted());
      });
    } catch (_) {}
    try {
      _tts.setPauseHandler(() {
        _setState(DriverState.paused);
        _addEvent(const DriverPaused());
      });
    } catch (_) {}
    try {
      _tts.setContinueHandler(() {
        _setState(DriverState.speaking);
        _addEvent(const DriverResumed());
      });
    } catch (_) {}
    try {
      _tts.setCompletionHandler(() {
        _setState(DriverState.ready);
        _addEvent(const DriverCompleted());
      });
    } catch (_) {}
    try {
      _tts.setCancelHandler(() {
        _setState(DriverState.stopped);
      });
    } catch (_) {}
    try {
      _tts.setErrorHandler((dynamic msg) {
        _setState(DriverState.error);
        _addEvent(DriverError(msg?.toString() ?? 'Unknown TTS error'));
      });
    } catch (_) {}
    try {
      _tts.setProgressHandler((String text, int start, int end, String word) {
        _addEvent(DriverWordBoundary(start, end, word));
      });
    } catch (_) {}
  }

  void _setState(DriverState s) {
    _state = s;
    if (_stateController.isClosed) return;
    _stateController.add(s);
  }

  void _addEvent(SpeechDriverEvent e) {
    if (_events.isClosed) return;
    _events.add(e);
  }

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
    String? language,
  }) async {
    _selectedVoiceId = voiceId;
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
    try {
      await _tts.setPitch(pitch);
    } catch (_) {}
    try {
      await _tts.setVolume(volume);
    } catch (_) {}
    if (language != null) {
      // flutter_tts setLanguage caches its Future (flutter_tts.dart:385);
      // a changed language still applies on Android/iOS, and re-calling it is
      // safe. Errors (e.g. unsupported locale) must not break the speak call.
      try {
        await _tts.setLanguage(language);
      } catch (_) {}
    }
    if (voiceId != null) {
      // flutter_tts identifies voices by a {name, locale} map, not a bare
      // id — callers should pass voiceId as 'name@locale' and this driver
      // splits it, OR (simpler for now) callers pass the full map via a
      // future overload. Left explicit rather than silently no-op'ing so
      // this gap is visible once real voice-selection UI is wired up.
      final parts = voiceId.split('@');
      if (parts.length == 2) {
        try {
          await _tts.setVoice({'name': parts[0], 'locale': parts[1]});
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> warmup(SpeechItem item) async {
    if (!kIsWeb && Platform.isWindows && _selectedVoiceId != null) return;
    try {
      if (item.language.isNotEmpty) {
        await _tts.setLanguage(item.language);
      }
    } catch (_) {}
  }

  @override
  Future<List<int>?> synthesizeToBytes(SpeechItem item) async {
    // flutter_tts synthesizeToFile is platform-specific and file-based;
    // we expose a no-op here so the cache layer can gracefully degrade to
    // warmup-only gapless. A real file export can be wired via
    // `synthesizeToFile` when the platform supports it.
    return null;
  }

  static final _multiEllipsisRegex = RegExp(r'[…]+|\.{3,}');

  String _cleanTtsText(String text) {
    if (!text.contains('…') && !text.contains('...')) return text;
    return text.replaceAll(_multiEllipsisRegex, ', ');
  }

  @override
  Future<void> speak(SpeechItem item) async {
    // Windows SAPI: per-item setLanguage overrides the selected voice and can select a non-existent
    // locale (e.g. book language 'zh' while selected voice is 'en-US' David), resulting in silent 0 return.
    // Keep the user's selected voice on Windows; only setLanguage when no voice is selected or on mobile.
    final shouldSetLanguage = !(!kIsWeb && Platform.isWindows && _selectedVoiceId != null);
    if (shouldSetLanguage && item.language.isNotEmpty) {
      try {
        await _tts.setLanguage(item.language);
      } catch (_) {
        try {
          await _tts.setLanguage('en-US');
        } catch (_) {}
      }
    } else if (shouldSetLanguage) {
      try {
        await _tts.setLanguage('en-US');
      } catch (_) {}
    }
    try {
      final cleanText = _cleanTtsText(item.text);
      final result =
          await _tts.speak(cleanText).timeout(_speakTimeout, onTimeout: () => 0);
      // flutter_tts returns 1 on success, 0/null on failure (common on Windows
      // SAPI with empty voice, or an unbound Android TTS connection).
      if (result == 0 || result == null) {
        _addEvent(DriverError('TTS speak returned $result for ${item.language} voice=$_selectedVoiceId'));
      }
    } catch (e) {
      _addEvent(DriverError(e.toString()));
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (_) {}
  }

  @override
  Future<void> resume(SpeechItem item) async {
    try {
      final cleanText = _cleanTtsText(item.text);
      await _tts.speak(cleanText).timeout(_speakTimeout, onTimeout: () => 0);
    } catch (e) {
      _addEvent(DriverError(e.toString()));
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _setState(DriverState.stopped);
  }

  @override
  Future<List<VoiceDescriptor>> listVoices() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (v) => VoiceDescriptor(
            id: '${v['name']}@${v['locale']}',
            language: (v['locale'] as String?)?.split('-').first ?? 'en',
            locale: v['locale'] as String? ?? 'en-US',
            gender: v['gender'] as String?,
            quality: v['quality']?.toString(),
          ),
        )
        .toList();
  }

  @override
  Future<void> restart() async {
    try {
      await _tts.stop();
    } catch (_) {}
    // On Android, re-instantiating the Dart wrapper does NOT rebind the
    // native engine — the plugin owns a single TextToSpeech per FlutterEngine
    // and `_tts = FlutterTts()` only swaps the callback wiring. When the OS
    // connection is dead ("not bound to TTS engine"), force a fresh bind via
    // setEngine(getDefaultEngine): the plugin sets ttsStatus back to null and
    // constructs a new TextToSpeech, completing the future on init success
    // or failure. Falls back to the plain re-wrap if that path fails.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final engine = await _tts.getDefaultEngine;
        if (engine is String && engine.isNotEmpty) {
          await _tts
              .setEngine(engine)
              .timeout(const Duration(seconds: 15), onTimeout: () => null);
        }
      } catch (_) {}
    }
    _tts = FlutterTts();
    _wireCallbacks();
    _setState(DriverState.ready);
  }

  @override
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (!_events.isClosed) await _events.close();
    if (!_stateController.isClosed) await _stateController.close();
  }
}
