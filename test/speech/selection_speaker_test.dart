import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/services/dictionary_service.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings_repository.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';

class FakeDriver implements SpeechDriver {
  final spoken = <SpeechItem>[];
  double? lastRate;
  double? lastPitch;
  String? lastVoiceId;
  String? lastLanguage;

  @override
  Stream<SpeechDriverEvent> get events => const Stream<SpeechDriverEvent>.empty();
  @override
  DriverState get state => DriverState.ready;
  @override
  Stream<DriverState> get stateStream => const Stream<DriverState>.empty();

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
    String? language,
  }) async {
    lastRate = rate;
    lastPitch = pitch;
    lastVoiceId = voiceId;
    lastLanguage = language;
  }

  @override
  Future<void> speak(SpeechItem item) async => spoken.add(item);

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume(SpeechItem item) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<List<VoiceDescriptor>> listVoices() async => const [];
  @override
  Future<void> restart() async {}
  @override
  Future<void> dispose() async {}
}

class FakeNarrationSettingsRepository extends NarrationSettingsRepository {

  FakeNarrationSettingsRepository(this.settings);
  final NarrationSettings settings;

  @override
  Future<NarrationSettings> load() async => settings;

  @override
  Future<void> save(NarrationSettings settings) async {}
}

class _SpeakHarness extends ConsumerStatefulWidget {
  const _SpeakHarness({
    required this.driver,
    required this.text,
    required this.language,
    this.voiceId,
    required this.onSpoken,
  });

  final FakeDriver driver;
  final String text;
  final String language;
  final String? voiceId;
  final void Function(FakeDriver driver) onSpoken;

  @override
  ConsumerState<_SpeakHarness> createState() => _SpeakHarnessState();
}

class _SpeakHarnessState extends ConsumerState<_SpeakHarness> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await ref.read(narrationSettingsProvider.future);
    await const SelectionSpeaker().speak(
      ref: ref,
      bookId: 'b1',
      chapterId: 'c1',
      text: widget.text,
      language: widget.language,
      voiceId: widget.voiceId,
    );
    widget.onSpoken(widget.driver);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeDriver driver,
  required String text,
  String language = 'en-US',
  NarrationSettings? settings,
  required void Function(FakeDriver driver) onSpoken,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        speechDriverProvider.overrideWithValue(driver),
        if (settings != null)
          narrationSettingsRepositoryProvider.overrideWithValue(
            FakeNarrationSettingsRepository(settings),
          ),
      ],
      child: _SpeakHarness(
        driver: driver,
        text: text,
        language: language,
        onSpoken: onSpoken,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ResolveHarness extends ConsumerStatefulWidget {
  const _ResolveHarness({
    required this.code,
    required this.onResolved,
  });

  final String code;
  final void Function(String?) onResolved;

  @override
  ConsumerState<_ResolveHarness> createState() => _ResolveHarnessState();
}

class _ResolveHarnessState extends ConsumerState<_ResolveHarness> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final result = await resolveVoiceIdForLanguage(ref, widget.code);
    widget.onResolved(result);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<String?> _resolve(
  WidgetTester tester, {
  required List<VoiceDescriptor> voices,
  required String code,
}) async {
  String? result;
  await tester.pumpWidget(
    ProviderScope(
      key: ObjectKey(code),
      overrides: [
        speechVoicesProvider.overrideWith((ref) async => voices),
      ],
      child: _ResolveHarness(code: code, onResolved: (r) => result = r),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('SelectionSpeaker configures the driver with narration settings', (tester) async {
    final driver = FakeDriver();
    await _pump(
      tester,
      driver: driver,
      text: 'Hello world.',
      settings: const NarrationSettings(
        speechRate: 1.4,
        speechPitch: 0.8,
        selectedVoiceId: 'voice-42',
      ),
      onSpoken: (d) {
        expect(d.spoken, hasLength(1));
        expect(d.spoken.single.text, 'Hello world.');
      },
    );

    expect(driver.lastRate, 1.4);
    expect(driver.lastPitch, 0.8);
    expect(driver.lastVoiceId, 'voice-42');
    expect(driver.lastLanguage, 'en-US');
    expect(driver.spoken.single.bookId, 'b1');
    expect(driver.spoken.single.chapterId, 'c1');
    expect(driver.spoken.single.language, 'en-US');
  });

  testWidgets('SelectionSpeaker uses defaults when settings are unloaded', (tester) async {
    final driver = FakeDriver();
    await _pump(
      tester,
      driver: driver,
      text: 'Hello.',
      settings: const NarrationSettings(),
      onSpoken: (_) {},
    );

    expect(driver.lastRate, 1.0);
    expect(driver.lastPitch, 1.0);
    expect(driver.lastVoiceId, isNull);
    expect(driver.spoken.single.text, 'Hello.');
  });

  testWidgets('SelectionSpeaker applies an explicit voiceId and language override', (tester) async {
    final driver = FakeDriver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechDriverProvider.overrideWithValue(driver),
        ],
        child: _SpeakHarness(
          driver: driver,
          text: 'Bonjour. A greeting.',
          language: 'fr-FR',
          voiceId: 'fr-voice@fr-FR',
          onSpoken: (d) {
            expect(d.lastLanguage, 'fr-FR');
            expect(d.lastVoiceId, 'fr-voice@fr-FR');
            expect(d.spoken.single.language, 'fr-FR');
            expect(d.spoken.single.voiceId, 'fr-voice@fr-FR');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  });

  group('resolveVoiceIdForLanguage', () {
    const voices = [
      VoiceDescriptor(id: 'en-us-a@en-US', language: 'en', locale: 'en-US'),
      VoiceDescriptor(id: 'fr-paris@fr-FR', language: 'fr', locale: 'fr-FR'),
      VoiceDescriptor(id: 'zh-cn@zh-CN', language: 'zh', locale: 'zh-CN'),
      VoiceDescriptor(id: 'zh-tw@zh-TW', language: 'zh', locale: 'zh-TW'),
    ];

    testWidgets('picks a voice matching the language code', (tester) async {
      expect(await _resolve(tester, voices: voices, code: 'fr'),
          'fr-paris@fr-FR');
      expect(await _resolve(tester, voices: voices, code: 'en'),
          'en-us-a@en-US');
    });

    testWidgets('zh prefers a mainland voice when both are installed', (tester) async {
      expect(await _resolve(tester, voices: voices, code: 'zh'),
          'zh-cn@zh-CN');
    });

    testWidgets('returns null when no voice exists for the language', (tester) async {
      expect(await _resolve(tester, voices: voices, code: 'km'), isNull);
    });

    testWidgets('returns null when the voice list is empty', (tester) async {
      expect(
          await _resolve(tester, voices: const [], code: 'en'), isNull);
    });
  });

  test('localeForLanguageCode maps dictionary codes to BCP-47 locales', () {
    expect(localeForLanguageCode('fr'), 'fr-FR');
    expect(localeForLanguageCode('zh'), 'zh-CN');
    expect(localeForLanguageCode('en'), 'en-US');
    expect(localeForLanguageCode('xx'), 'xx');
  });
}