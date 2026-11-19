import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/core/design_system/organisms/atlas_glass_nav_bar.dart'
    show AtlasNavItem;
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

void main() {
  testWidgets(
    'NarrationMiniPlayer renders cover thumbnail and navigates back to reader on cover tap',
    (tester) async {
      const builder = SpeechSessionBuilder();
      const bookId = 'test_book_123';
      const chapterId = 'chapter_456';
      const content =
          'First sentence of novel narration. Second sentence of narration.';

      const chapter = ChapterEntity(
        id: chapterId,
        bookId: bookId,
        title: 'Chapter 10: The Beginning',
        index: 9,
        contentPath: '',
      );

      final session = builder.build(
        bookId: bookId,
        chapter: chapter,
        content: content,
        language: 'en',
        settings: const NarrationSettings(),
        coverPath: '/test/cover.png',
        bookTitle: 'The Great Tale',
        author: 'Author Name',
      );

      String? navigatedRoute;
      final router = GoRouter(
        initialLocation: '/library',
        routes: [
          GoRoute(
            path: '/library',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Library Screen')),
              bottomNavigationBar: NarrationMiniPlayer(),
            ),
          ),
          GoRoute(
            path: '/reader/:bookId',
            builder: (context, state) {
              navigatedRoute = state.uri.toString();
              return Scaffold(
                body: Center(
                  child: Text('Reader: ${state.pathParameters['bookId']}'),
                ),
              );
            },
          ),
        ],
      );

      final fakeDriver = _FakeDriver();
      final recoveryStore = _NoopRecoveryStore();
      final testEngine = SpeechEngine(fakeDriver, recoveryStore);
      await testEngine.loadSession(session);

      final container = ProviderContainer(
        overrides: [
          speechDriverProvider.overrideWithValue(fakeDriver),
          speechRecoveryStoreProvider.overrideWithValue(recoveryStore),
          speechEngineProvider.overrideWithValue(testEngine),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      // Start playback
      await testEngine.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Mini player should now be visible with tooltip and lyrics
      expect(find.byTooltip('Go to The Great Tale'), findsOneWidget);

      // Tap the cover thumbnail
      await tester.tap(find.byTooltip('Go to The Great Tale'));
      await tester.pumpAndSettle();

      // Verify navigation occurred to the exact chapter
      expect(
        navigatedRoute,
        equals('/reader/test_book_123?chapterId=chapter_456'),
      );
      expect(find.text('Reader: test_book_123'), findsOneWidget);

      await testEngine.stop();
    },
  );

  testWidgets(
    'docked mode renders the nav destination strip and taps through',
    (tester) async {
      const builder = SpeechSessionBuilder();
      final session = builder.build(
        bookId: 'test_book_123',
        chapter: const ChapterEntity(
          id: 'chapter_456',
          bookId: 'test_book_123',
          title: 'Chapter 10: The Beginning',
          index: 9,
          contentPath: '',
        ),
        content:
            'First sentence of novel narration. Second sentence of narration.',
        language: 'en',
        settings: const NarrationSettings(),
        bookTitle: 'The Great Tale',
      );

      final fakeDriver = _FakeDriver();
      final recoveryStore = _NoopRecoveryStore();
      final testEngine = SpeechEngine(fakeDriver, recoveryStore);
      await testEngine.loadSession(session);

      final container = ProviderContainer(
        overrides: [
          speechDriverProvider.overrideWithValue(fakeDriver),
          speechRecoveryStoreProvider.overrideWithValue(recoveryStore),
          speechEngineProvider.overrideWithValue(testEngine),
        ],
      );

      final selected = <int>[];
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: const SizedBox.shrink(),
              bottomNavigationBar: NarrationMiniPlayer(
                docked: true,
                navDestinations: const [
                  AtlasNavItem(
                    icon: Icons.auto_stories_outlined,
                    activeIcon: Icons.auto_stories_rounded,
                    label: 'Library',
                  ),
                  AtlasNavItem(
                    icon: Icons.tune_outlined,
                    activeIcon: Icons.tune_rounded,
                    label: 'Settings',
                  ),
                ],
                currentNavIndex: 0,
                onNavSelect: selected.add,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await testEngine.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byTooltip('Settings'),
        findsOneWidget,
        reason: 'docked mode renders the nav destination strip',
      );
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(selected, [
        1,
      ], reason: 'docked nav strip forwards the tapped destination index');

      await testEngine.stop();
    },
  );
}
