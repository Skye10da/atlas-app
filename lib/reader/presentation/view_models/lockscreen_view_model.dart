import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:atlas_app/reader/domain/entities/lockscreen_media_entity.dart';
import 'package:atlas_app/reader/domain/use_cases/update_lockscreen_media_use_case.dart';
import 'package:atlas_app/reader/infrastructure/repositories/lockscreen_repository.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';

/// ViewModel for lockscreen notification widget (mobile + desktop SMTC/MPRIS).
/// Extends `ChangeNotifier` per MVVM, exposes immutable state.
class LockscreenViewModel extends ChangeNotifier {
  LockscreenViewModel({
    required LockscreenRepository repository,
    required UpdateLockscreenMediaUseCase useCase,
    required SpeechEngine engine,
  })  : _repo = repository,
        _useCase = useCase,
        _engine = engine {
    _sub = _engine.events.listen(_onEvent);
  }

  final LockscreenRepository _repo;
  final UpdateLockscreenMediaUseCase _useCase;
  final SpeechEngine _engine;
  StreamSubscription<SpeechEvent>? _sub;

  LockscreenMediaEntity? _state;
  LockscreenMediaEntity? get state => _state;
  bool get isActive => _state != null && _state!.isPlaying;

  String? _error;
  String? get error => _error;

  void _onEvent(SpeechEvent event) {
    // ViewModel handles UI state, delegates business transform to UseCase/Repo
    switch (event) {
      case ChapterStarted():
        final s = _engine.session;
        // Only show playing if engine is actually playing (not just loading a chapter)
        if (s != null && _engine.isPlaying) {
          _state = _repo.fromSession(s, position: Duration.zero, duration: null, isPlaying: true, speed: 1.0);
          notifyListeners();
          unawaited(_useCase.onChapterStarted(s, event));
        }
        break;
      case final SentenceStarted s:
        _state = _state?.copyWith(isPlaying: true);
        notifyListeners();
        unawaited(_useCase.onSentenceStarted(_engine.session, s));
        break;
      case SpeechPaused():
        _state = _state?.copyWith(isPlaying: false);
        notifyListeners();
        unawaited(_useCase.onPaused());
        break;
      case SpeechStopped():
      case SpeechCompleted():
        _state = _state?.copyWith(isPlaying: false);
        notifyListeners();
        unawaited(_useCase.onStopped());
        break;
      case ChapterFinished():
        // Chapter ended (auto-advance or natural end) - ensure not showing as playing
        _state = _state?.copyWith(isPlaying: false);
        notifyListeners();
        unawaited(_useCase.onStopped());
        break;
      default:
        break;
    }
  }

  Future<void> pause() async {
    _error = null;
    try {
      await _engine.pause();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resume() async {
    _error = null;
    try {
      await _engine.resume();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _error = null;
    try {
      await _engine.stop();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
