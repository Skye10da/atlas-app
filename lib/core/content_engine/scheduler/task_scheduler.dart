import 'dart:async';

/// A single periodic maintenance job: plugin refresh, resume-downloads, cache
/// cleanup. Each task returns its work as a string describing what happened
/// (or null/empty for nothing) so the scheduler can log the outcome.
typedef ScheduledTask = Future<String?> Function();

/// Runs background maintenance tasks on fixed intervals without overlapping:
/// if a task is still running when its next tick fires, that tick is skipped.
/// Timer seams are injectable for deterministic tests.
class TaskScheduler {
  TaskScheduler({
    this.pluginRefreshInterval = const Duration(hours: 6),
    this.resumeDownloadsInterval = const Duration(minutes: 30),
    this.cacheCleanupInterval = const Duration(hours: 24),
    Duration Function()? updateCheckIntervalResolver,
    Future<void> Function(Duration)? timer,
  }) : _timer = timer ?? Future<void>.delayed,
       _updateCheckIntervalResolver =
           updateCheckIntervalResolver ?? (() => const Duration(hours: 6));

  final Duration pluginRefreshInterval;
  final Duration resumeDownloadsInterval;
  final Duration cacheCleanupInterval;

  /// Resolved on every scheduling tick so runtime changes to the user's
  /// preferred check interval take effect without restarting the scheduler.
  final Duration Function() _updateCheckIntervalResolver;
  final Future<void> Function(Duration) _timer;

  ScheduledTask? _pluginRefresh;
  ScheduledTask? _resumeDownloads;
  ScheduledTask? _cacheCleanup;
  ScheduledTask? _updateCheck;

  final Map<String, bool> _running = {};
  final List<StreamController<String>> _logControllers = [];
  bool _started = false;

  void setTasks({
    ScheduledTask? pluginRefresh,
    ScheduledTask? resumeDownloads,
    ScheduledTask? cacheCleanup,
    ScheduledTask? updateCheck,
  }) {
    _pluginRefresh = pluginRefresh;
    _resumeDownloads = resumeDownloads;
    _cacheCleanup = cacheCleanup;
    _updateCheck = updateCheck;
  }

  void start() {
    if (_started) return;
    _started = true;
    if (_pluginRefresh != null) {
      _schedule('pluginRefresh', () => pluginRefreshInterval, _pluginRefresh!);
    }
    if (_resumeDownloads != null) {
      _schedule(
        'resumeDownloads',
        () => resumeDownloadsInterval,
        _resumeDownloads!,
      );
    }
    if (_cacheCleanup != null) {
      _schedule('cacheCleanup', () => cacheCleanupInterval, _cacheCleanup!);
    }
    if (_updateCheck != null) {
      _schedule('updateCheck', _updateCheckIntervalResolver, _updateCheck!);
    }
  }

  Future<void> _schedule(
    String name,
    Duration Function() interval,
    ScheduledTask task,
  ) async {
    while (_started) {
      await _timer(interval());
      if (!_started) return;
      await _run(name, task);
    }
  }

  Future<void> _run(String name, ScheduledTask task) async {
    if (_running[name] == true) return;
    _running[name] = true;
    try {
      final summary = await task();
      if (summary != null && summary.isNotEmpty) {
        for (final controller in _logControllers) {
          controller.add('[$name] $summary');
        }
      }
    } catch (e) {
      for (final controller in _logControllers) {
        controller.add('[$name] failed: $e');
      }
    } finally {
      _running[name] = false;
    }
  }

  /// Runs every registered task once immediately (regardless of interval).
  /// Returns the summaries, for one-shot invocation and tests.
  Future<List<String>> runAllNow() async {
    final results = <String>[];
    for (final entry in [
      ('pluginRefresh', _pluginRefresh),
      ('resumeDownloads', _resumeDownloads),
      ('cacheCleanup', _cacheCleanup),
      ('updateCheck', _updateCheck),
    ]) {
      final name = entry.$1;
      final task = entry.$2;
      if (task == null) continue;
      final summary = await _runForResult(name, task);
      if (summary != null) results.add(summary);
    }
    return results;
  }

  Future<String?> _runForResult(String name, ScheduledTask task) async {
    if (_running[name] == true) return null;
    _running[name] = true;
    try {
      final summary = await task();
      if (summary != null && summary.isNotEmpty) {
        for (final controller in _logControllers) {
          controller.add('[$name] $summary');
        }
      }
      return summary;
    } catch (e) {
      for (final controller in _logControllers) {
        controller.add('[$name] failed: $e');
      }
      return null;
    } finally {
      _running[name] = false;
    }
  }

  /// Broadcasts one line per completed/failed task run.
  Stream<String> get log {
    final controller = StreamController<String>();
    _logControllers.add(controller);
    controller.onCancel = () => _logControllers.remove(controller);
    return controller.stream;
  }

  void stop() {
    _started = false;
  }
}
