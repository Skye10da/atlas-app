import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/narration_tab.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

const _catalogBody = '''
{"schemaVersion": 1, "families": [
  {"id": "piper-en_US-amy", "name": "Amy", "language": "en",
   "locale": "en-US", "gender": "female",
   "flavors": [
     {"quality": "standard", "packId": "p-amy-med", "sizeBytes": 81000000,
      "files": {"m.onnx": {"sha256": "s"}}}
   ]}
]}
''';

VoicePackRecord _record(String packId, VoicePackState state) => VoicePackRecord(
  packId: packId,
  familyId: 'piper-en_US-amy',
  quality: VoicePackQuality.standard,
  state: state,
  bytes: 1,
  totalBytes: 1,
  updatedAt: DateTime.now(),
);

class _FakeSettingsController extends NarrationSettingsController {
  _FakeSettingsController(this.initial);
  final NarrationSettings initial;
  final applied = <NarrationSettings>[];

  @override
  Future<NarrationSettings> build() async => initial;

  @override
  Future<void> apply(NarrationSettings next) async {
    applied.add(next);
  }
}

const _platformVoice = VoiceDescriptor(
  id: 'samantha@en-US',
  language: 'en',
  locale: 'en-US',
);

Future<void> _pump(
  WidgetTester tester, {
  required NarrationSettings settings,
  List<VoicePackRecord> records = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voicePackCatalogProvider.overrideWith(
          (ref) async => VoicePackCatalog.tryDecode(_catalogBody),
        ),
        voicePackStatesProvider.overrideWith((ref) => Stream.value(records)),
        speechVoicesProvider.overrideWith(
          (ref) async => const [_platformVoice],
        ),
        narrationSettingsProvider.overrideWith(
          () => _FakeSettingsController(settings),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: NarrationTab())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('platform default: voice card + speed pill + pitch slider', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const NarrationSettings(
        pronunciationEnabled: false,
        selectedVoiceId: 'samantha@en-US',
      ),
    );

    expect(find.byKey(const ValueKey('voice_card')), findsOneWidget);
    expect(find.text('samantha'), findsOneWidget);
    expect(find.byType(NarrationSpeedControl), findsOneWidget);
    expect(
      find.text('Pitch'),
      findsOneWidget,
      reason: 'pitch shows for platform voices',
    );
  });

  testWidgets('neural pack selected: label carries tier, pitch hidden', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const NarrationSettings(
        pronunciationEnabled: false,
        selectedVoiceId: 'p-amy-med',
      ),
      records: [_record('p-amy-med', VoicePackState.ready)],
    );

    expect(find.text('Amy · Standard'), findsOneWidget);
    expect(
      find.text('Pitch'),
      findsNothing,
      reason: 'VITS packs have no pitch axis',
    );
  });

  testWidgets('profiles section is gone', (tester) async {
    await _pump(
      tester,
      settings: const NarrationSettings(
        pronunciationEnabled: false,
        selectedVoiceId: 'samantha@en-US',
      ),
    );

    expect(find.text('Profiles'), findsNothing);
  });

  testWidgets('behavior & storage group is collapsed by default', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const NarrationSettings(
        pronunciationEnabled: false,
        selectedVoiceId: 'samantha@en-US',
      ),
    );

    expect(find.text('Behavior & storage'), findsOneWidget);
    expect(
      find.text('Auto-advance chapters'),
      findsNothing,
      reason: 'collapsed until expanded',
    );

    await tester.tap(find.text('Behavior & storage'));
    await tester.pumpAndSettle();
    expect(find.text('Auto-advance chapters'), findsOneWidget);
    expect(find.text('Offline TTS cache'), findsOneWidget);
    expect(find.text('Pronunciation'), findsOneWidget);
  });

  testWidgets('unknown pack id still renders without crashing', (tester) async {
    await _pump(
      tester,
      settings: const NarrationSettings(
        pronunciationEnabled: false,
        selectedVoiceId: 'gone-pack',
      ),
    );

    expect(find.byKey(const ValueKey('voice_card')), findsOneWidget);
    expect(
      find.text('gone-pack'),
      findsOneWidget,
      reason: 'falls back to the raw id, split at the @ separator',
    );
  });
}
