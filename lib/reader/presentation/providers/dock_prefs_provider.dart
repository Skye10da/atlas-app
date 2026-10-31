import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An interactive action that can appear in the reader dock's capsule row.
///
/// [more] is always present (last): it is the overflow for everything that is
/// not promoted into the capsule. The other entries can be hidden, or promoted
/// out of the More menu (search, atlas, flow, redownload).
enum ReaderDockAction {
  contents,
  annotations,
  listen,
  aa,
  more,
  flow,
  search,
  atlas,
  redownload;

  static ReaderDockAction? tryParse(String raw) {
    return switch (raw) {
      'contents' => contents,
      'annotations' => annotations,
      'listen' => listen,
      'aa' => aa,
      'more' => more,
      'flow' => flow,
      'search' => search,
      'atlas' => atlas,
      'redownload' => redownload,
      _ => null,
    };
  }

  String get jsonName => name;
}

/// Which indicators the dock's chapter strip shows.
class ReaderSpineVisibility {
  const ReaderSpineVisibility({
    this.chapterProgress = true,
    this.clock = true,
    this.battery = true,
  });

  final bool chapterProgress;
  final bool clock;
  final bool battery;

  ReaderSpineVisibility copyWith({
    bool? chapterProgress,
    bool? clock,
    bool? battery,
  }) {
    return ReaderSpineVisibility(
      chapterProgress: chapterProgress ?? this.chapterProgress,
      clock: clock ?? this.clock,
      battery: battery ?? this.battery,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterProgress': chapterProgress,
    'clock': clock,
    'battery': battery,
  };

  static ReaderSpineVisibility fromJson(Map<String, dynamic> json) {
    return ReaderSpineVisibility(
      chapterProgress: json['chapterProgress'] as bool? ?? true,
      clock: json['clock'] as bool? ?? true,
      battery: json['battery'] as bool? ?? true,
    );
  }

  bool get allOn => chapterProgress && clock && battery;
  bool get allOff => !chapterProgress && !clock && !battery;
}

/// User-level dock customization: which actions the capsule row carries (and
/// in which order), what the chapter strip shows, and the auto-scroll start
/// speed. Global (not per-book), applied everywhere the dock mounts.
class ReaderDockPrefs {
  const ReaderDockPrefs({
    this.actions = defaultActions,
    this.spine = const ReaderSpineVisibility(),
    this.autoScrollSpeed = 2.0,
  });

  static const defaultActions = <ReaderDockAction>[
    ReaderDockAction.contents,
    ReaderDockAction.annotations,
    ReaderDockAction.listen,
    ReaderDockAction.aa,
  ];

  /// Ordered capsule actions. [ReaderDockAction.more] is always shown last,
  /// regardless of this list.
  final List<ReaderDockAction> actions;
  final ReaderSpineVisibility spine;

  /// Auto-scroll speed in engine units (px per 50 ms tick), 1–6.
  /// Displayed as `${(speed * 20).round()} px/s`.
  final double autoScrollSpeed;

  /// The [actions] that will actually render, normalized: [more] last,
  /// no duplicates, always non-empty.
  List<ReaderDockAction> normalizedActions() {
    final seen = <ReaderDockAction>{};
    final out = <ReaderDockAction>[];
    void add(ReaderDockAction a) {
      if (a == ReaderDockAction.more || !seen.add(a)) return;
      out.add(a);
    }

    for (final a in actions) {
      add(a);
    }
    if (out.isEmpty) out.addAll(defaultActions);
    out.add(ReaderDockAction.more);
    return out;
  }

  ReaderDockPrefs copyWith({
    List<ReaderDockAction>? actions,
    ReaderSpineVisibility? spine,
    double? autoScrollSpeed,
  }) {
    return ReaderDockPrefs(
      actions: actions ?? this.actions,
      spine: spine ?? this.spine,
      autoScrollSpeed:
          autoScrollSpeed?.clamp(1.0, 6.0) ?? this.autoScrollSpeed,
    );
  }

  Map<String, dynamic> toJson() => {
    'actions': actions.map((a) => a.jsonName).toList(),
    'spine': spine.toJson(),
    'autoScrollSpeed': autoScrollSpeed,
  };

  static ReaderDockPrefs fromJson(Map<String, dynamic> json) {
    final names = (json['actions'] as List? ?? [])
        .whereType<String>()
        .map(ReaderDockAction.tryParse)
        .whereType<ReaderDockAction>()
        .toList();
    return ReaderDockPrefs(
      actions: names,
      spine: json['spine'] is Map
          ? ReaderSpineVisibility.fromJson(
              (json['spine'] as Map).cast<String, dynamic>(),
            )
          : const ReaderSpineVisibility(),
      autoScrollSpeed: json['autoScrollSpeed'] is num
          ? (json['autoScrollSpeed'] as num).toDouble().clamp(1.0, 6.0)
          : 2.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderDockPrefs &&
      _actionsEqual(other.actions, actions) &&
      other.spine == spine &&
      other.autoScrollSpeed == autoScrollSpeed;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(actions.map((a) => a.index)),
    spine,
    autoScrollSpeed,
  );
}

bool _actionsEqual(List<ReaderDockAction> a, List<ReaderDockAction> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class ReaderDockPrefsRepository {
  static const _key = 'reader_dock_prefs';

  Future<ReaderDockPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const ReaderDockPrefs();
    try {
      return ReaderDockPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReaderDockPrefs();
    }
  }

  Future<void> save(ReaderDockPrefs prefs) async {
    final prefsInstance = await SharedPreferences.getInstance();
    await prefsInstance.setString(_key, jsonEncode(prefs.toJson()));
  }
}

/// Loads saved prefs on first read (before that, defaults apply so the dock
/// renders immediately), then keeps state and disk in sync.
class ReaderDockPrefsNotifier extends StateNotifier<ReaderDockPrefs> {
  ReaderDockPrefsNotifier(this._repository) : super(const ReaderDockPrefs()) {
    unawaited(_load());
  }

  final ReaderDockPrefsRepository _repository;

  Future<void> _load() async {
    final loaded = await _repository.load();
    if (!mounted) return;
    // A change can legally land between construction and the load completing
    // (the dock renders synchronously off defaults; splice comes from a
    // Customize sheet microseconds later). Loaded values only apply when the
    // state is still pristine, so user edits are never silently reverted.
    if (state != const ReaderDockPrefs()) return;
    state = loaded;
  }

  void update(ReaderDockPrefs Function(ReaderDockPrefs) change) {
    state = change(state);
    unawaited(_repository.save(state));
  }

  void setActions(List<ReaderDockAction> actions) =>
      update((p) => p.copyWith(actions: actions));

  /// Includes / removes [action] from the capsule (appended before [more]).
  void spliceAction(ReaderDockAction action, {required bool include}) =>
      update(
        (p) => p.copyWith(
          actions: include
              ? [
                  ...p.actions,
                  if (!p.actions.contains(action)) action,
                ]
              : p.actions.where((a) => a != action).toList(),
        ),
      );

  void setSpine(ReaderSpineVisibility spine) =>
      update((p) => p.copyWith(spine: spine));

  void setAutoScrollSpeed(double speed) =>
      update((p) => p.copyWith(autoScrollSpeed: speed));

  void reset() => update((_) => const ReaderDockPrefs());
}

/// Kept alive: the prefs must survive while the dock unmounts (chrome hidden)
/// and while sheets open, so the state doesn't reset mid-session.
final readerDockPrefsProvider =
    StateNotifierProvider<ReaderDockPrefsNotifier, ReaderDockPrefs>((ref) {
  return ReaderDockPrefsNotifier(ReaderDockPrefsRepository());
});
