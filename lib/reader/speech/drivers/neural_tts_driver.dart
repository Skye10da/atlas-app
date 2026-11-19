import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:atlas_tts/atlas_tts.dart' as atlas;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// SpeechDriver implementation backed by the atlas_tts neural core (NTD
/// design doc, M4): VITS synthesis into an internal FIFO consumed by the
/// native playback device, word boundaries derived from the core's text
/// offsets, native pause (device-gated, no re-synthesis), and voice packs
/// resolved from `<docs>/atlas_tts/voices/<pack-id>`.
///
/// This is one of two files in the Speech subsystem that imports atlas_tts
/// directly — everything else talks to [SpeechDriver].
///
/// Capability gating: the neural path activates only when the native core is
/// available, has a working playback device backend, AND an installed voice
/// pack exists (Android/iOS; desktop never activates per NTD scope). Missing
/// any of the three keeps callers on FlutterTtsDriver.
class NeuralTtsDriver implements SpeechDriver {
  NeuralTtsDriver._(this._tts, {String? packDirectory, bool ownsSession = true})
    : _packDirOverride = packDirectory,
      _ownsSession = ownsSession {
    _sub = _tts.events.listen(_onTtsEvent);
  }

  /// Wraps an already-initialized session. Visible for tests: the app path
  /// goes through [tryCreate], which owns session initialization. An
  /// injected session is a guest — dispose() stops render/playback but
  /// never tears the native session down.
  @visibleForTesting
  static NeuralTtsDriver session(atlas.AtlasTts tts, {String? packDirectory}) =>
      NeuralTtsDriver._(tts, packDirectory: packDirectory, ownsSession: false);

  /// Attempts to create the neural driver. Returns null — and leaves no
  /// state behind — when the platform lacks the native core, a playback
  /// device backend, or an installed voice pack. Callers must fall back to
  /// their platform-TTS driver.
  ///
  /// The pack gate is deliberate (pre-M5): never take narration away from
  /// platform TTS while no pack can exist yet — ATM (Android/iOS speak before
  /// the M5 CDN download manager runs) the neural driver would turn working
  /// narration into SpeakErrors. The core's [AtlasTts.enablePlayback] cannot
  /// know this, so it is probed here.
  static NeuralTtsDriver? tryCreate() {
    if (kIsWeb) return null;
    // NTD scope: Android + iOS first; desktop stays on FlutterTtsDriver.
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    try {
      if (atlas.AtlasTts.initialize() != null) return null;
      final tts = atlas.AtlasTts.instance!;
      // M3 gate: without a compiled-in device backend this answers
      // errInternal — the app then transparently stays on platform TTS.
      if (tts.enablePlayback(true) != atlas.AtlasTtsResult.ok) {
        tts.shutdown();
        return null;
      }
      // Pre-M5 pack gate (see doc comment above).
      if (!packInstalledSync(documentsRoot: documentsRootSync())) {
        tts.shutdown();
        return null;
      }
      return NeuralTtsDriver._(tts);
    } catch (_) {
      // Native lib missing/malformed: degrade to platform TTS.
      atlas.AtlasTts.instance?.shutdown();
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Synchronous pack-presence gate (visible for tests)
  // -------------------------------------------------------------------------
  // path_provider is async and the provider graph constructs the driver
  // synchronously, so the gate probes the platform sandbox layout directly.
  // Everything here is best-effort: ambiguity answers false, i.e. platform
  // TTS keeps narration; nobody guesses at a sandbox they cannot see.

  /// Dispatches per platform to the sync documents-directory derivation.
  @visibleForTesting
  static String? documentsRootSync() {
    try {
      if (Platform.isAndroid) {
        return androidDocumentsRootFromCmdline(_procCmdlineSync());
      }
      if (Platform.isIOS) {
        return iosDocumentsRootFromExecutable(Platform.resolvedExecutable);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _procCmdlineSync() {
    try {
      return File('/proc/self/cmdline').readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  /// Android documents root for the app_flutter convention:
  /// `<docs>/atlas_tts/voices` in [NeuralTtsDriver] must equal
  /// path_provider's getApplicationDocumentsDirectory, which
  /// path_provider_android derives from Context.getDir("flutter", MODE_PRIVATE)
  /// -> /data/user/0/[pkg name]/app_flutter. The package name is process name
  /// on Android, readable from /proc/self/cmdline (NUL-separated, args follow).
  /// Visible for tests (Windows hosts cannot take the Platform.isAndroid
  /// branch).
  @visibleForTesting
  static String? androidDocumentsRootFromCmdline(String? cmdline) {
    if (cmdline == null) return null;
    final pkg = cmdline.split(String.fromCharCode(0)).first.trim();
    if (pkg.isEmpty || !pkg.contains('.')) return null;
    return '/data/user/0/$pkg/app_flutter';
  }

  /// iOS documents root, derived by walking up from
  /// Platform.resolvedExecutable (which lives inside the app bundle) to the
  /// enclosing *.app container, then applying path_provider's
  /// getApplicationDocumentsDirectory convention (container)/Documents.
  /// Visible for tests (Windows hosts cannot take the Platform.isIOS branch).
  @visibleForTesting
  static String? iosDocumentsRootFromExecutable(String? resolvedExecutable) {
    if (resolvedExecutable == null || resolvedExecutable.isEmpty) return null;
    var dir = Directory(resolvedExecutable).parent;
    for (var i = 0; i < 4; i++) {
      if (dir.path.endsWith('.app')) return '${dir.parent.path}/Documents';
      final parent = dir.parent;
      if (parent.path == dir.path) return null; // reached the filesystem root
      dir = parent;
    }
    return null;
  }

  /// True when at least one voice pack directory exists under
  /// `<documentsRoot>/atlas_tts/voices` (same shape as [_discoverPackRoot]).
  /// Visible for tests (Windows hosts cannot take the Platform.isAndroid
  /// branch).
  @visibleForTesting
  static bool packInstalledSync({String? documentsRoot}) {
    if (documentsRoot == null) return false;
    try {
      final voices = Directory('$documentsRoot/atlas_tts/voices');
      if (!voices.existsSync()) return false;
      return voices.listSync().any((e) => e is Directory);
    } catch (_) {
      return false;
    }
  }

  /// Documents root for the M5 pack system's path math. Public wrapper
  /// over the same derivation [documentsRootSync] uses: the provider graph
  /// needs it from production code, not just tests (M5 §3.5).
  static String? documentsRootForPacks() => documentsRootSync();

  /// Upper bound on one utterance's lifecycle (render + play-out). Render is
  /// sentence-sized and the device consumes in real time, so this is orders
  /// of magnitude beyond nominal; it converts a wedged pipeline into a
  /// DriverError so SpeechEngine's recovery can run.
  static const _speakTimeout = Duration(seconds: 120);

  final atlas.AtlasTts _tts;
  final String? _packDirOverride;
  final bool _ownsSession;

  StreamSubscription<atlas.TtsEvent>? _sub;
  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _stateController = StreamController<DriverState>.broadcast();

  DriverState _state = DriverState.ready;

  // Render parameters (configure()).
  double _rate = 1.0;
  double _volume = 1.0;
  String? _selectedVoiceId;

  // Pack loading. load_voice is event-driven (the core loads on its own
  // worker thread and answers with TtsVoiceReady), so speak() awaits
  // _packLoaded first.
  String? _targetPackId;
  String? _loadedPackId;
  Completer<void>? _packLoaded;

  // The in-flight utterance. Request ids start at 1: 0 means "unset" in the
  // core's render_done_id marker, so request id 0 would never receive its
  // CHUNK_DRAINED in playback mode.
  int _nextRequestId = 1;
  int? _currentRequestId;
  String? _currentText;
  List<int>? _byteToCodeUnit; // UTF-8 byte offset → Dart index (+1 sentinels)
  final _pending = <int, Completer<void>>{};

  @override
  Stream<SpeechDriverEvent> get events => _events.stream;

  @override
  DriverState get state => _state;

  @override
  Stream<DriverState> get stateStream => _stateController.stream;

  // -------------------------------------------------------------------------
  // Session + pack plumbing
  // -------------------------------------------------------------------------

  /// VITS speed is `length_scale`; rate > 1 must shrink it (NTD §3.3).
  double get _lengthScale => _rate > 0 ? 1.0 / _rate : 1.0;

  Future<String?> _discoverPackRoot() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory('${docs.path}/atlas_tts/voices');
      if (!root.existsSync()) return null;
      return root.path;
    } catch (_) {
      return null;
    }
  }

  /// Resolves [voiceId] to a pack directory. `voiceId` is the pack folder
  /// name; language-specific pack matching comes with the M5 drift table.
  /// Returns null when no pack is available.
  Future<String?> _resolvePackDir(String? voiceId) async {
    if (_packDirOverride != null) return _packDirOverride;
    final rootPath = await _discoverPackRoot();
    if (rootPath == null) return null;
    final root = Directory(rootPath);
    if (voiceId != null && voiceId.isNotEmpty) {
      final dir = Directory('${root.path}/$voiceId');
      return dir.existsSync() ? dir.path : null;
    }
    // Default pack: first subdirectory (sorted for determinism until the
    // M5 manifest grades them).
    final packs = root.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return packs.isEmpty ? null : packs.first.path;
  }

  // Kept from FlutterTtsDriver: ellipsis runs read terribly through both
  // SAPI and VITS. \u2026 keeps the source ASCII-safe.
  static final _multiEllipsisRegex = RegExp(r'[\u2026]+|\.{3,}');

  String _cleanText(String text) {
    if (!text.contains('\u2026') && !text.contains('...')) return text;
    return text.replaceAll(_multiEllipsisRegex, ', ');
  }

  /// Issues a load_voice for [voiceId] (or the best installed pack) and
  /// returns a future completed by the core's TtsVoiceReady. Concurrent
  /// calls coalesce on the loader completer.
  Future<void> _ensurePackLoaded(String? voiceId) async {
    var packDir = await _resolvePackDir(voiceId);
    if (packDir == null && voiceId != null) {
      // Requested pack is missing (not downloaded / stale persisted id):
      // degrade to the default pack like FlutterTtsDriver degrades to the
      // platform default voice.
      packDir = await _resolvePackDir(null);
    }
    if (packDir == null) {
      throw StateError('no atlas_tts voice pack available');
    }
    if (_loadedPackId == packDir) return Future.value();
    final inFlight = _packLoaded;
    if (inFlight != null && _targetPackId == packDir) return inFlight.future;

    final completer = Completer<void>();
    _packLoaded = completer;
    _targetPackId = packDir;
    final rc = _tts.loadVoice(packDir);
    if (rc != atlas.AtlasTtsResult.ok) {
      _packLoaded = null;
      _targetPackId = null;
      completer.completeError(StateError('atlas_tts load_voice rc=$rc'));
      return completer.future;
    }
    // Safety: if TtsVoiceReady never arrives, speak's own timeout covers
    // it — but keep the loader completer bounded so a failed load cannot
    // wedge follow-up retries either.
    unawaited(
      Future<void>(() async {
        await Future<void>.delayed(const Duration(seconds: 20));
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('atlas_tts voice load timed out ($packDir)'),
          );
        }
      }),
    );
    return completer.future;
  }

  // -------------------------------------------------------------------------
  // Event translation
  // -------------------------------------------------------------------------

  void _setState(DriverState s) {
    _state = s;
    if (_stateController.isClosed) return;
    _stateController.add(s);
  }

  void _addEvent(SpeechDriverEvent e) {
    if (_events.isClosed) return;
    _events.add(e);
  }

  void _onTtsEvent(atlas.TtsEvent e) {
    switch (e) {
      case final atlas.TtsVoiceReady _:
        _loadedPackId = _targetPackId;
        _packLoaded?.complete();
        _packLoaded = null;
        if (_state != DriverState.speaking) _setState(DriverState.ready);
      case final atlas.TtsWordBoundary w:
        final boundary = _translateBoundary(w);
        if (boundary != null) _addEvent(boundary);
      case final atlas.TtsAudioQueued _:
        // Progress bookkeeping the engine does not consume yet; word pacing
        // stays render-side until per-word durations surface (NTD §3.3).
        break;
      case final atlas.TtsChunkDrained d:
        final completer = _pending.remove(d.requestId);
        if (completer != null) {
          completer.complete();
          _setState(DriverState.ready);
          _addEvent(const DriverCompleted());
        }
      case final atlas.TtsError err:
        final completer = _pending.remove(err.requestId);
        _setState(DriverState.error);
        _addEvent(DriverError('atlas_tts error code=${err.code}'));
        if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  DriverWordBoundary? _translateBoundary(atlas.TtsWordBoundary w) {
    final text = _currentText;
    final requestId = _currentRequestId;
    if (text == null || w.requestId != requestId) return null;
    final map = _byteToCodeUnit;
    if (map == null || w.offset >= map.length) return null;
    final start = _resolveIndex(map, w.offset);
    final end = _resolveIndex(map, w.offset + w.length, fallback: text.length);
    if (end <= start) return null;
    return DriverWordBoundary(start, end, text.substring(start, end));
  }

  /// UTF-8 byte offset → Dart string index. The core reports byte offsets
  /// into the UTF-8 encoding it received; highlighting operates on Dart
  /// indices (same conversion shape flutter_tts avoids by indexing native
  /// UTF-16 instead).
  static List<int> _buildByteMap(String text) {
    final bytes = utf8.encode(text);
    final map = List<int>.filled(bytes.length + 1, -1);
    var bi = 0;
    var i = 0;
    while (i < text.length) {
      map[bi] = i;
      final c = text.codeUnitAt(i);
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
        bi += 4; // surrogate pair → 4 UTF-8 bytes; skip the low half
        i += 2;
      } else if (c < 0x80) {
        bi += 1;
        i += 1;
      } else if (c < 0x800) {
        bi += 2;
        i += 1;
      } else {
        bi += 3;
        i += 1;
      }
    }
    map[bytes.length] = text.length;
    return map;
  }

  static int _resolveIndex(List<int> map, int byteOffset, {int fallback = -1}) {
    if (byteOffset >= map.length) return fallback;
    var i = byteOffset;
    while (i < map.length && map[i] == -1) {
      i++; // mid-pair byte boundary: next character start
    }
    return i >= map.length ? fallback : map[i];
  }

  // -------------------------------------------------------------------------
  // SpeechDriver
  // -------------------------------------------------------------------------

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
    String? language,
  }) async {
    _rate = rate > 0 ? rate : 1.0;
    // Pitch: VITS has no pitch axis (NTD §3.3); noise_scale variance tuning
    // is the v1 stand-in and intentionally coarse.
    _volume = volume;
    if (voiceId != null) _selectedVoiceId = voiceId;
    final wanted = _selectedVoiceId;
    if (wanted != null && wanted != _loadedPackId) {
      try {
        await _ensurePackLoaded(wanted);
      } catch (e) {
        _setState(DriverState.error);
        _addEvent(DriverError('atlas_tts voice load failed: $e'));
      }
    }
  }

  @override
  Future<void> warmup(SpeechItem item) async {
    try {
      await _ensurePackLoaded(_selectedVoiceId);
    } catch (_) {}
  }

  @override
  Future<void> speak(SpeechItem item) async {
    final text = _cleanText(item.text);
    if (text.trim().isEmpty) {
      _addEvent(const DriverCompleted());
      return;
    }
    try {
      await _ensurePackLoaded(_selectedVoiceId);
    } catch (e) {
      _setState(DriverState.error);
      _addEvent(DriverError('atlas_tts voice unavailable: $e'));
      return;
    }

    final requestId = _nextRequestId++;
    final completer = Completer<void>();
    _pending[requestId] = completer;
    _currentRequestId = requestId;
    _currentText = text;
    _byteToCodeUnit = _buildByteMap(text);

    _setState(DriverState.speaking);
    _addEvent(const DriverStarted());

    // The core renders asynchronously; rc only validates the enqueue.
    final rc = _tts.speak(
      text,
      lengthScale: _lengthScale,
      volume: _volume.clamp(0.0, 1.0),
      requestId: requestId,
    );
    if (rc != atlas.AtlasTtsResult.ok) {
      _pending.remove(requestId);
      if (_currentRequestId == requestId) {
        _currentRequestId = null;
        _currentText = null;
      }
      _setState(DriverState.error);
      _addEvent(DriverError('atlas_tts speak rc=$rc'));
      return;
    }

    await completer.future.timeout(
      _speakTimeout,
      onTimeout: () {
        final pending = _pending.remove(requestId);
        if (pending != null && !pending.isCompleted) pending.complete();
        _tts.stop(); // wedged device/render: cancel before the next item
        _setState(DriverState.error);
        _addEvent(DriverError('atlas_tts speak timed out (req=$requestId)'));
      },
    );
    if (_currentRequestId == requestId) {
      _currentRequestId = null;
      _currentText = null;
    }
  }

  @override
  Future<List<int>?> synthesizeToBytes(SpeechItem item) async {
    // Rendering to bytes for offline caching comes with the M5 cache
    // pipeline; the driver gracefully degrades to warmup-mode gaps until
    // then (same contract shape as FlutterTtsDriver).
    return null;
  }

  @override
  Future<void> pause() async {
    if (_state == DriverState.speaking) {
      _tts.pause(true); // device gate: buffers hold, no re-synthesis
      _setState(DriverState.paused);
      _addEvent(const DriverPaused());
    }
  }

  @override
  Future<void> resume(SpeechItem item) async {
    _tts.pause(false);
    _setState(DriverState.speaking);
    _addEvent(const DriverResumed());
  }

  @override
  Future<void> stop() async {
    // Resolve every pending speak first: stop is legal at any point, and the
    // core's stop() with playback on may suppress the drained event that
    // would otherwise complete them.
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete();
    }
    _pending.clear();
    _currentRequestId = null;
    _currentText = null;
    try {
      _tts.pause(false);
      _tts.stop();
    } catch (_) {}
    _setState(DriverState.stopped);
  }

  @override
  Future<List<VoiceDescriptor>> listVoices() async {
    final rootPath = await _discoverPackRoot();
    if (rootPath == null) return const [];
    final root = Directory(rootPath);
    if (!root.existsSync()) return const [];
    return root
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .map(
          (name) => VoiceDescriptor(
            id: name,
            language: name.split('-').take(2).join('-').toLowerCase(),
            locale: 'en-US', // placeholder until pack manifests (M5)
          ),
        )
        .toList();
  }

  @override
  Future<void> restart() async {
    // ASA §12 recovery: paper over a wedged pipeline. Session re-init is
    // unnecessary for transient device hiccups; a full stop + pack reload
    // covers both render-worker and device-thread restarts.
    try {
      _tts.pause(false);
      _tts.stop();
    } catch (_) {}
    if (_pending.isNotEmpty) {
      for (final completer in _pending.values) {
        if (!completer.isCompleted) completer.complete();
      }
      _pending.clear();
    }
    final packId = _targetPackId;
    if (packId != null) {
      try {
        await _ensurePackLoaded(packId);
      } catch (_) {}
    }
    _setState(DriverState.ready);
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete();
    }
    _pending.clear();
    try {
      _tts.pause(false);
      _tts.stop();
      if (_ownsSession) {
        _tts.unloadVoice();
        _tts.enablePlayback(false);
        _tts.shutdown();
      }
    } catch (_) {}
    if (!_events.isClosed) await _events.close();
    if (!_stateController.isClosed) await _stateController.close();
  }
}
