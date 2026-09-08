import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/widgets/app_session_refresh_bridge.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/core/import/opened_file_import_service.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/services/window_theme_channel.dart';
import 'package:atlas_app/core/theme/app_theme.dart';
import 'package:atlas_app/core/theme/local_fonts.dart';
import 'package:atlas_app/notifications/infrastructure/background_update_check.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/presentation/providers/update_check_settings_provider.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final _windowThemeChannel = WindowThemeChannel();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(LocalFonts.initialize());
  runApp(
    ProviderScope(
      child: AtlasApp(key: ValueKey(DateTime.now().millisecondsSinceEpoch)),
    ),
  );
}

class AtlasApp extends ConsumerWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const ReadingSettingsEntity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap(ref));
      _syncNativeTheme(context, settings);
    });

    return MaterialApp.router(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light(settings.brand, settings.systemFontFamily),
      darkTheme: AppTheme.dark(settings.brand, settings.systemFontFamily),
      themeMode: settings.themeMode,
      routerConfig: AppRouter.router,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            // Installs the session re-verify driver (see
            // `app_session_refresh_bridge.dart`); renders nothing itself.
            const AppSessionRefreshBridge(),
          ],
        );
      },
    );
  }

  static bool _bootstrapped = false;

  /// One-time background startup: kicks off plugin discovery, starts the
  /// maintenance scheduler, boots the Speech subsystem, wires up OS file
  /// import (open with Atlas), and registers ongoing-novel update checks.
  Future<void> _bootstrap(WidgetRef ref) async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // Registers the headless WebView pool fallback fetcher for silent Cloudflare challenge solving
    final silentService = ref.read(silentWebViewServiceProvider);
    WebViewFetchService.instance.fallbackFetcher = silentService.fetchHtml;

    ref.read(pluginSourcesProvider);
    ref.read(taskSchedulerProvider).start();
    ref.read(speechStartupProvider);
    // Wires the platform-backed WTR-Lab runtime (SharedPreferences preference
    // store + WebView-cookie session) and restores the persisted auth state so
    // reading starts authenticated-aware.
    await ref.read(wtrRuntimeProvider.future);

    await _initUpdateChecks(ref);

    await _initFileOpen(ref);
  }

  static bool _updateChecksInitialized = false;

  Future<void> _initUpdateChecks(WidgetRef ref) async {
    if (_updateChecksInitialized) return;
    _updateChecksInitialized = true;
    final settings = await UpdateCheckSettingsStore.load();
    ref.read(updateCheckIntervalHoursProvider.notifier).state =
        settings.intervalHours;
    // Initialized unconditionally so notification taps deep-link even when
    // the OS-level checks are off.
    final db = ref.read(databaseProvider);
    await UpdateNotificationService.instance.initialize(db: db);
    await initializeBackgroundUpdateChecks(settings);
  }

  static bool _fileOpenSubscribed = false;

  Future<void> _initFileOpen(WidgetRef ref) async {
    if (_fileOpenSubscribed) return;
    _fileOpenSubscribed = true;
    final controller = ref.read(fileOpenControllerProvider);
    final importer = ref.read(openedFileImportServiceProvider);
    controller.openedFiles.listen((path) {
      unawaited(_handleOpenedFile(ref, importer, path));
    });
    // Wait for controller.init() so cold-start desktop args / initial mobile
    // file are emitted while one listener is guaranteed stable.
    await controller.init();
  }

  Future<void> _handleOpenedFile(
    WidgetRef ref,
    OpenedFileImportService importer,
    String path,
  ) async {
    final result = await importer.import(path);
    switch (result) {
      case Success(value: final outcome):
        await _navigateImported(outcome);
      case Failure(error: final error):
        _showToast(error.userMessage);
    }
  }

  Future<void> _navigateImported(ImportOutcome outcome) async {
    final route = outcome.category == ContentCategory.novel
        ? '/novel/${outcome.bookId}'
        : '/book/${outcome.bookId}';
    // Retry once in case the navigator isn't mounted yet on a cold-start open.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await AppRouter.router.push(route);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  void _showToast(String message) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _syncNativeTheme(BuildContext context, ReadingSettingsEntity settings) {
    final brightness = switch (settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    _windowThemeChannel.syncTheme(
      brightness: brightness,
      brandSeed: settings.brand.seed,
    );
  }
}
