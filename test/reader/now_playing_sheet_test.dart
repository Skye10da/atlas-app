import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/voice_gallery_sheet.dart';
import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';
import 'package:atlas_app/reader/speech/speech_session_builder.dart';

class _FakeDriver implements SpeechDriver {
  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _state = StreamController<DriverState>.broadcast();
  DriverState _driverState = DriverState.ready;

  @override
  Stream<SpeechDriverEvent> get events => _events.stream;
  @override
  DriverState get state => _driverState;
  @override
  Stream<DriverState> get stateStream => _state.stream;

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
    String? language,
  }) async {}

  @override
  bool get supportsFileOutput => false;

  @override
  Future<File?> synthesizeToFile(SpeechItem item) async => null;

  @override
  Future<void> speak(SpeechItem item) async {
    _driverState = DriverState.speaking;
    _state.add(DriverState.speaking);
  }

  @override
  Future<void> pause() async {
    _driverState = DriverState.paused;
    _state.add(DriverState.paused);
  }

  @override
  Future<void> resume(SpeechItem item) async {
    _driverState = DriverState.speaking;
    _state.add(DriverState.speaking);
  }

  @override
  Future<void> stop() async {
    _driverState = DriverState.stopped;
    _state.add(DriverState.stopped);
  }

  @override
  Future<void> warmup(SpeechItem item) async {}
  @override
  Future<List<int>?> synthesizeToBytes(SpeechItem item) async => null;

  @override
  Future<List<VoiceDescriptor>> listVoices() async => const [];

  @override
  Future<void> restart() async {
    _driverState = DriverState.ready;
    _state.add(DriverState.ready);
  }

  @override
  Future<void> dispose() async {
    await _events.close();
    await _state.close();
  }
}

class _NoopRecoveryStore implements RecoveryStore {
  @override
  Future<void> save(SpeechCheckpoint checkpoint) async {}
  @override
  Future<SpeechCheckpoint?> load(String bookId) async => null;
  @override
  Future<void> clear(String bookId) async {}
}

class _FakeSettingsController extends NarrationSettingsController {
  @override
  Future<NarrationSettings> build() async => const NarrationSettings();
}

Future<ProviderContainer> pumpSheet(
  WidgetTester tester, {
  SpeechEngine? engine,
}) async {
  const builder = SpeechSessionBuilder();
  const chapter = ChapterEntity(
    id: 'chapter_1',
    bookId: 'book_1',
    title: 'The Beginning',
    index: 0,
    contentPath: '',
  );
  final session = builder.build(
    bookId: 'book_1',
    chapter: chapter,
    content:
        'First sentence of the chapter. Second sentence of the chapter. '
        'Third sentence of the chapter.',
    language: 'en',
    settings: const NarrationSettings(),
    bookTitle: 'The Great Tale',
  );

  final fakeDriver = _FakeDriver();
  final recoveryStore = _NoopRecoveryStore();
  final testEngine = engine ?? SpeechEngine(fakeDriver, recoveryStore);
  await testEngine.loadSession(session);

  final container = ProviderContainer(
    overrides: [
      speechDriverProvider.overrideWithValue(fakeDriver),
      speechRecoveryStoreProvider.overrideWithValue(recoveryStore),
      speechEngineProvider.overrideWithValue(testEngine),
      narrationSettingsProvider.overrideWith(_FakeSettingsController.new),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: NowPlayingSheet())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  return container;
}

void main() {
  testWidgets('expressive hero renders overline, cover, and glass strip', (
    tester,
  ) async {
    final container = await pumpSheet(tester);
    addTearDown(container.dispose);

    expect(find.text('NOW PLAYING'), findsOneWidget);
    expect(
      find.byIcon(Icons.auto_stories_rounded),
      findsOneWidget,
      reason: 'no cover file falls back to the stylized placeholder',
    );
    expect(
      find.text('The Great Tale'),
      findsOneWidget,
      reason:
          'book title is the headline when no chapter title is passed; '
          'never duplicated as subtitle',
    );
    expect(find.byKey(const ValueKey('play_disc')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_chip')), findsOneWidget);
    expect(find.byType(NarrationSpeedControl), findsOneWidget);
    expect(find.byType(VoicePill), findsOneWidget);
  });

  testWidgets('queue progress renders the sentence cursor', (tester) async {
    final container = await pumpSheet(tester);
    addTearDown(container.dispose);

    // 4 items: the session builder prepends a chapter-intro item.
    expect(find.text('Sentence 1 of 4'), findsOneWidget);
  });

  testWidgets('settings chip reveals the narration settings panel', (
    tester,
  ) async {
    final container = await pumpSheet(tester);
    addTearDown(container.dispose);

    expect(
      find.byKey(const ValueKey('voice_card')),
      findsNothing,
      reason: 'settings collapsed initially',
    );

    await tester.tap(find.byKey(const ValueKey('settings_chip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('voice_card')), findsOneWidget);
  });

  testWidgets('play disc starts an idle session and flips to pause', (
    tester,
  ) async {
    final container = await pumpSheet(tester);
    addTearDown(container.dispose);

    final engine = container.read(speechEngineProvider);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play_disc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(engine.session, isNotNull);
    expect(
      container.read(narrationStatusProvider).valueOrNull,
      NarrationStatus.playing,
    );
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}
