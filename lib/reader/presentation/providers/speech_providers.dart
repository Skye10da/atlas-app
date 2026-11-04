import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/speech/cache/tts_file_cache.dart';

import 'package:atlas_app/reader/speech/drivers/flutter_tts_driver.dart';
import 'package:atlas_app/reader/speech/playback_controller.dart';
import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/persistence/shared_prefs_recovery_store.dart';
import 'package:atlas_app/reader/speech/persistence/voice_cache.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings_repository.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Roughly what the narration bar should show. Derived from the driver's
/// [DriverState] / engine events rather than tracked by the UI itself.
enum NarrationStatus { idle, playing, paused }

/// Result of the one-time startup sequence (ASA §8). [voiceResetNotice] is
/// non-null when the persisted voice was no longer available and was silently
/// replaced with the platform default.
class SpeechStartupResult {
  const SpeechStartupResult({this.voiceResetNotice});

  final String? voiceResetNotice;
}

/// The configured voice that was persisted but is no longer installed.
final speechDriverNoticeProvider = StateProvider<String?>((ref) => null);

final speechDriverProvider = Provider<SpeechDriver>((ref) {
  // Windows SAPI now wrapped in try/catch in FlutterTtsDriver; Noop only as fallback if SAPI throws.
  // Keeping FlutterTtsDriver on Windows restores TTS playback (was silent with Noop).
  return FlutterTtsDriver();
});

final speechRecoveryStoreProvider = Provider<RecoveryStore>(
  (ref) => SharedPrefsRecoveryStore(),
);

final narrationSettingsRepositoryProvider =
    Provider<NarrationSettingsRepository>(
      (ref) => NarrationSettingsRepository(),
    );

final voiceCacheProvider = Provider<VoiceCache>((ref) => VoiceCache());

final ttsFileCacheProvider = Provider<TtsFileCache>((ref) => TtsFileCache());

final speechEngineProvider = Provider<SpeechEngine>((ref) {
  final engine = SpeechEngine(
    ref.watch(speechDriverProvider),
    ref.watch(speechRecoveryStoreProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final speechPlaybackControllerProvider = Provider<AtlasPlaybackController>(
  (ref) => AtlasPlaybackController(ref.watch(speechEngineProvider)),
);

/// The engine's SpeechEvent stream as a provider so multiple widgets can
/// listen to the same broadcast stream through Riverpod.
final speechEventsProvider = StreamProvider<SpeechEvent>((ref) {
  return ref.watch(speechEngineProvider).events;
});

/// Current narration transport status, derived from the driver state stream.
final narrationStatusProvider = StreamProvider<NarrationStatus>((ref) {
  return ref
      .watch(speechDriverProvider)
      .stateStream
      .map(
        (s) => switch (s) {
          DriverState.speaking => NarrationStatus.playing,
          DriverState.paused => NarrationStatus.paused,
          _ => NarrationStatus.idle,
        },
      );
});

/// The SpeechItem currently being narrated, for sentence highlighting. Set by
/// the Reader as sentences start/finish.
final activeSpeechItemProvider = StateProvider<SpeechItem?>((ref) => null);

/// The word currently being spoken within [activeSpeechItemProvider]'s
/// sentence, emitted by the driver's word boundaries. Drives the karaoke-style
/// lyric highlight in the Now Playing sheet. Cleared on sentence change/stop.
final activeWordBoundaryProvider = StateProvider<WordBoundary?>((ref) => null);

/// Available platform voices, served from the disk/memory cache when present
/// (ASA §9) and refreshed from the driver otherwise.
final speechVoicesProvider = FutureProvider<List<VoiceDescriptor>>((ref) async {
  final cache = ref.watch(voiceCacheProvider);
  final cached = cache.cached;
  if (cached != null) return cached;
  final voices = await _safeListVoices(ref.watch(speechDriverProvider));
  if (voices.isNotEmpty) await cache.persist(voices);
  return voices;
});

/// Loads + persists [NarrationSettings] and live-applies changes to the engine.
final narrationSettingsProvider =
    AsyncNotifierProvider<NarrationSettingsController, NarrationSettings>(
      NarrationSettingsController.new,
    );

class NarrationSettingsController extends AsyncNotifier<NarrationSettings> {
  @override
  Future<NarrationSettings> build() {
    return ref.read(narrationSettingsRepositoryProvider).load();
  }

  Future<void> apply(NarrationSettings next) async {
    state = AsyncValue.data(next);
    await ref.read(narrationSettingsRepositoryProvider).save(next);
    final engine = ref.read(speechEngineProvider);
    engine.setSleepTimer(next.sleepTimer);
    if (engine.session != null) {
      await engine.updateSettings(next);
    }
  }
}

/// One-time startup sequence (ASA §8): init audio_service, populate the voice
/// cache, validate the persisted driver voice. Session restoration is deferred
/// to the Reader, which alone can re-derive a SpeechQueue from chapter text. It
/// also surfaces a one-time notice when the persisted voice is gone.
final speechStartupProvider = FutureProvider<SpeechStartupResult>((ref) async {
  final controller = ref.watch(speechPlaybackControllerProvider);
  // Lockscreen widget: mobile + desktop (Windows SMTC / macOS Now Playing).
  // Previously skipped on Windows to avoid SAPI mute — now enabled with
  // non-ongoing notification that doesn't steal focus.
  try {
    await AudioService.init(
      builder: () => controller,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.atlas.app.audio_service',
        androidNotificationChannelName: 'Narration',
        androidNotificationChannelDescription:
            'Background novel narration and text-to-speech',
        // Mobile: ongoing lockscreen widget; Desktop (Windows SMTC): non-ongoing
        // so SAPI not ducked, still shows in System Media Controls.
        androidNotificationOngoing: !kIsWeb && !Platform.isWindows,
        androidStopForegroundOnPause: !kIsWeb && !Platform.isWindows,
        androidNotificationClickStartsActivity: true,
        fastForwardInterval: const Duration(seconds: 15),
        rewindInterval: const Duration(seconds: 15),
        // Enables Windows/macOS/Linux system lockscreen/media keys via SMTC
        artDownscaleWidth: 300,
        artDownscaleHeight: 300,
      ),
    );
  } catch (_) {
    // audio_service is unsupported on some desktops before just_audio wiring;
    // narration still works via flutter_tts without the OS media session.
  }
  // Configure audio session for ducking/interruptions where available.
  // Skip on Windows — AudioSession speech config can duck SAPI to 0 and cause "no audio".
  if (!kIsWeb && !Platform.isWindows) {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      session.becomingNoisyEventStream.listen((_) {
        controller.pause();
      });
      var pausedForInterruption = false;
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            // Ducking handled by OS; keep playing at lower volume.
          } else {
            // Interrupted (phone call / assistant / focus loss) — pause and
            // remember so we can resume automatically when it ends.
            pausedForInterruption = true;
            controller.pause();
          }
        } else {
          if (event.type != AudioInterruptionType.duck && pausedForInterruption) {
            // Interruption ended — resume narration automatically instead of
            // leaving the driver paused indefinitely (playback gets stuck).
            pausedForInterruption = false;
            controller.resumeSpeech();
          }
        }
      });
    } catch (_) {}
  }

  final cache = ref.watch(voiceCacheProvider);
  await cache.init();

  String? notice;
  final driver = ref.watch(speechDriverProvider);
  final voices = await _safeListVoices(driver);
  if (voices.isNotEmpty) {
    await cache.persist(voices);
  }

  final settingsRepo = ref.read(narrationSettingsRepositoryProvider);
  final settings = await settingsRepo.load();
  final selected = settings.selectedVoiceId;
  if (selected != null &&
      voices.isNotEmpty &&
      !voices.any((v) => v.id == selected)) {
    notice = 'Selected narration voice is no longer available; using default.';
    final reset = settings.copyWith(
      selectedVoiceId: null,
      clearActiveProfile: true,
    );
    await settingsRepo.save(reset);
    ref.read(speechDriverNoticeProvider.notifier).state = notice;
  }

  return SpeechStartupResult(voiceResetNotice: notice);
});

Future<List<VoiceDescriptor>> _safeListVoices(SpeechDriver driver) async {
  try {
    return await driver.listVoices();
  } catch (_) {
    return const [];
  }
}
