import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final speechDriverProvider = Provider<SpeechDriver>(
  (ref) => FlutterTtsDriver(),
);

final speechRecoveryStoreProvider = Provider<RecoveryStore>(
  (ref) => SharedPrefsRecoveryStore(),
);

final narrationSettingsRepositoryProvider =
    Provider<NarrationSettingsRepository>(
      (ref) => NarrationSettingsRepository(),
    );

final voiceCacheProvider = Provider<VoiceCache>((ref) => VoiceCache());

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
  try {
    await AudioService.init(
      builder: () => controller,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.atlas.app.audio_service',
        androidNotificationChannelName: 'Narration',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    // audio_service is unsupported on Windows/Linux; narration still works via
    // flutter_tts without the OS media session.
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
