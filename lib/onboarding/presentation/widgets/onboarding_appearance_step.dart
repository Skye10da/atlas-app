import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_page_frame.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

/// A short list of brand colours; the full catalogue stays in Settings.
const List<AppBrand> _kOnboardingBrands = [
  AppBrand.atlas,
  AppBrand.sapphire,
  AppBrand.violet,
  AppBrand.emerald,
  AppBrand.teal,
  AppBrand.amber,
  AppBrand.rose,
  AppBrand.slate,
];

/// Theme mode and brand colour. Changes apply immediately (the whole app
/// rebuilds with them), which doubles as the preview.
class OnboardingAppearanceStep extends ConsumerWidget {
  const OnboardingAppearanceStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(readingSettingsProvider).valueOrNull ??
        const ReadingSettingsEntity();
    final notifier = ref.read(readingSettingsProvider.notifier);

    return OnboardingPageFrame(
      hero: const OnboardingHeroBadge(icon: Icons.palette_outlined),
      title: 'Make it yours',
      subtitle: 'Choose how Atlas looks. Changes show up right away.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selected) =>
                  notifier.setThemeMode(selected.first),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Colour', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final brand in _kOnboardingBrands)
                _BrandSwatch(
                  brand: brand,
                  selected: brand == settings.brand,
                  onTap: () => notifier.setBrand(brand),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandSwatch extends StatelessWidget {
  const _BrandSwatch({
    required this.brand,
    required this.selected,
    required this.onTap,
  });

  final AppBrand brand;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '${brand.label} colour',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: AppSpacing.touchTarget - 2,
          height: AppSpacing.touchTarget - 2,
          decoration: BoxDecoration(
            color: brand.seed,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}
