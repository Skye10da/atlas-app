import 'dart:async';
import 'dart:isolate';

/// Native implementation of [runInBackground]: spawns a fresh isolate.
Future<R> runInBackgroundImpl<R>(FutureOr<R> Function() computation) =>
    Isolate.run(computation);
