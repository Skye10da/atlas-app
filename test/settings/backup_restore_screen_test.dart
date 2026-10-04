import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/library/application/library_backup_service.dart';
import 'package:atlas_app/settings/presentation/screens/backup_restore_screen.dart';

void main() {
  testWidgets('BackupRestoreScreen renders options, format selector, and action buttons', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          libraryBackupServiceProvider.overrideWithValue(LibraryBackupService(db)),
        ],
        child: const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar and Header
    expect(find.text('Library Backup & Restore'), findsOneWidget);
    expect(find.text('Full Library Preservation'), findsOneWidget);

    // Verify Sections
    expect(find.text('Export Library Backup'), findsOneWidget);
    expect(find.text('Restore Library Backup'), findsOneWidget);

    // Verify Segmented Buttons for formats
    expect(find.text('Full Package (.atlas)'), findsOneWidget);
    expect(find.text('Metadata Only (.json)'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Save Backup File'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Select Backup to Restore'), findsOneWidget);

    // Verify format toggle interaction
    await tester.tap(find.text('Metadata Only (.json)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Lightweight JSON file containing all books, reading progress, exact positions, and sources.'),
      findsOneWidget,
    );

    await db.close();
  });
}
