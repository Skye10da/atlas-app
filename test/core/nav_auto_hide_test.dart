import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/organisms/atlas_glass_nav_bar.dart';
import 'package:atlas_app/core/design_system/organisms/nav_reveal_button.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_session_builder.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// Shell-level tests for the nav-chrome auto-hide:
/// pill hides on scroll-down, returns on scroll-up / reveal bead, horizontal
/// carousels never trigger it, and narration docks the mini player into the
/// nav position (with nav destinations). The desktop sidebar deliberately
/// does NOT auto-hide — it only collapses via its own button.

class _FakeDriver implements SpeechDriver {
  final _state = StreamController<DriverState>.broadcast();
  final _events = StreamController<SpeechDriverEvent>.broadcast();
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
  Future<void> restart() async {}
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

/// Scrollable tab content: a horizontal carousel (which must NOT hide the
/// nav) above a vertical list (which must).
class _TabContent extends StatelessWidget {
  const _TabContent(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 100,
            child: ListView.builder(
              key: ValueKey('carousel-$label'),
              scrollDirection: Axis.horizontal,
              itemCount: 40,
              itemBuilder: (context, i) =>
                  SizedBox(width: 80, child: Center(child: Text('$label h$i'))),
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: ValueKey('list-$label'),
              itemCount: 80,
              itemBuilder: (context, i) =>
                  ListTile(title: Text('$label item $i')),
            ),
          ),
        ],
      ),
    );
  }
}

GoRouter _router() {
  StatefulShellBranch tab(String path, String label) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => _TabContent(label))],
  );
  return GoRouter(
    initialLocation: '/library',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          tab('/library', 'Library'),
          tab('/find', 'Find new'),
          tab('/saved', 'Saved'),
          tab('/settings', 'Settings'),
        ],
      ),
    ],
  );
}

ProviderContainer _container({SpeechEngine? engine}) {
  final driver = _FakeDriver();
  final testEngine = engine ?? SpeechEngine(driver, _NoopRecoveryStore());
  return ProviderContainer(
    overrides: [
      speechDriverProvider.overrideWithValue(driver),
      speechEngineProvider.overrideWithValue(testEngine),
    ],
  );
}

double _barTop(WidgetTester tester) =>
    tester.getRect(find.byType(AtlasGlassNavBar)).top;

/// The reveal chrome's current opacity (it stays in the tree, fading via
/// [AnimatedOpacity], so presence ≠ visibility). Handles both variants —
/// the lone bead and the narration transport cluster.
double _revealOpacity(WidgetTester tester) {
  final bead = find.byType(NavRevealButton);
  final cluster = find.byType(NavRevealCluster);
  final target = bead.evaluate().isNotEmpty ? bead : cluster;
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: target, matching: find.byType(AnimatedOpacity)),
      )
      .opacity;
}

double _sidebarWidth(WidgetTester tester) =>
    tester.getRect(find.byType(GlassCapsule).first).width;

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Loads a one-chapter session, starts playback and settles the shell —
/// shared setup for the narration-active shell tests. Returns the engine
/// and its overridden provider container.
Future<(SpeechEngine, ProviderContainer)> _startNarration(
  WidgetTester tester,
) async {
  final session = const SpeechSessionBuilder().build(
    bookId: 'b1',
    chapter: const ChapterEntity(
      id: 'c1',
      bookId: 'b1',
      title: 'Chapter 1',
      index: 0,
      contentPath: '',
    ),
    content: 'First sentence of narration. Second sentence of narration.',
    language: 'en',
    settings: const NarrationSettings(),
    bookTitle: 'Test Book',
  );
  final driver = _FakeDriver();
  final engine = SpeechEngine(driver, _NoopRecoveryStore());
  await engine.loadSession(session);
  final container = _container(engine: engine);
  await _pump(tester, container);
  await engine.start();
  await tester.pump();
  await tester.pumpAndSettle();
  return (engine, container);
}

void main() {
  testWidgets('nav pill hides on scroll down and returns on scroll up', (
    tester,
  ) async {
    final container = _container();
    await _pump(tester, container);

    final restingTop = _barTop(tester);
    expect(restingTop, lessThan(844 - 60), reason: 'pill rests at the bottom');

    await tester.drag(
      find.byKey(const ValueKey('list-Library')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      _barTop(tester),
      greaterThan(844 - 10),
      reason: 'pill slid off-screen after scrolling down',
    );
    expect(find.byType(NavRevealButton), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('list-Library')),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(
      _barTop(tester),
      lessThanOrEqualTo(restingTop + 1),
      reason: 'scrolling up reveals the pill again',
    );
  });

  testWidgets('tapping the reveal bead re-shows the hidden pill', (
    tester,
  ) async {
    final container = _container();
    await _pump(tester, container);

    await tester.drag(
      find.byKey(const ValueKey('list-Library')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(_barTop(tester), greaterThan(844 - 10));

    await tester.tap(find.byType(NavRevealButton));
    await tester.pumpAndSettle();
    expect(
      _barTop(tester),
      lessThan(844 - 60),
      reason: 'reveal bead brings the pill back',
    );
  });

  testWidgets('horizontal carousel scrolling does not hide the pill', (
    tester,
  ) async {
    final container = _container();
    await _pump(tester, container);

    await tester.drag(
      find.byKey(const ValueKey('carousel-Library')),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    expect(
      _barTop(tester),
      lessThan(844 - 60),
      reason: 'horizontal scroll must not trigger the vertical auto-hide',
    );
  });

  testWidgets(
    'narration docks the mini player (with nav strip) and hides the pill; '
    'stopping restores the pill',
    (tester) async {
      final session = const SpeechSessionBuilder().build(
        bookId: 'b1',
        chapter: const ChapterEntity(
          id: 'c1',
          bookId: 'b1',
          title: 'Chapter 1',
          index: 0,
          contentPath: '',
        ),
        content: 'First sentence of narration. Second sentence of narration.',
        language: 'en',
        settings: const NarrationSettings(),
        bookTitle: 'Test Book',
      );
      final driver = _FakeDriver();
      final engine = SpeechEngine(driver, _NoopRecoveryStore());
      await engine.loadSession(session);
      final container = _container(engine: engine);
      await _pump(tester, container);

      // Nothing docked before playback starts.
      expect(_barTop(tester), lessThan(844 - 60));

      await engine.start();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        _barTop(tester),
        greaterThan(844 - 10),
        reason: 'pill pinned hidden while narrating',
      );
      expect(
        _revealOpacity(tester),
        0.0,
        reason: 'the docked mini player carries navigation instead',
      );
      expect(find.byType(NarrationMiniPlayer), findsOneWidget);

      // Tap a docked nav destination → branch switch.
      await tester.tap(
        find.descendant(
          of: find.byType(NarrationMiniPlayer),
          matching: find.text('Saved'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Saved item 0'),
        findsOneWidget,
        reason: 'docked nav strip switches to the Saved branch',
      );

      await engine.stop();
      await tester.pumpAndSettle();
      expect(
        _barTop(tester),
        lessThan(844 - 60),
        reason: 'narration stopped → pill returns',
      );
    },
  );

  testWidgets(
    'while narrating, the docked player scroll-hides and the transport '
    'cluster pauses and stops playback',
    (tester) async {
      final (_, container) = await _startNarration(tester);

      final playerTop = tester.getRect(find.byType(NarrationMiniPlayer)).top;
      expect(playerTop, lessThan(844 - 60), reason: 'player docked at bottom');

      await tester.drag(
        find.byKey(const ValueKey('list-Library')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(NarrationMiniPlayer)).top,
        greaterThan(844),
        reason: 'docked player slid off-screen with the scroll',
      );
      expect(
        find.byType(NavRevealCluster),
        findsOneWidget,
        reason: 'the transport cluster stands in for the hidden player',
      );

      // Pause via the cluster, then resume.
      await tester.tap(find.byTooltip('Pause narration'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Resume narration'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume narration'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pause narration'), findsOneWidget);

      // Stop ends the session: cluster reverts to the plain bead and the
      // mini player collapses.
      await tester.tap(find.byTooltip('Stop narration'));
      await tester.pumpAndSettle();
      expect(find.byType(NavRevealCluster), findsNothing);
      expect(
        container.read(narrationStatusProvider).valueOrNull,
        NarrationStatus.idle,
        reason: 'stopping tears the session down',
      );
    },
  );

  testWidgets('NavRevealCluster reflects playing state and fires callbacks', (
    tester,
  ) async {
    var reveals = 0;
    var toggles = 0;
    var stops = 0;
    Widget host(bool playing) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: NavRevealCluster(
            playing: playing,
            onReveal: () => reveals++,
            onToggle: () => toggles++,
            onStop: () => stops++,
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(true));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Show player'));
    await tester.tap(find.byTooltip('Pause narration'));
    await tester.tap(find.byTooltip('Stop narration'));
    expect(reveals, 1);
    expect(toggles, 1);
    expect(stops, 1);

    await tester.pumpWidget(host(false));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byTooltip('Resume narration'), findsOneWidget);
  });

  testWidgets('desktop sidebar ignores scroll and collapses via its button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    final container = _container();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _sidebarWidth(tester),
      greaterThan(200),
      reason: 'big-desktop sidebar starts expanded',
    );

    // Scrolling never moves the sidebar — desktop chrome is persistent.
    await tester.drag(
      find.byKey(const ValueKey('list-Library')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      _sidebarWidth(tester),
      greaterThan(200),
      reason: 'scrolling down does not collapse the desktop sidebar',
    );

    // Only the sidebar's own toggle changes its width.
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(
      _sidebarWidth(tester),
      lessThan(100),
      reason: 'the collapse button still works',
    );

    // When collapsed the toggle is the app icon itself (no tooltip).
    await tester.tap(find.image(const AssetImage('assets/icon.png')));
    await tester.pumpAndSettle();
    expect(
      _sidebarWidth(tester),
      greaterThan(200),
      reason: 'the collapse button re-expands the sidebar',
    );
  });
}
