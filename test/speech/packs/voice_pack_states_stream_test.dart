import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart' as db;
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_catalog.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_downloader.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';
import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Regression for the silent-download bug: the gallery's pack states are a
/// *reactive* stream of the store, re-queried on every downloader state
/// change — the `downloading` record must appear while the download runs,
/// not only after it finishes.

const _packId = 'vits-piper-en_US-amy-low';
const _familyId = 'piper-en_US-amy';

String _catalogJson() {
  final modelSha = sha256.convert(utf8.encode('model-bytes')).toString();
  final tokensSha = sha256.convert(utf8.encode('tokens')).toString();
  return jsonEncode({
    'schemaVersion': 1,
    'families': [
      {
        'id': _familyId,
        'name': 'Amy',
        'language': 'en',
        'locale': 'en-US',
        'gender': 'female',
        'previewUrl': null,
        'flavors': [
          {
            'quality': 'compact',
            'packId': _packId,
            'sizeBytes':
                utf8.encode('model-bytes').length +
                utf8.encode('tokens').length,
            'modelFormatVersion': 1,
            'files': {
              'model.onnx': {'sha256': modelSha},
              'tokens.txt': {'sha256': tokensSha},
            },
          },
        ],
      },
    ],
  });
}

http.Client _clientServing() {
  const base = 'https://cdn.test/atlas_tts/voices/$_familyId/$_packId';
  final bodies = <String, Uint8List>{
    '$base/model.onnx': Uint8List.fromList(utf8.encode('model-bytes')),
    '$base/tokens.txt': Uint8List.fromList(utf8.encode('tokens')),
  };
  // Drip-feeds the model body so the `downloading` state lasts long enough
  // for a poll to observe it (an instant 404-or-200 response would race the
  // whole download past the in-flight window on a fast host).
  Stream<List<int>> slow(Uint8List body) async* {
    for (var i = 0; i < body.length; i += 4) {
      yield body.sublist(i, i + 4 > body.length ? body.length : i + 4);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  return MockClient.streaming((request, _) async {
    final body = bodies[request.url.toString()];
    if (body == null) {
      return http.StreamedResponse(Stream.value(utf8.encode('missing')), 404);
    }
    return http.StreamedResponse(slow(body), 200);
  });
}

/// Base override set shared by every container in this file: the real store
/// + downloader against a fake CDN and an in-memory database.
List<Override> _baseOverrides(String documentsRoot, AppDatabase database) => [
  db.databaseProvider.overrideWithValue(database),
  voicePackDocumentsRootProvider.overrideWithValue(documentsRoot),
  voicePackEndpointsProvider.overrideWithValue(
    const VoicePackCatalogEndpoints(
      baseUrl: 'https://cdn.test/atlas_tts',
      catalogPath: 'catalog.json',
    ),
  ),
  voicePackCatalogProvider.overrideWith(
    (ref) async => VoicePackCatalog.tryDecode(_catalogJson()),
  ),
  speechVoicesProvider.overrideWith((ref) async => const <VoiceDescriptor>[]),
  voicePackProgressProvider.overrideWith(
    (ref) => const Stream<VoicePackProgress>.empty(),
  ),
  // The real downloader: the state-change stream under test.
  voicePackDownloaderProvider.overrideWith((ref) {
    final downloader = VoicePackDownloader(
      store: ref.watch(voicePackStoreProvider),
      documentsRoot: documentsRoot,
      location: ref.watch(voicePackEndpointsProvider).toLocation(),
      client: _clientServing(),
    );
    ref.onDispose(downloader.dispose);
    return downloader;
  }),
];

/// The real [speechEngineProvider] constructs a [FlutterTtsDriver], whose
/// plugin channel needs an initialized binding a plain test env lacks — so
/// tests get an engine backed by a fake driver instead.
SpeechEngine _fakeEngineOverride(Ref ref) {
  final engine = SpeechEngine(FakeSwapDriver(), InMemoryRecoveryStore());
  ref.onDispose(engine.dispose);
  return engine;
}

void main() {
  late Directory sandbox;
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sandbox = await Directory.systemTemp.createTemp('atlas_states_test');
    database = AppDatabase.memory();
    container = ProviderContainer(
      overrides: [
        ..._baseOverrides('${sandbox.path}/docs', database),
        speechEngineProvider.overrideWith(_fakeEngineOverride),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    try {
      sandbox.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<List<VoicePackRecord>> pollState(
    bool Function(List<VoicePackRecord>) condition,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final value =
          container.read(voicePackStatesProvider).valueOrNull ??
          const <VoicePackRecord>[];
      if (condition(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('pack state condition not reached within timeout');
  }

  test(
    'downloading record streams into pack states while the download runs',
    () async {
      // Initial (empty) state resolves first.
      final initial = await container.read(voicePackStatesProvider.future);
      expect(initial, isEmpty, reason: 'no pack records before any download');

      // The controller reads the catalog synchronously; let the overridden
      // FutureProvider resolve before the first action.
      await container.read(voicePackCatalogProvider.future);

      final controller = container.read(voicePackControllerProvider);
      final done = controller.downloadFamily(
        _familyId,
        quality: VoicePackQuality.compact,
      );

      // REGRESSION: the downloading record must reach the UI while the
      // download is still in flight (previously nothing appeared until done).
      final inFlight = await pollState(
        (records) => records.any(
          (r) =>
              r.packId == _packId &&
              (r.state == VoicePackState.downloading ||
                  r.state == VoicePackState.verifying),
        ),
      );
      expect(
        inFlight.single.state,
        isIn(const <VoicePackState>[
          VoicePackState.downloading,
          VoicePackState.verifying,
        ]),
        reason: 'in-flight record is visible via the reactive stream',
      );

      expect(await done, VoicePackDownloadResult.ready);

      // Terminal transition lands in the same stream without manual
      // invalidation.
      final settled = await pollState(
        (records) => records.any(
          (r) => r.packId == _packId && r.state == VoicePackState.ready,
        ),
      );
      expect(settled.single.state, VoicePackState.ready);
    },
  );

  group('driver hot-swap wiring', () {
    test('pack ready upgrades the engine driver; deleting the last pack '
        'downgrades back to platform TTS', () async {
      final neuralFake = FakeSwapDriver();
      final platformFake = FakeSwapDriver();
      final swapContainer = ProviderContainer(
        overrides: [
          ..._baseOverrides('${sandbox.path}/docs', database),
          speechEngineProvider.overrideWith(_fakeEngineOverride),
          voicePackControllerProvider.overrideWith((ref) {
            final controller = VoicePackController(ref)
              ..neuralDriverFactory = (() => neuralFake)
              ..platformDriverFactory = (() => platformFake);
            return controller;
          }),
        ],
      );
      try {
        await swapContainer.read(voicePackStatesProvider.future);
        await swapContainer.read(voicePackCatalogProvider.future);

        final controller = swapContainer.read(voicePackControllerProvider);
        final engine = swapContainer.read(speechEngineProvider);
        expect(
          identical(engine.driver, neuralFake),
          isFalse,
          reason: 'precondition: app-start driver is not neural',
        );

        // Upgrade: the pack became ready → neural driver takes over.
        expect(
          await controller.downloadFamily(
            _familyId,
            quality: VoicePackQuality.compact,
          ),
          VoicePackDownloadResult.ready,
        );
        expect(
          identical(engine.driver, neuralFake),
          isTrue,
          reason: 'pack-ready upgrades the pinned app-start driver',
        );
        expect(swapContainer.read(speechDriverEpochProvider), 1);

        // Downgrade: last pack deleted → back to platform TTS.
        await controller.deletePack(_packId);
        expect(
          identical(engine.driver, platformFake),
          isTrue,
          reason: 'no ready packs remain → platform TTS resumes',
        );
        expect(swapContainer.read(speechDriverEpochProvider), 2);
      } finally {
        swapContainer.dispose();
      }
    });
  });
}

/// Minimal [SpeechDriver] fake standing in for a neural driver: the real
/// `NeuralTtsDriver.tryCreate()` is platform-gated (null on Windows hosts),
/// so the controller's upgrade path is exercised through the injected
/// [VoicePackController.neuralDriverFactory].
class FakeSwapDriver implements SpeechDriver {
  @override
  Stream<SpeechDriverEvent> get events => const Stream.empty();
  @override
  DriverState get state => DriverState.ready;
  @override
  Stream<DriverState> get stateStream => const Stream.empty();

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
    String? language,
  }) async {}

  @override
  Future<void> speak(SpeechItem item) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume(SpeechItem item) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<List<VoiceDescriptor>> listVoices() async => const [];
  @override
  Future<void> warmup(SpeechItem item) async {}
  @override
  Future<List<int>?> synthesizeToBytes(SpeechItem item) async => null;
  @override
  Future<void> restart() async {}
  @override
  Future<void> dispose() async {}
}
