import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/presentation/widgets/app_session_refresh_bridge.dart';
import 'package:atlas_app/browser/presentation/widgets/silent_web_view_host.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/core/import/opened_file_import_service.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/services/window_theme_channel.dart';
import 'package:atlas_app/core/theme/app_theme.dart';
import 'package:atlas_app/core/theme/local_fonts.dart';
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
      builder: (context, child) {
        // A 1x1 off-screen background web view that survives for the whole app
        // lifetime, so plugin fetches (reader chapter downloads, imports) can
        // re-establish a browser session for bot-protected sites even when the
        // in-app browser is closed. IgnorePointer + no-focus keep it from
        // stealing input.
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            const Positioned(
              right: 0,
              bottom: 0,
              width: 1,
              height: 1,
              child: SilentWebViewHost(),
            ),
            // Installs the session re-verify driver (see
            // `app_session_refresh_bridge.dart`); renders nothing itself.
            const AppSessionRefreshBridge(),
          ],
        );
      },
    );
  }

  /// One-time background startup: kicks off plugin discovery, starts the
  /// maintenance scheduler, boots the Speech subsystem, and wires up OS file
  /// import (open with Atlas). Safe to call repeatedly; all idempotent.
  Future<void> _bootstrap(WidgetRef ref) async {
    ref.read(pluginSourcesProvider);
    ref.read(taskSchedulerProvider).start();
    ref.read(speechStartupProvider);
    // Wires the platform-backed WTR-Lab runtime (SharedPreferences preference
    // store + WebView-cookie session) and restores the persisted auth state so
    // reading starts authenticated-aware.
    await ref.read(wtrRuntimeProvider.future);
    await _initFileOpen(ref);
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
