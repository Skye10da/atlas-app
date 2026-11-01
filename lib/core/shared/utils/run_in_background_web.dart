import 'dart:async';

/// Web implementation of [runInBackground].
///
/// `dart:isolate` is not available on the web target (attempting to use it
/// throws "dart isolate is not available for web"), so the computation runs
/// inline on the main isolate after yielding one event-loop turn, letting the
/// current frame settle before the heavy work blocks.
Future<R> runInBackgroundImpl<R>(FutureOr<R> Function() computation) async {
  await Future<void>.delayed(Duration.zero);
  return computation();
}
