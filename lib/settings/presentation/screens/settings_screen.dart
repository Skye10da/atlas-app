import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load settings')),
        data: (settings) {
          final notifier = ref.read(readingSettingsProvider.notifier);
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Keep screen awake'),
                subtitle: const Text('Prevent screen from turning off while reading'),
                value: settings.keepScreenAwake,
                onChanged: notifier.setKeepScreenAwake,
              ),
              ListTile(
                title: const Text('Brightness'),
                subtitle: Slider(
                  value: settings.brightness,
                  min: 0.0,
                  max: 1.0,
                  onChanged: notifier.setBrightness,
                ),
              ),
              SwitchListTile(
                title: const Text('Auto-optimize for battery'),
                subtitle: const Text(
                    'Automatically dim brightness when battery is low'),
                value: settings.autoOptimizeBrightness,
                onChanged: notifier.setAutoOptimizeBrightness,
              ),
              const Divider(),
              ListTile(
                title: const Text('Font size'),
                subtitle: Slider(
                  value: settings.fontSize,
                  min: 12,
                  max: 28,
                  divisions: 16,
                  onChanged: notifier.setFontSize,
                ),
              ),
              ListTile(
                title: const Text('Line height'),
                subtitle: Slider(
                  value: settings.lineHeight,
                  min: 1.0,
                  max: 2.0,
                  divisions: 10,
                  onChanged: notifier.setLineHeight,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
