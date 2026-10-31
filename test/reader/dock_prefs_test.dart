import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/presentation/providers/dock_prefs_provider.dart';

void main() {
  group('ReaderDockPrefs model', () {
    test('normalizes actions: always ends with more, no duplicates', () {
      const prefs = ReaderDockPrefs(
        actions: [
          ReaderDockAction.aa,
          ReaderDockAction.contents,
          ReaderDockAction.aa,
        ],
      );
      final out = prefs.normalizedActions();
      expect(out, [
        ReaderDockAction.aa,
        ReaderDockAction.contents,
        ReaderDockAction.more,
      ]);
      expect(out.last, ReaderDockAction.more);
    });

    test('empty actions falls back to defaults plus more', () {
      const empty = ReaderDockPrefs(actions: []);
      expect(empty.normalizedActions(), [
        ...ReaderDockPrefs.defaultActions,
        ReaderDockAction.more,
      ]);
    });

    test('json round trip preserves override values only', () {
      const original = ReaderDockPrefs(
        actions: [
          ReaderDockAction.search,
          ReaderDockAction.contents,
          ReaderDockAction.more,
        ],
        spine: ReaderSpineVisibility(clock: false, battery: false),
        autoScrollSpeed: 3.5,
      );
      final json = original.toJson();
      final restored = ReaderDockPrefs.fromJson(json);
      expect(restored.actions, [...original.actions]);
      expect(restored.spine.clock, isFalse);
      expect(restored.spine.battery, isFalse);
      expect(restored.spine.chapterProgress, isTrue);
      expect(restored.autoScrollSpeed, closeTo(3.5, 0.001));
    });

    test('corrupted action names are dropped; autoScrollSpeed clamps', () {
      final restored = ReaderDockPrefs.fromJson({
        'actions': ['search', 'bogus', 42],
        'autoScrollSpeed': 900,
      });
      expect(restored.actions, [ReaderDockAction.search]);
      expect(restored.autoScrollSpeed, 6.0);
    });

    test('defaults match the pre-customization dock', () {
      const prefs = ReaderDockPrefs();
      expect(prefs.actions, [
        ReaderDockAction.contents,
        ReaderDockAction.annotations,
        ReaderDockAction.listen,
        ReaderDockAction.aa,
      ]);
      expect(prefs.spine.allOn, isTrue);
      expect(prefs.autoScrollSpeed, 2.0);
    });
  });

  group('ReaderDockPrefsRepository', () {
    test('returns defaults when nothing was saved', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ReaderDockPrefsRepository();
      final prefs = await repo.load();
      expect(prefs.actions, ReaderDockPrefs.defaultActions);
      expect(prefs.spine.allOn, isTrue);
      expect(prefs.autoScrollSpeed, 2.0);
    });

    test('save / load round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ReaderDockPrefsRepository();
      const saved = ReaderDockPrefs(
        actions: [
          ReaderDockAction.listen,
          ReaderDockAction.aa,
          ReaderDockAction.flow,
          ReaderDockAction.more,
        ],
        spine: ReaderSpineVisibility(chapterProgress: false),
        autoScrollSpeed: 1.5,
      );
      await repo.save(saved);
      final loaded = await repo.load();
      expect(loaded.actions, [...saved.actions]);
      expect(loaded.spine.chapterProgress, isFalse);
      expect(loaded.autoScrollSpeed,	closeTo(1.5, 0.001));
    });

    test('corrupt json falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        'reader_dock_prefs': '{not json',
      });
      final repo = ReaderDockPrefsRepository();
      final prefs = await repo.load();
      expect(prefs.actions, ReaderDockPrefs.defaultActions);
    });
  });

  group('ReaderDockPrefsNotifier', () {
    test('spliceAction appends then removes, never duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ReaderDockPrefsNotifier(ReaderDockPrefsRepository());
      await Future<void>.delayed(Duration.zero);

      notifier.spliceAction(ReaderDockAction.search, include: true);
      expect(notifier.state.actions, contains(ReaderDockAction.search));
      notifier.spliceAction(ReaderDockAction.search, include: true);
      expect(
        notifier.state.actions.where((a) => a == ReaderDockAction.search),
        hasLength(1),
      );
      notifier.spliceAction(ReaderDockAction.search, include: false);
      expect(notifier.state.actions, isNot(contains(ReaderDockAction.search)));
      // hide a default action works the same way
      notifier.spliceAction(ReaderDockAction.annotations, include: false);
      expect(
        notifier.state.actions,
        isNot(contains(ReaderDockAction.annotations)),
      );
    });

    test('autoScrollSpeed clamps into the engine range', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ReaderDockPrefsNotifier(ReaderDockPrefsRepository());
      await Future<void>.delayed(Duration.zero);
      notifier.setAutoScrollSpeed(99);
      expect(notifier.state.autoScrollSpeed, 6.0);
      notifier.setAutoScrollSpeed(-5);
      expect(notifier.state.autoScrollSpeed, 1.0);
    });

    test('reset restores everything', () async {
      SharedPreferences.setMockInitialValues({});
      final store = <String, String>{};
      SharedPreferences.setMockInitialValues(store);
      final n = ReaderDockPrefsNotifier(ReaderDockPrefsRepository());
      await Future<void>.delayed(Duration.zero);

      n.setAutoScrollSpeed(4.0);
      n.spliceAction(ReaderDockAction.search, include: true);
      n.setSpine(
        const ReaderSpineVisibility(clock: false, battery: false),
      );
      n.reset();
      expect(n.state.autoScrollSpeed, 2.0);
      expect(n.state.actions, ReaderDockPrefs.defaultActions);
      expect(n.state.spine.allOn, isTrue);

      // The reset value is already flushed to storage (no debounce).
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('reader_dock_prefs');
      expect(raw, isNotNull);
      final flushed = ReaderDockPrefs.fromJson(
        (jsonDecode(raw!) as Map).cast<String, dynamic>(),
      );
      expect(flushed.autoScrollSpeed, 2.0);
    });
  });
}

