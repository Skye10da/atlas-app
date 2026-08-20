import 'dart:async';

import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// The driver-agnostic core of the Speech subsystem. Owns the current
/// SpeechSession (queue + checkpoint + settings), translates low-level
/// SpeechDriverEvents into the SpeechEvent stream the Reader listens to,
/// and implements the debounced recovery checkpoint and error-recovery
/// policies from ASA §10 and §12.
///
/// Deliberately knows nothing about audio_service — that's
/// PlaybackController's job — and nothing about chapters beyond the
/// current one, per the Reader/Speech ownership split in ASA §7: this
/// class emits ChapterFinished and stops; it never loads a new chapter
/// itself.
class SpeechEngine {
  SpeechEngine(this._driver, this._recoveryStore) {
    _lastCheckpointFlush = DateTime.now();
    _driver.events.listen(_onDriverEvent);
  }

  final SpeechDriver _driver;
  final RecoveryStore _recoveryStore;

  SpeechSession? _session;
  SleepTimerBoundary? _stopAtBoundary;
  Timer? _sleepTimer;

  int _checkpointBufferCount = 0;
  late DateTime _lastCheckpointFlush;
  static const _checkpointFlushEvery = 5; // sentences
  static const _checkpointFlushInterval = Duration(seconds: 10);

  bool _retriedCurrentItem = false;
  bool _restartedForCurrentItem = false;

  final _eventsController = StreamController<SpeechEvent>.broadcast();
  Stream<SpeechEvent> get events => _eventsController.stream;

  SpeechSession? get session => _session;

  /// Loads a new session (e.g. a chapter's SpeechQueue) and applies its
  /// settings to the driver. Does not start playback — call [start]
  /// separately, mirroring the Reader's explicit control over when
  /// narration actually begins (ASA §8).
  Future<void> loadSession(SpeechSession session) async {
    _session = session;
    _retriedCurrentItem = false;
    _restartedForCurrentItem = false;
    setSleepTimer(session.settings.sleepTimer);
    await _driver.configure(
      rate: session.settings.speechRate,
      pitch: session.settings.speechPitch,
      volume: 1.0,
      voiceId: session.settings.selectedVoiceId,
    );
  }

  /// Live-apply a settings change (rate/pitch/voice/sleep timer) without
  /// rebuilding the session. Persisting the settings themselves is the
  /// caller's responsibility.
  Future<void> updateSettings(NarrationSettings settings) async {
    final session = _session;
    if (session != null) {
      session.settings = settings;
    }
    await _driver.configure(
      rate: settings.speechRate,
      pitch: settings.speechPitch,
      volume: 1.0,
      voiceId: settings.selectedVoiceId,
    );
  }

  Future<void> start() async {
    final item = _session?.currentItem;
    if (item == null) return;
    _eventsController.add(SentenceStarted(item));
    await _driver.speak(item);
  }

  Future<void> pause() => _driver.pause();

  Future<void> resume() async {
    final item = _session?.currentItem;
    if (item == null) return;
    await _driver.resume(item);
  }

  Future<void> stop() async {
    await _driver.stop();
    _eventsController.add(const SpeechStopped());
  }

  /// Skips to the next sentence in the queue, stopping the current one.
  /// No-op at end of queue (the Reader handles ChapterFinished/next chapter).
  Future<void> skipNext() async {
    final session = _session;
    if (session == null) return;
    final next = session.queue.next();
    if (next == null) return;
    await _driver.stop();
    _eventsController.add(SentenceStarted(next));
    await _driver.speak(next);
  }

  /// Skips back to the previous sentence in the queue, stopping the current
  /// one. No-op at the start of the queue.
  Future<void> skipPrevious() async {
    final session = _session;
    if (session == null) return;
    final prev = session.queue.previous();
    if (prev == null) return;
    await _driver.stop();
    _eventsController.add(SentenceStarted(prev));
    await _driver.speak(prev);
  }

  void setSleepTimer(SleepTimerConfig? config) {
    _sleepTimer?.cancel();
    _stopAtBoundary = null;
    if (config == null) return;
    _sleepTimer = Timer(config.duration, () {
      if (config.boundary == SleepTimerBoundary.immediate) {
        stop();
      } else {
        _stopAtBoundary = config.boundary;
      }
    });
  }

  void _onDriverEvent(SpeechDriverEvent event) {
    switch (event) {
      case DriverStarted():
        break; // SentenceStarted already emitted in start()/advance
      case DriverPaused():
        _eventsController.add(const SpeechPaused());
      case DriverResumed():
        break;
      case DriverCompleted():
        unawaited(_onItemComplete());
      case DriverError(:final message):
        unawaited(_onDriverError(message));
      case DriverWordBoundary(:final start, :final end, :final word):
        final item = _session?.currentItem;
        if (item != null) {
          _eventsController.add(WordBoundary(item, start, end, word));
        }
    }
  }

  Future<void> _onItemComplete() async {
    final session = _session;
    if (session == null) return;
    final finishedItem = session.currentItem;
    if (finishedItem == null) return;

    _retriedCurrentItem = false;
    _restartedForCurrentItem = false;
    _eventsController.add(SentenceFinished(finishedItem));
    await _checkpoint(session);

    final isParagraphEnd = session.queue.isLastInParagraph(finishedItem);
    if (isParagraphEnd) {
      _eventsController.add(ParagraphFinished(finishedItem));
      if (_stopAtBoundary == SleepTimerBoundary.endOfParagraph ||
          _stopAtBoundary == SleepTimerBoundary.endOfSentence) {
        await stop();
        return;
      }
    } else if (_stopAtBoundary == SleepTimerBoundary.endOfSentence) {
      await stop();
      return;
    }

    final next = session.queue.next();
    if (next != null) {
      _eventsController.add(SentenceStarted(next));
      await _driver.speak(next);
    } else {
      if (_stopAtBoundary == SleepTimerBoundary.endOfChapter) {
        await stop();
      }
      // Deliberately does not load the next chapter — see ASA §7.
      _eventsController.add(ChapterFinished(session.chapterId));
    }
  }

  /// Error Recovery per ASA §12: retry the current item once, then
  /// restart the driver and retry once more from the same item, then give
  /// up and surface SpeechError while leaving the last checkpoint intact.
  Future<void> _onDriverError(String message) async {
    final session = _session;
    final item = session?.currentItem;

    if (item == null) {
      _eventsController.add(SpeechError(message));
      return;
    }

    if (!_retriedCurrentItem) {
      _retriedCurrentItem = true;
      await _driver.speak(item);
      return;
    }

    if (_restartedForCurrentItem) {
      // Already restarted and retried once after the restart - give up.
      _eventsController.add(SpeechError(message, item: item));
      await stop();
      return;
    }

    _restartedForCurrentItem = true;
    try {
      await _driver.restart();
      await _driver.configure(
        rate: session!.settings.speechRate,
        pitch: session.settings.speechPitch,
        volume: 1.0,
        voiceId: session.settings.selectedVoiceId,
      );
      await _driver.speak(item);
    } catch (_) {
      _eventsController.add(SpeechError(message, item: item));
      await stop();
    }
  }

  Future<void> _checkpoint(SpeechSession session) async {
    _checkpointBufferCount++;
    final now = DateTime.now();
    final dueByCount = _checkpointBufferCount >= _checkpointFlushEvery;
    final dueByTime =
        now.difference(_lastCheckpointFlush) >= _checkpointFlushInterval;
    if (!dueByCount && !dueByTime) return;

    _checkpointBufferCount = 0;
    _lastCheckpointFlush = now;
    await _recoveryStore.save(session.toCheckpoint());
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    await _eventsController.close();
  }
}
