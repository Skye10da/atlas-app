/// Riverpod wiring for the M5 voice-pack system. The CDN base URL lives in
/// one place ([kVoicePackCdnBase]) and every dependency is overridable so
/// tests (and future ops changes) never hunt through the provider graph.
library;

import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart' as db;
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/speech/drivers/flutter_tts_driver.dart';
import 'package:atlas_app/reader/speech/drivers/neural_tts_driver.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_catalog.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_downloader.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Default CDN root for the voice-pack system (NTD §3.5). Hugging Face
/// model repo with real directory paths — the app builds
/// `<base>/voices/<familyId>/<packId>/<file>` against it and public repos
/// serve downloads with no token. Replace `<repo-id>` with the published
/// repo (see atlas_tts/tool/publish_voice_packs.ps1); override via
/// [voicePackEndpointsProvider] for tests.
const String kVoicePackCdnBase =
    'https://huggingface.co/Skye000/atlas-voice-packs/resolve/main';

final voicePackEndpointsProvider = Provider<VoicePackCatalogEndpoints>(
  (ref) => const VoicePackCatalogEndpoints(
    baseUrl: kVoicePackCdnBase,
    catalogPath: 'catalog.json',
  ),
);

/// Documents root for pack paths (same sandbox math as the driver's sync
/// gate — public wrapper, not the test-only member). Null on platforms
/// without pack support: the gallery then shows platform voices only.
final voicePackDocumentsRootProvider = Provider<String?>((ref) {
  return NeuralTtsDriver.documentsRootForPacks();
});

final voicePackStoreProvider = Provider<VoicePackStore>((ref) {
  return VoicePackStore(database: ref.watch(db.databaseProvider));
});

final voicePackDownloaderProvider = Provider<VoicePackDownloader>((ref) {
  final root = ref.watch(voicePackDocumentsRootProvider) ?? '';
  final downloader = VoicePackDownloader(
    store: ref.watch(voicePackStoreProvider),
    documentsRoot: root,
    location: ref.watch(voicePackEndpointsProvider).toLocation(),
  );
  ref.onDispose(downloader.dispose);
  return downloader;
});

/// Cached-or-fetched catalog, with a one-shot startup hygiene pass
/// (interrupted downloads → corrupt; stale `.tmp-*` scratch dirs removed).
final voicePackCatalogProvider = FutureProvider<VoicePackCatalog?>((ref) async {
  final catalog = await VoicePackCatalogService(
    endpoints: ref.watch(voicePackEndpointsProvider),
  ).load();
  if (ref.watch(voicePackDocumentsRootProvider) != null) {
    await ref.read(voicePackDownloaderProvider).recoverStaleState();
  }
  return catalog;
});

/// Per-pack persisted state, **reactive**: the downloader's
/// `stateChangeStream` fires on every transition (downloading → verifying →
/// ready / corrupt / cancelled), and each event re-queries the store so the
/// gallery shows the in-flight row the moment a download starts — not only
/// after it finishes. (Previously a one-shot FutureProvider, which is why
/// downloads ran with no progress indication.)
final voicePackStatesProvider = StreamProvider<List<VoicePackRecord>>((
  ref,
) async* {
  yield await ref.watch(voicePackStoreProvider).all();
  await for (final _
      in ref.watch(voicePackDownloaderProvider).stateChangeStream) {
    yield await ref.watch(voicePackStoreProvider).all();
  }
});

/// Actions over packs: download with quality choice, cancel, delete,
/// quality memory. Owns the "pack became ready" bookkeeping (invalidate
/// voice lists so the gallery and the driver see the new voice).
class VoicePackController {
  VoicePackController(this._ref);

  final Ref _ref;

  VoicePackStore get _store => _ref.read(voicePackStoreProvider);
  VoicePackDownloader get _downloader => _ref.read(voicePackDownloaderProvider);
  VoicePackCatalog? get catalog =>
      _ref.read(voicePackCatalogProvider).valueOrNull;

  /// Resolves the flavor the user chose for [familyId], falling back to
  /// the smallest available (a compact default respects metered data).
  Future<VoicePackFlavor?> resolveFlavor(String familyId) async {
    final family = catalog?.family(familyId);
    if (family == null) return null;
    final remembered = await _store.preferredQuality(familyId);
    final quality = remembered ?? VoicePackQuality.compact;
    final exact = family.flavor(quality);
    return exact ?? (family.flavors.isNotEmpty ? family.flavors.first : null);
  }

  Future<VoicePackDownloadResult> downloadFamily(
    String familyId, {
    VoicePackQuality? quality,
  }) async {
    final family = catalog?.family(familyId);
    if (family == null) return VoicePackDownloadResult.failed;
    final flavor = quality != null
        ? (family.flavor(quality) ??
              (family.flavors.isNotEmpty ? family.flavors.first : null))
        : await resolveFlavor(familyId);
    if (flavor == null) return VoicePackDownloadResult.failed;
    if (quality != null) await _store.setPreferredQuality(familyId, quality);
    final result = await _downloader.download(flavor, familyId: familyId);
    // Refresh pack-state UI on every terminal result (ready, failed,
    // cancelled all change the persisted record).
    await _invalidateVoiceState();
    return result;
  }

  void cancel(String packId) => _downloader.cancel(packId);

  /// Deletes an installed pack (files + record) and refreshes voice state.
  Future<void> deletePack(String packId) async {
    final root = _ref.read(voicePackDocumentsRootProvider);
    if (root != null) {
      try {
        final dir = Directory('$root/atlas_tts/voices/$packId');
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }
    await _store.delete(packId);
    await _invalidateVoiceState();
  }

  /// Refreshes the voice list caches so the driver + gallery see changes,
  /// then hot-swaps the active driver if the pack change warrants it.
  /// The voice cache holds a memory snapshot that would otherwise shadow
  /// the driver's fresh listVoices() (which reads packs from disk live), so
  /// it is dropped here before the provider invalidation.
  Future<void> _invalidateVoiceState() async {
    await _maybeSwapDriver();
    _ref.read(voiceCacheProvider).clearMemory();
    _ref.invalidate(voicePackStatesProvider);
    _ref.invalidate(speechVoicesProvider);
  }

  /// Injectable neural-driver factory ([visibleForTesting] seam): production
  /// uses the real capability-gated [NeuralTtsDriver.tryCreate]; tests
  /// substitute a fake so the swap paths run on any host. Return type is
  /// [SpeechDriver] so fakes don't have to subclass the real driver.
  @visibleForTesting
  SpeechDriver? Function() neuralDriverFactory = NeuralTtsDriver.tryCreate;

  /// Injectable platform-driver factory for the downgrade path — mirrors
  /// [neuralDriverFactory] so tests never construct the real
  /// [FlutterTtsDriver] (its plugin channel needs an initialized binding).
  @visibleForTesting
  SpeechDriver Function() platformDriverFactory = FlutterTtsDriver.new;

  /// The driver this controller swapped in, if any (a neural driver in
  /// production; any fake in tests). Downgrade only undoes our own swap,
  /// or a boot-time neural driver detected by type.
  SpeechDriver? _swappedNeural;

  /// Driver hot-swap (NTD §3.5 / ASA §13). The app-start driver selection
  /// binds [SpeechEngine] (and through it the audio_service handler) once,
  /// so a pack installed *after* boot used to leave narration pinned to
  /// platform TTS forever — fatal on devices whose platform engine is
  /// broken ("not bound to TTS engine" on every utterance). Now:
  ///
  /// * **Upgrade** — no neural driver active + [NeuralTtsDriver.tryCreate]
  ///   now passes its pack-presence gate (a pack finished installing) →
  ///   swap it in. Playback mid-sentence resumes on the neural voice.
  /// * **Downgrade** — neural driver active but no ready packs remain
  ///   (last pack deleted) → swap back to platform TTS.
  ///
  /// [speechDriverEpochProvider] is bumped so providers derived from the
  /// driver (transport status, voice list) re-resolve from the new driver.
  Future<void> _maybeSwapDriver() async {
    final engine = _ref.read(speechEngineProvider);
    final isNeural =
        engine.driver is NeuralTtsDriver ||
        identical(engine.driver, _swappedNeural);
    if (!isNeural) {
      final neural = neuralDriverFactory();
      if (neural != null) await _swap(engine, neural);
      return;
    }
    // Downgrade: no ready packs left on disk (last pack deleted).
    final records = await _store.all();
    final hasReady = records.any((r) => r.state == VoicePackState.ready);
    if (!hasReady) {
      await _swap(engine, platformDriverFactory());
      _swappedNeural = null;
    }
  }

  Future<void> _swap(SpeechEngine engine, SpeechDriver next) async {
    if (identical(engine.driver, next)) return;
    await engine.swapDriver(next);
    _swappedNeural = next;
    _ref.read(speechDriverEpochProvider.notifier).state++;
  }
}

final voicePackControllerProvider = Provider<VoicePackController>(
  (ref) => VoicePackController(ref),
);

// ---------------------------------------------------------------------------
// Merge layer: gallery rows = CDN families + platform voices
// ---------------------------------------------------------------------------
/// A gallery row: either a pack family (HD, downloadable) or a platform
/// voice (Basic). The UI never mixes the two domains.
sealed class VoiceGalleryEntry {
  const VoiceGalleryEntry({required this.key});
  final String key;
}

class PackVoiceEntry extends VoiceGalleryEntry {
  PackVoiceEntry({
    required this.family,
    required this.installedPackIds,
    required this.records,
  }) : super(key: 'pack:${family.id}');

  final VoicePackFamily family;

  /// Pack ids of every installed (ready) flavor of this family — a user can
  /// have Compact and Best on disk at once. Any of these is a valid
  /// `selectedVoiceId`; selection flows through the existing
  /// NeuralTtsDriver pack resolution untouched.
  final Set<String> installedPackIds;
  final List<VoicePackRecord> records;

  /// Ready records by quality tier, for chip state rendering.
  VoicePackRecord? readyRecord(VoicePackQuality quality) {
    for (final r in records) {
      if (r.state == VoicePackState.ready && r.quality == quality) return r;
    }
    return null;
  }

  /// Any in-flight record (downloading/verifying) for live progress rows.
  VoicePackRecord? get activeRecord {
    for (final r in records) {
      if (r.state == VoicePackState.downloading ||
          r.state == VoicePackState.verifying) {
        return r;
      }
    }
    return null;
  }
}

class PlatformVoiceEntry extends VoiceGalleryEntry {
  PlatformVoiceEntry(this.voice) : super(key: 'platform:${voice.id}');
  final VoiceDescriptor voice;
}

/// Builds the gallery model: pack families first (recommended), platform
/// voices after.
List<VoiceGalleryEntry> buildVoiceGallery({
  required VoicePackCatalog? catalog,
  required List<VoicePackRecord> records,
  required List<VoiceDescriptor> platformVoices,
}) {
  final byFamily = <String, List<VoicePackRecord>>{};
  for (final r in records) {
    byFamily.putIfAbsent(r.familyId, () => []).add(r);
  }

  final entries = <VoiceGalleryEntry>[];
  for (final family in catalog?.families ?? const <VoicePackFamily>[]) {
    final ready = byFamily[family.id]
        ?.where((r) => r.state == VoicePackState.ready)
        .map((r) => r.packId)
        .toSet();
    entries.add(
      PackVoiceEntry(
        family: family,
        installedPackIds: ready ?? const <String>{},
        records: byFamily[family.id] ?? const [],
      ),
    );
  }
  for (final v in platformVoices) {
    entries.add(PlatformVoiceEntry(v));
  }
  return entries;
}

/// Watched gallery model shared by the narration tab and the voice pill —
/// merges the catalog, pack states and platform voices.
final voiceGalleryEntriesProvider = Provider<List<VoiceGalleryEntry>>((ref) {
  return buildVoiceGallery(
    catalog: ref.watch(voicePackCatalogProvider).valueOrNull,
    records: ref.watch(voicePackStatesProvider).valueOrNull ?? const [],
    platformVoices: ref.watch(speechVoicesProvider).valueOrNull ?? const [],
  );
});

/// Display name for the selected voice, resolved against the merged gallery.
/// Falls back to "Platform default" for null/unknown ids.
String resolveVoiceLabel(List<VoiceGalleryEntry> entries, String? voiceId) {
  if (voiceId == null || voiceId.isEmpty) return 'Platform default';
  for (final entry in entries) {
    switch (entry) {
      case final PackVoiceEntry pack:
        for (final quality in VoicePackQuality.values) {
          final record = pack.readyRecord(quality);
          if (record != null && record.packId == voiceId) {
            return '${pack.family.name} · ${quality.label}';
          }
        }
      case final PlatformVoiceEntry platform:
        if (platform.voice.id == voiceId) {
          return platform.voice.id.split('@').first;
        }
    }
  }
  return voiceId.split('@').first;
}

/// True when the selected voice is platform TTS (or the default) — the only
/// cases where a pitch slider is meaningful. VITS packs have no pitch axis
/// (NTD §3.3).
bool isPlatformVoiceSelected(List<VoiceGalleryEntry> entries, String? voiceId) {
  if (voiceId == null || voiceId.isEmpty) return true;
  for (final entry in entries) {
    switch (entry) {
      case final PackVoiceEntry pack:
        if (pack.installedPackIds.contains(voiceId)) return false;
      case final PlatformVoiceEntry platform:
        if (platform.voice.id == voiceId) return true;
    }
  }
  return true;
}

/// Live byte progress of the active download, for the gallery's in-flight
/// rows. Watchers must guard on [VoicePackProgress.packId] — only the
/// currently-downloading pack emits.
final voicePackProgressProvider = StreamProvider<VoicePackProgress>((ref) {
  return ref.watch(voicePackDownloaderProvider).progressStream;
});
