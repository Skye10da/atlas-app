import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/widgets/app_session_refresh_bridge.dart';
import 'package:atlas_app/browser/domain/services/webview_offline_guard.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/core/import/opened_file_import_service.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';
import 'package:atlas_app/core/services/window_theme_channel.dart';
import 'package:atlas_app/core/theme/app_theme.dart';
import 'package:atlas_app/core/theme/local_fonts.dart';
import 'package:atlas_app/notifications/infrastructure/background_update_check.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/presentation/providers/update_check_settings_provider.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';
import 'package:atlas_app/reader/presentation/providers/lockscreen_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final _windowThemeChannel = WindowThemeChannel();

void main() {
  _installErrorHandlers();
  // The root zone must not be allowed to die: before these guards, a single
  // uncaught error in any background future (a network call with no catch —
  // plugin catalog sync, WebView transport, session refresh, …) terminated
  // the whole process. This is what made the Windows app crash whenever the
  // internet dropped mid-flight.
  //
  // IMPORTANT: `WidgetsFlutterBinding.ensureInitialized` must run in the SAME
  // zone as `runApp` — otherwise Flutter warns about a zone mismatch.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(LocalFonts.initialize());
    runApp(
      ProviderScope(
        child: AtlasApp(key: ValueKey(DateTime.now().millisecondsSinceEpoch)),
      ),
    );
  }, (error, stack) =>
      AppLogger.error('Unhandled error in root zone', error, stack));
}

/// Installs the last-resort error handlers. Every handler only logs —
/// nothing here is allowed to rethrow or terminate the isolate.
void _installErrorHandlers() {
  // Framework errors (build/layout/paint): keep the Flutter console dump,
  // but don't let a broken widget take down the process.
  FlutterError.onError = (details) => FlutterError.presentError(details);

  // Uncaught async errors from anywhere in the app (network tasks included).
  // Returning true means "handled" — the isolate keeps running.
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Unhandled async error', error, stack);
    return true;
  };
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
      // Glass toast pills display on the root navigator's overlay.
      AppToast.bind(AppRouter.rootNavigatorKey);
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

    // Pre-warm SharedPreferences so the reader's first chapter open
    // doesn't pay cold SharedPrefs init. `_applyTranslation` and
    // `_applyAtlasGlossary` await the translation/glossary `.future`
    // providers right after the "Preparing reader" phase is published;
    // on a cold start those block on `SharedPreferences.getInstance()`,
    // which used to stall the reader until it was closed and reopened
    // (by which point SharedPrefs was cached). Warming it here removes
    // that first-open latency.
    unawaited(SharedPreferences.getInstance());

    // Registers the headless WebView pool fallback fetcher for silent Cloudflare challenge solving
    try {
      final silentService = ref.read(silentWebViewServiceProvider);
      WebViewFetchService.instance.fallbackFetcher = silentService.fetchHtml;
    } catch (e, st) {
      AppLogger.error('Silent WebView fallback setup failed', e, st);
    }

    // WebView offline shield: the flutter_inappwebview_windows plugin has
    // native crash paths (0xc0000005 in its plugin DLL) that fire when its
    // requests fail on a lost connection. The guard pauses/blank-parks every
    // engine the moment connectivity drops, preempting those callbacks.
    try {
      WebViewOfflineGuard.instance.start();
    } catch (e, st) {
      AppLogger.error('WebView offline guard failed to start', e, st);
    }

    try {
      ref.read(pluginSourcesProvider);
    } catch (e, st) {
      AppLogger.error('Plugin discovery failed to start', e, st);
    }
    // Self-updater: silent daily GitHub Releases check (docs/release.md).
    // Result only surfaces in Settings → App updates; never interrupts boot.
    unawaited(_bootSelfUpdater(ref));
    // Each bootstrap subsystem is guarded: with the internet down, several
    // of these (plugin catalog sync, scheduler's first network pass, WTR
    // session restore) can throw — a failure in one must never prevent the
    // rest from starting (or the app from booting at all).
    try {
      ref.read(taskSchedulerProvider).start();
    } catch (e, st) {
      AppLogger.error('Maintenance scheduler failed to start', e, st);
    }
    try {
      ref.read(speechStartupProvider);
    } catch (_) {}
    // Lockscreen music notification widget — mobile (MediaStyle) + desktop (SMTC/MPRIS)
    // Keeps ViewModel alive so SpeechEvents → LockscreenRepository → audio_service
    try {
      ref.read(lockscreenViewModelProvider);
    } catch (_) {}
    // Sherpa ONNX is lazy-initialized only when an offline voice pack is
    // actually selected (OfflineNeuralDriver._ensureSherpaInit). Eager init
    // here was crashing Windows at startup (missing VC++ runtime / DLL load
    // failure propagates as unhandled native exception) — do not init here.
    // Wires the platform-backed WTR-Lab runtime (SharedPreferences preference
    // store + WebView-cookie session) and restores the persisted auth state so
    // reading starts authenticated-aware.
    try {
      await ref.read(wtrRuntimeProvider.future);
    } catch (e, st) {
      AppLogger.error('WTR-Lab runtime restore failed', e, st);
    }

    try {
      await _initUpdateChecks(ref);
    } catch (e, st) {
      AppLogger.error('Update checks failed to initialize', e, st);
    }

    try {
      await _initFileOpen(ref);
    } catch (e, st) {
      AppLogger.error('File-open import failed to initialize', e, st);
    }
  }

  static bool _updateChecksInitialized = false;

  /// Waits for the updater's async build (prefs + PackageInfo) to resolve so
  /// the notifier has its stores wired, then runs the throttled check. After
  /// that, records the changelog entry of a freshly-installed version and
  /// surfaces it as a one-tap "What's new" banner (self-update, docs/release.md).
  Future<void> _bootSelfUpdater(WidgetRef ref) async {
    try {
      await ref.read(updaterControllerProvider.future);
      await ref.read(updaterControllerProvider.notifier).maybeAutoCheck();

      final updaterState = ref.read(updaterControllerProvider).valueOrNull;
      if (updaterState == null || updaterState.currentBuild == 0) return;
      final entry = await ref
          .read(changelogControllerProvider.notifier)
          .detectInstalledVersionChange(
            currentBuild: updaterState.currentBuild,
            currentVersion: updaterState.currentVersion,
          );
      if (entry != null) _showWhatsNewBanner(entry);
    } catch (e, st) {
      AppLogger.error('App self-update check failed', e, st);
    }
  }

  /// Post-update surfacing: a single glass droplet pill over whatever screen
  /// the user lands on, offering the What's-new screen. Skipped when the pill
  /// host isn't ready yet (the entry is already in the changelog store,
  /// so Settings → What's new covers it).
  static void _showWhatsNewBanner(ChangelogEntry entry) {
    AppToast.show(
      'Atlas ${entry.version} installed — see what changed.',
      tone: AppToastTone.sparkle,
      action: AppToastAction(
        'Read',
        () => AppRouter.openWhatsNew(),
      ),
    );
  }
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
    // Try preview-confirm flow like the file picker: read bytes, show the
    // import sheet with a NovelModel preview, let the user confirm. If no
    // BuildContext is available yet (very early cold start) fall back to
    // silent auto-import then navigate to the novel details page.
    final handled = await _tryPreviewImport(ref, importer, path);
    if (handled) return;

    // Silent fallback (no context or preview failed).
    final result = await importer.import(path);
    switch (result) {
      case Success(value: final outcome):
        await _navigateImported(outcome);
      case Failure(error: final error):
        _showToast(error.userMessage);
    }
  }

  /// Shows the confirmation sheet when a context is available. Returns true
  /// if the sheet took over (navigation already handled), false to fall back
  /// to silent import.
  Future<bool> _tryPreviewImport(
    WidgetRef ref,
    OpenedFileImportService importer,
    String path,
  ) async {
    // Wait briefly for a navigator context on cold start.
    BuildContext? ctx;
    for (var i = 0; i < 10; i++) {
      ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) break;
    }
    if (ctx == null || !ctx.mounted) return false;

    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final fileName = p.basename(path);
      final ext = p.extension(fileName).toLowerCase();
      if (!['.atlas', '.epub', '.pdf', '.txt', '.text', '.md', '.markdown']
          .contains(ext)) {
        return false;
      }
      if (!ctx.mounted) return false;

      // Build preview model without importing, mirroring import_url_dialog pickFile.
      final preview = await _extractPreviewForBytes(ref, bytes, fileName);
      if (preview == null) return false;
      if (!ctx.mounted) return false;

      final outcome = await showImportUrlSheet(
        ctx,
        mode: ImportSheetMode.combined,
        title: 'Add to library',
        previewModel: preview,
        onImport: (b, f, url, onProgress) async {
          final useBytes = b ?? bytes;
          final useName = f ?? fileName;
          onProgress(0.1);
          final res = await importer.importBytes(useBytes, useName);
          onProgress(1.0);
          // Clean up the sandbox copy after a preview import (importBytes does not).
          if (importer.shouldDeleteTempCopy(path)) {
            try {
              await File(path).delete();
            } catch (_) {}
          }
          if (res is Success<ImportOutcome>) return res.value;
          if (res is Failure<ImportOutcome>) throw res.error;
          throw Exception('Import cancelled');
        },
      );

      if (outcome != null) {
        await _navigateImported(outcome);
      } else {
        // User dismissed sheet without importing — still clean up temp copy.
        if (importer.shouldDeleteTempCopy(path)) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _extractPreviewForBytes(
    WidgetRef ref,
    List<int> bytes,
    String fileName,
  ) async {
    final lower = fileName.toLowerCase();
    try {
      if (lower.endsWith('.atlas')) {
        final svc = ref.read(atlasSourceImportServiceProvider);
        return await svc.extractMetadata(bytes, fileName);
      } else if (lower.endsWith('.pdf')) {
        final svc = ref.read(pdfImportServiceProvider);
        return await svc.extractMetadata(bytes, fileName);
      } else if (lower.endsWith('.txt') ||
          lower.endsWith('.text') ||
          lower.endsWith('.md') ||
          lower.endsWith('.markdown')) {
        final svc = ref.read(textImportServiceProvider);
        return await svc.extractMetadata(bytes, fileName);
      } else {
        final svc = ref.read(libraryImportServiceProvider);
        return await svc.extractMetadata(bytes, fileName);
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _navigateImported(ImportOutcome outcome) async {
    final route = outcome.category == ContentCategory.novel
        ? '/novel/${outcome.bookId}'
        : '/book/${outcome.bookId}';
    // The OS can report the same cold-start file both as an initial argument
    // and as a stream event. Avoid stacking the same detail page twice.
    if (AppRouter.router.routeInformationProvider.value.uri.path == route) {
      return;
    }
    // Retry in case the navigator isn't mounted yet on a cold-start open.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        // ignore: unawaited_futures
        AppRouter.router.push(route);
        return;
      } catch (_) {
        // GoException when route isn't ready — try go() next.
        try {
          AppRouter.router.go(route);
          return;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    // Last resort: direct Navigator on the root key.
    try {
      final ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        // ignore: use_build_context_synchronously
        AppRouter.router.go(route);
        return;
      }
    } catch (_) {}
    _showToast('Imported — open it from your library.');
  }

  void _showToast(String message) {
    AppToast.show(message);
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
