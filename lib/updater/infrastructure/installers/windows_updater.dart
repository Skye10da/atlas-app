import 'dart:io';

import 'package:archive/archive_io.dart' show ZipDecoder;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/logging/logger.dart';

/// Windows self-update: you cannot overwrite a running .exe, so the update is
/// applied by a detached helper script that waits for this process to exit,
/// mirrors the extracted new build over the install directory, and restarts
/// Atlas. The controller calls [apply] right before `exit(0)`.
class WindowsUpdater {
  /// Applies a previously downloaded & hash-verified update [zipPath].
  Future<void> apply(String zipPath) async {
    final tempDir = await getTemporaryDirectory();
    final extractionDir = Directory(p.join(tempDir.path, 'updates', 'swap'));
    if (extractionDir.existsSync()) {
      extractionDir.deleteSync(recursive: true);
    }
    extractionDir.createSync(recursive: true);

    final archive = ZipDecoder().decodeBytes(
      await File(zipPath).readAsBytes(),
    );
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final outFile = File(
        p.join(extractionDir.path, entry.name),
      )..createSync(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }

    final installDir = File(Platform.resolvedExecutable).parent;
    final exeName = p.basename(Platform.resolvedExecutable);

    // robocopy exit codes: 0-7 are success variants, 8+ are real failures.
    final scriptContent = '@echo off\r\n'
        'echo Waiting for Atlas to exit...\r\n'
        'timeout /t 3 /nobreak >nul\r\n'
        'robocopy "${extractionDir.path}" "${installDir.path}" '
        '/E /NFL /NDL /NJH /NJS /NP >nul\r\n'
        'if errorlevel 8 exit /b 1\r\n'
        'start "" "${p.join(installDir.path, exeName)}"\r\n';
    final script = File(
      p.join(tempDir.path, 'updates', 'apply_swap.cmd'),
    )..writeAsStringSync(scriptContent);

    final process = await Process.start(
      'cmd.exe',
      ['/c', script.path],
      mode: ProcessStartMode.detached,
    );
    AppLogger.info(
      'Updater: spawned swap script (pid ${process.pid}) — exiting now.',
    );
  }
}
