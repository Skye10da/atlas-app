import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web implementation of the app's drift connection.
///
/// Uses drift's official WASM support: `sqlite3.wasm` and `drift_worker.js`
/// must be served next to `index.html` (they live in `web/`). The worker
/// persists the database to OPFS when available, falling back to IndexedDB —
/// and both storage locations survive reloads.
QueryExecutor createAppConnectionImpl() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'atlas_app',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}

/// In-memory connection for tests. Tests run on the VM and never execute this
/// branch; for completeness it opens a throwaway browser database.
QueryExecutor memoryAppConnectionImpl() => createAppConnectionImpl();
