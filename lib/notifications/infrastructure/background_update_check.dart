import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';

/// Unique workmanager name for the periodic chapter-update task.
const kChapterUpdateTaskName = 'atlas.chapterUpdateCheck';
const _kChapterUpdateUniqueName = 'atlas-chapter-update-check';

/// Runs the update check without the app's Riverpod graph so it can execute
/// inside the workmanager background isolate (and be reused by any caller
/// that has no provider container).
///
/// Builds its own database connection and plugin registry, checks every
/// tracked ongoing novel, and raises an OS notification when configured to.
@pragma('vm:entry-point')
Future<bool> runChapterUpdateBackgroundTask() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase? db;
  try {
    final database = AppDatabase();
    db = database;
    final settings = await UpdateCheckSettingsStore.load();
    if (!settings.enabled) return true;

    final registry = await _buildPluginRegistry();
    final service = ChapterUpdateService(db: database, registry: registry);
    final result = await service.checkTrackedBooks();

    if (result.booksWithUpdates > 0 && settings.notificationsEnabled) {
      await UpdateNotificationService.instance.initialize();
      await UpdateNotificationService.instance.showUpdateSummary(
        result.updates
            .map(
              (u) => (title: u.title, bookId: u.bookId, count: u.newChapters),
            )
            .toList(),
      );
    }
    return true;
  } catch (e, st) {
    AppLogger.error('Background update check failed', e, st);
    return false;
  } finally {
    try {
      await db?.close();
    } catch (_) {}
  }
}

/// Loads installed plugin sources from `<support>/plugins` into a fresh
/// registry. Skips the GitHub catalog sync — a background check must stay
/// fast and network-light; whatever was installed at last app start is used.
Future<SourceRegistry> _buildPluginRegistry() async {
  final registry = SourceRegistry();
  try {
    final supportDir = await getApplicationSupportDirectory();
    final pluginsDir = Directory(p.join(supportDir.path, 'plugins'));
    final repository = PluginRepository(
      baseDirectory: pluginsDir,
      templateRegistry: TemplateRegistry.defaults,
    );
    for (final manifest in await repository.loadAll()) {
      try {
        registry.register(await repository.buildSource(manifest.id));
      } catch (e) {
        AppLogger.warning('Skipping plugin "${manifest.id}": $e');
      }
    }
  } catch (e) {
    AppLogger.warning('Plugin discovery failed in background isolate: $e');
  }
  return registry;
}

/// Top-level dispatcher entry point required by workmanager. All Atlas
/// background tasks funnel through [runChapterUpdateBackgroundTask].
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return runChapterUpdateBackgroundTask();
  });
}

/// Initializes workmanager and registers the periodic update check.
///
/// No-op on platforms without workmanager support (Windows). Safe to call
/// repeatedly; re-registration with [ExistingPeriodicWorkPolicy.update]
/// applies interval changes made in Settings.
Future<void> initializeBackgroundUpdateChecks(
  UpdateCheckSettings settings,
) async {
  if (kIsWeb ||
      !(Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isLinux)) {
    return;
  }
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _kChapterUpdateUniqueName,
      kChapterUpdateTaskName,
      frequency: Duration(hours: settings.intervalHours),
      // Don't let the first OS run coincide with app startup — the check
      // competes with plugin discovery and first-frame rendering otherwise.
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    AppLogger.warning('Failed to register background update checks: $e');
  }
}
