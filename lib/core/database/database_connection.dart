import 'package:drift/drift.dart';

import 'package:atlas_app/core/database/database_connection_io.dart'
    // The Dart-only target reaches this branch: drift's `NativeDatabase`
    // (through `drift/native.dart` → `sqlite3` → `dart:ffi`) cannot compile on
    // web, where the WASM connection below is used instead.
    if (dart.library.js_interop) 'package:atlas_app/core/database/database_connection_web.dart';

/// Creates the production connection for [AppDatabase].
///
/// - Native (Android / Windows / Linux / iOS / macOS): a `NativeDatabase`
///   running in a background isolate on the app's SQLite file.
/// - Web: drift's official `WasmDatabase`, backed by `sqlite3.wasm` and
///   `drift_worker.js` served next to `index.html` (see `web/`). Data is
///   persisted to IndexedDB / OPFS by the worker.
QueryExecutor createAppConnection() => createAppConnectionImpl();

/// In-memory connection used by fast widget/unit tests.
QueryExecutor memoryAppConnection() => memoryAppConnectionImpl();
