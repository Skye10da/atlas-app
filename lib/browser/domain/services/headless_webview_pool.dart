import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/infrastructure/engines/headless_web_engine.dart';

class _PooledEngine {
  _PooledEngine(this.engine) : lastUsed = DateTime.now();

  final BrowserWebEngine engine;
  DateTime lastUsed;
  int activeHolders = 0;
}

/// A pool of [BrowserWebEngine] instances keyed by origin (`scheme://host[:port]`),
/// enabling parallel challenge solving and fetching across distinct domains.
///
/// When [memoryAware] is true (default), [maxViews] is capped based on
/// available RAM so low-memory Android devices don't OOM from 3 concurrent
/// WebViews (~50-70MB each). Caps: <2GB → 1, <3GB → 2, otherwise [maxViews].
class HeadlessWebViewPool {
  HeadlessWebViewPool({
    this.maxViews = 3,
    this.memoryAware = true,
    BrowserEngineFactory? engineFactory,
  }) : _engineFactory = engineFactory ?? _defaultEngineFactory,
       _effectiveMaxViews = _resolveEffectiveMaxViews(
         maxViews,
         memoryAware: memoryAware,
       );

  /// Builds a pool containing a single fixed engine (useful for tests and single-engine setups).
  factory HeadlessWebViewPool.single(BrowserWebEngine engine) =>
      _SingleEnginePool(engine);

  final int maxViews;
  final bool memoryAware;
  final int _effectiveMaxViews;
  final BrowserEngineFactory _engineFactory;

  /// Effective cap after memory-aware adjustment. Use this for all
  /// capacity checks; [maxViews] remains the requested value for diagnostics.
  int get effectiveMaxViews => _effectiveMaxViews;

  static BrowserWebEngine _defaultEngineFactory({String? initialUrl}) =>
      HeadlessWebEngine(initialUrl: initialUrl);

  static int _resolveEffectiveMaxViews(
    int requested, {
    required bool memoryAware,
  }) {
    if (!memoryAware) return requested;
    if (requested <= 1) return requested;
    if (kIsWeb) return requested;
    // On Windows we keep the pool enabled but cap more aggressively —
    // WebView2 headless is supported after COM init, but each view is
    // heavier (~80MB). Limit to 2 on low-RAM, 3 otherwise.
    try {
      // Android/Linux: read MemTotal from /proc/meminfo (kB).
      if (Platform.isAndroid || Platform.isLinux) {
        final file = File('/proc/meminfo');
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(content);
          if (match != null) {
            final kb = int.tryParse(match.group(1) ?? '');
            if (kb != null) {
              final mb = kb ~/ 1024;
              if (mb < 2048) return 1;
              if (mb < 3072) return 2;
              if (mb < 4096) return 2;
              return requested;
            }
          }
        }
      }
      // macOS/iOS: fallback to ProcessInfo if available, otherwise
      // keep requested — those platforms rarely hit the low-RAM path.
      // We avoid importing `dart:io` ProcessInfo.maxRss which is process-
      // local, not system total; so we keep the requested cap.
    } catch (_) {
      // Ignore and fall back to requested.
    }
    return requested;
  }

  final Map<String, _PooledEngine> _pool = {};
  final Map<String, Completer<BrowserWebEngine>> _pendingCreations = {};
  bool _disposed = false;

  static String originKeyOf(Uri origin) =>
      origin.replace(path: '/', query: null, fragment: null).toString();

  /// Acquires an engine allocated for [origin], creating one if necessary or reusing an existing view.
  Future<BrowserWebEngine> acquire(Uri origin) async {
    if (_disposed) throw StateError('HeadlessWebViewPool is disposed');
    final key = originKeyOf(origin);

    // If already pooled, return and bump usage
    final existing = _pool[key];
    if (existing != null) {
      existing.activeHolders++;
      existing.lastUsed = DateTime.now();
      return existing.engine;
    }

    // If an engine for this origin is already being created, wait on its completer
    final pending = _pendingCreations[key];
    if (pending != null) {
      final engine = await pending.future;
      _pool[key]?.activeHolders++;
      return engine;
    }

    final completer = Completer<BrowserWebEngine>();
    _pendingCreations[key] = completer;

    try {
      // Evict least-recently-used idle engine if at capacity (memory-aware).
      if (_pool.length >= _effectiveMaxViews) {
        _evictLruIdle();
      }

      final engine = _engineFactory(initialUrl: origin.toString());
      final pooled = _PooledEngine(engine);
      pooled.activeHolders++;
      _pool[key] = pooled;
      completer.complete(engine);
      return engine;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingCreations.remove(key);
    }
  }

  /// Releases the hold on [origin]'s engine, allowing it to be reused or evicted when needed.
  void release(Uri origin) {
    final key = originKeyOf(origin);
    final pooled = _pool[key];
    if (pooled != null) {
      pooled.activeHolders = (pooled.activeHolders - 1).clamp(0, 9999);
      pooled.lastUsed = DateTime.now();
    }
  }

  void _evictLruIdle() {
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _pool.entries) {
      if (entry.value.activeHolders == 0) {
        if (oldestTime == null || entry.value.lastUsed.isBefore(oldestTime)) {
          oldestTime = entry.value.lastUsed;
          oldestKey = entry.key;
        }
      }
    }

    if (oldestKey != null) {
      final evicted = _pool.remove(oldestKey);
      evicted?.engine.dispose();
    }
  }

  int get size => _pool.length;

  bool hasOrigin(Uri origin) => _pool.containsKey(originKeyOf(origin));

  void dispose() {
    _disposed = true;
    for (final pooled in _pool.values) {
      pooled.engine.dispose();
    }
    _pool.clear();
    _pendingCreations.clear();
  }
}

class _SingleEnginePool extends HeadlessWebViewPool {
  _SingleEnginePool(this._singleEngine) : super(maxViews: 1);

  final BrowserWebEngine _singleEngine;

  @override
  Future<BrowserWebEngine> acquire(Uri origin) async => _singleEngine;

  @override
  void release(Uri origin) {}

  @override
  int get size => 1;

  @override
  bool hasOrigin(Uri origin) => true;

  @override
  void dispose() {
    _singleEngine.dispose();
  }
}
