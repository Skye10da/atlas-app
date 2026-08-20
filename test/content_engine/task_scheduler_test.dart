import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/scheduler/task_scheduler.dart';

void main() {
  group('TaskScheduler', () {
    test(
      'runAllNow invokes every registered task and returns summaries',
      () async {
        final scheduler = TaskScheduler();
        var refreshRan = false;
        var cleanupRan = false;

        scheduler.setTasks(
          pluginRefresh: () async {
            refreshRan = true;
            return 'refreshed 2 plugins';
          },
          resumeDownloads: () async => null,
          cacheCleanup: () async {
            cleanupRan = true;
            return 'removed 3 stale entries';
          },
        );

        final summaries = await scheduler.runAllNow();

        expect(refreshRan, isTrue);
        expect(cleanupRan, isTrue);
        expect(summaries, ['refreshed 2 plugins', 'removed 3 stale entries']);
      },
    );

    test('a task that returns nothing produces no log line', () async {
      final scheduler = TaskScheduler();
      final logLines = <String>[];
      scheduler.log.listen(logLines.add);

      scheduler.setTasks(resumeDownloads: () async => null);
      await scheduler.runAllNow();

      expect(logLines, isEmpty);
    });

    test(
      'a failing task is caught and logged, and later runs still proceed',
      () async {
        final scheduler = TaskScheduler();
        final logLines = <String>[];
        scheduler.log.listen(logLines.add);
        var attempts = 0;

        scheduler.setTasks(
          pluginRefresh: () async {
            attempts++;
            if (attempts == 1) throw Exception('network down');
            return 'refreshed on retry';
          },
        );

        await scheduler.runAllNow();
        await scheduler.runAllNow();
        await Future<void>.delayed(Duration.zero);

        expect(attempts, 2);
        expect(logLines, [
          '[pluginRefresh] failed: Exception: network down',
          '[pluginRefresh] refreshed on retry',
        ]);
      },
    );

    test('scheduled ticks call the task after each interval', () async {
      var runs = 0;
      final scheduler = TaskScheduler(
        pluginRefreshInterval: const Duration(milliseconds: 1),
        timer: (d) => Future<void>.delayed(const Duration(milliseconds: 2)),
      );

      scheduler.setTasks(
        pluginRefresh: () async {
          runs++;
          return 'run $runs';
        },
      );

      scheduler.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      scheduler.stop();

      expect(runs, greaterThanOrEqualTo(1));
    });

    test('overlapping ticks are skipped while a task is running', () async {
      final completer = Completer<void>();
      var started = 0;
      var maxConcurrent = 0;
      var current = 0;
      final scheduler = TaskScheduler(
        pluginRefreshInterval: const Duration(milliseconds: 1),
        timer: (d) => Future<void>.delayed(const Duration(milliseconds: 2)),
      );

      scheduler.setTasks(
        pluginRefresh: () async {
          started++;
          current++;
          maxConcurrent = current > maxConcurrent ? current : maxConcurrent;
          await completer.future;
          current--;
          return null;
        },
      );

      scheduler.start();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(started, 1);
      expect(maxConcurrent, 1);
      completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      scheduler.stop();

      expect(maxConcurrent, 1);
    });
  });
}
