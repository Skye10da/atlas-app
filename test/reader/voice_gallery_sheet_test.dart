import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/voice_gallery_sheet.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_downloader.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

const _catalogBody = '''
{"schemaVersion": 1, "families": [
  {"id": "piper-en_US-amy", "name": "Amy", "language": "en",
   "locale": "en-US", "gender": "female",
   "previewUrl": "https://cdn.example/previews/amy.ogg",
   "flavors": [
     {"quality": "compact", "packId": "p-amy-low", "sizeBytes": 23000000,
      "files": {"m.onnx": {"sha256": "s"}}},
     {"quality": "standard", "packId": "p-amy-med", "sizeBytes": 81000000,
      "files": {"m.onnx": {"sha256": "s"}}},
     {"quality": "best", "packId": "p-amy-high", "sizeBytes": 110000000,
      "files": {"m.onnx": {"sha256": "s"}}}
   ]}
]}
''';

VoicePackRecord _record(
  String packId,
  VoicePackQuality quality,
  VoicePackState state,
) => VoicePackRecord(
  packId: packId,
  familyId: 'piper-en_US-amy',
  quality: quality,
  state: state,
  bytes: 1,
  totalBytes: 1,
  updatedAt: DateTime.now(),
);

/// Records applied settings without touching prefs/engine.
class _FakeSettingsController extends NarrationSettingsController {
  _FakeSettingsController([this.initialVoiceId]);

  final String? initialVoiceId;
  final applied = <NarrationSettings>[];

  @override
  Future<NarrationSettings> build() async => NarrationSettings(
    pronunciationEnabled: false,
    selectedVoiceId: initialVoiceId,
  );

  @override
  Future<void> apply(NarrationSettings next) async {
    applied.add(next);
  }
}

/// Records download actions without touching the CDN/store.
class _FakePackController extends VoicePackController {
  _FakePackController(super.ref);

  final downloads = <({String familyId, VoicePackQuality quality})>[];
  final cancels = <String>[];

  @override
  Future<VoicePackDownloadResult> downloadFamily(
    String familyId, {
    VoicePackQuality? quality,
  }) async {
    downloads.add((familyId: familyId, quality: quality!));
    return VoicePackDownloadResult.ready;
  }

  @override
  void cancel(String packId) => cancels.add(packId);
}

/// Pump harness. [packSink] captures the fake pack controller created
/// inside the override (the provider builds lazily on first action).
Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  required _FakeSettingsController settingsController,
  List<VoicePackRecord> records = const [],
  List<_FakePackController>? packSink,
  List<VoiceDescriptor> platformVoices = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voicePackCatalogProvider.overrideWith(
          (ref) async => VoicePackCatalog.tryDecode(_catalogBody),
        ),
        voicePackStatesProvider.overrideWith((ref) => Stream.value(records)),
        voicePackProgressProvider.overrideWith(
          (ref) => const Stream<VoicePackProgress>.empty(),
        ),
        speechVoicesProvider.overrideWith((ref) async => platformVoices),
        narrationSettingsProvider.overrideWith(() => settingsController),
        voicePackControllerProvider.overrideWith((ref) {
          final controller = _FakePackController(ref);
          packSink?.add(controller);
          return controller;
        }),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  _FakeSettingsController settingsController() => _FakeSettingsController();

  testWidgets('families render first with quality chips, platform after', (
    tester,
  ) async {
    await _pump(
      tester,
      settingsController: settingsController(),
      child: const VoiceGallerySheet(),
      platformVoices: const [
        VoiceDescriptor(
          id: 'samantha@en-US',
          language: 'en',
          locale: 'en-US',
          gender: 'Female',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Amy'), findsOneWidget);
    expect(find.byKey(const ValueKey('quality_p-amy-low')), findsOneWidget);
    expect(find.byKey(const ValueKey('quality_p-amy-med')), findsOneWidget);
    expect(find.byKey(const ValueKey('quality_p-amy-high')), findsOneWidget);
    expect(
      find.textContaining('Compact ·'),
      findsOneWidget,
      reason: 'chip label shows tier + download size',
    );
    expect(
      find.byKey(const ValueKey('platform_samantha@en-US')),
      findsOneWidget,
    );
  });

  testWidgets('installed tier chip is selected and tapping selects the pack', (
    tester,
  ) async {
    final settings = _FakeSettingsController('p-amy-low');
    await _pump(
      tester,
      settingsController: settings,
      records: [
        _record('p-amy-low', VoicePackQuality.compact, VoicePackState.ready),
      ],
      child: const VoiceGallerySheet(),
    );
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('quality_p-amy-low')),
    );
    expect(chip.selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('quality_p-amy-low')));
    await tester.pumpAndSettle();
    expect(settings.applied.single.selectedVoiceId, 'p-amy-low');
  });

  testWidgets('tapping an uninstalled tier starts that quality download', (
    tester,
  ) async {
    final settings = settingsController();
    final packs = <_FakePackController>[];
    await _pump(
      tester,
      settingsController: settings,
      packSink: packs,
      child: const VoiceGallerySheet(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quality_p-amy-med')));
    await tester.pumpAndSettle();
    expect(packs, hasLength(1));
    expect(packs.single.downloads.single.familyId, 'piper-en_US-amy');
    expect(packs.single.downloads.single.quality, VoicePackQuality.standard);
    expect(settings.applied.single.selectedVoiceId, 'p-amy-med',
        reason: 'download-then-auto-select: the chosen pack becomes the voice');
  });

  testWidgets('tapping a platform row selects its voice id', (tester) async {
    final settings = settingsController();
    await _pump(
      tester,
      settingsController: settings,
      child: const VoiceGallerySheet(),
      platformVoices: const [
        VoiceDescriptor(id: 'samantha@en-US', language: 'en', locale: 'en-US'),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('platform_samantha@en-US')));
    await tester.pumpAndSettle();
    expect(settings.applied.single.selectedVoiceId, 'samantha@en-US');
  });

  testWidgets(
    'an in-flight flavor shows busy state and cancel reaches the controller',
    (tester) async {
      final settings = settingsController();
      final packs = <_FakePackController>[];
      await _pump(
        tester,
        settingsController: settings,
        packSink: packs,
        records: [
          _record(
            'p-amy-med',
            VoicePackQuality.standard,
            VoicePackState.downloading,
          ),
        ],
        child: const VoiceGallerySheet(),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('quality_p-amy-med')),
      );
      expect(chip.onSelected, isNull, reason: 'busy chip is disabled');
      expect(
        find.byKey(const ValueKey('cancel_piper-en_US-amy')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('cancel_piper-en_US-amy')));
      await tester.pumpAndSettle();
      expect(packs.single.cancels.single, 'p-amy-med');
    },
  );

  testWidgets('an empty catalog shows the unavailable state with retry', (
    tester,
  ) async {
    final settings = settingsController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voicePackCatalogProvider.overrideWith((ref) async => null),
          voicePackStatesProvider.overrideWith(
            (ref) => Stream.value(<VoicePackRecord>[]),
          ),
          voicePackProgressProvider.overrideWith(
            (ref) => const Stream<VoicePackProgress>.empty(),
          ),
          speechVoicesProvider.overrideWith((ref) async => <VoiceDescriptor>[]),
          narrationSettingsProvider.overrideWith(() => settings),
        ],
        child: const MaterialApp(home: Scaffold(body: VoiceGallerySheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No voices available'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
