import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/theme/app_theme.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: AtlasApp(key: ValueKey(DateTime.now().millisecondsSinceEpoch))));
}

class AtlasApp extends ConsumerWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const ReadingSettingsEntity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap(ref);
    });

    return MaterialApp.router(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.brand, settings.systemFontFamily),
      darkTheme: AppTheme.dark(settings.brand, settings.systemFontFamily),
      themeMode: settings.themeMode,
      routerConfig: AppRouter.router,
    );
  }

  /// One-time background startup: kicks off plugin discovery, starts the
  /// maintenance scheduler, and boots the Speech subsystem (audio_service,
  /// voice cache, driver validation). Safe to call repeatedly; all idempotent.
  void _bootstrap(WidgetRef ref) {
    ref.read(pluginSourcesProvider);
    ref.read(taskSchedulerProvider).start();
    ref.read(speechStartupProvider);
  }
}
