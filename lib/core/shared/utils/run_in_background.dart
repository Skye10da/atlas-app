import 'dart:async';

import 'package:atlas_app/core/shared/utils/run_in_background_io.dart'
    // Web never reaches this branch: `dart:isolate` is unavailable there
    // ("dart isolate is not available for web"), so heavy work runs inline
    // instead.
    if (dart.library.js_interop) 'package:atlas_app/core/shared/utils/run_in_background_web.dart';

/// Runs [computation] as background work.
///
/// - Native (Android / Windows / Linux / iOS / macOS): runs in a fresh
///   isolate (`Isolate.run`) so parsing / scanning never blocks the UI.
/// - Web: `dart:isolate` does not exist, so on the web target this yields one
///   event-loop turn (so the current frame can settle) and then runs the
///   computation inline on the main isolate.
Future<R> runInBackground<R>(FutureOr<R> Function() computation) =>
    runInBackgroundImpl<R>(computation);
