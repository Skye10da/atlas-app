import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/theme/app_theme.dart';
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

    return MaterialApp.router(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.brand, settings.systemFontFamily),
      darkTheme: AppTheme.dark(settings.brand, settings.systemFontFamily),
      themeMode: settings.themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
