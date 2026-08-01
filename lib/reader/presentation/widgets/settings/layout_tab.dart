import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class LayoutTab extends StatelessWidget {
  const LayoutTab({
    super.key,
    required this.readingMode,
    required this.keepScreenAwake,
    required this.brightness,
    required this.autoOptimizeBrightness,
    required this.followSystemBrightness,
    this.pageTurnAnimation,
    this.scrollAnimation,
    this.chromeStyle = ReaderChromeStyle.translucent,
    required this.onReadingModeChanged,
    required this.onKeepScreenAwakeChanged,
    required this.onBrightnessChanged,
    required this.onAutoOptimizeChanged,
    required this.onFollowSystemBrightnessChanged,
    this.onPageTurnAnimationChanged,
    this.onScrollAnimationChanged,
    this.onChromeStyleChanged,
  });

  final ReadingMode readingMode;
  final bool keepScreenAwake;
  final double brightness;
  final bool autoOptimizeBrightness;
  final bool followSystemBrightness;
  final PageTurnAnimation? pageTurnAnimation;
  final ScrollAnimation? scrollAnimation;
  final ReaderChromeStyle chromeStyle;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<bool> onKeepScreenAwakeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<bool> onAutoOptimizeChanged;
  final ValueChanged<bool> onFollowSystemBrightnessChanged;
  final ValueChanged<PageTurnAnimation>? onPageTurnAnimationChanged;
  final ValueChanged<ScrollAnimation>? onScrollAnimationChanged;
  final ValueChanged<ReaderChromeStyle>? onChromeStyleChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reading Mode', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: ReadingMode.values.map((m) {
              final isSelected = readingMode == m;
              return ChoiceChip(
                label: Text(m.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onReadingModeChanged(m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Chrome Style', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: ReaderChromeStyle.values.map((s) {
              final isSelected = chromeStyle == s;
              return ChoiceChip(
                avatar: Icon(s.icon, size: 16),
                label: Text(s.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onChromeStyleChanged?.call(s);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (readingMode == ReadingMode.page) ...[
            Text('Page Turn Animation', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: PageTurnAnimation.values.map((a) {
                final isSelected = pageTurnAnimation == a;
                return ChoiceChip(
                  avatar: Icon(a.icon, size: 16),
                  label: Text(a.label),
                  selected: isSelected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onPageTurnAnimationChanged?.call(a);
                  },
                );
              }).toList(),
            ),
          ],
          if (readingMode == ReadingMode.continuous) ...[
            Text('Scroll Animation', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: ScrollAnimation.values.map((a) {
                final isSelected = scrollAnimation == a;
                return ChoiceChip(
                  avatar: Icon(a.icon, size: 16),
                  label: Text(a.label),
                  selected: isSelected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onScrollAnimationChanged?.call(a);
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text('Screen Brightness', style: textTheme.labelLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Follow System Brightness',
                style: textTheme.labelLarge),
            subtitle: Text('Use the device\'s brightness while reading',
                style: textTheme.bodySmall),
            value: followSystemBrightness,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onFollowSystemBrightnessChanged(v);
            },
          ),
          Row(
            children: [
              Icon(Icons.brightness_low,
                  size: 16,
                  color: followSystemBrightness
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                      : null),
              Expanded(
                child: Slider(
                  value: brightness,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: brightness.toStringAsFixed(2),
                  onChanged: followSystemBrightness
                      ? null
                      : onBrightnessChanged,
                ),
              ),
              Icon(Icons.brightness_high,
                  size: 16,
                  color: followSystemBrightness
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                      : null),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Keep Screen Awake', style: textTheme.labelLarge),
            subtitle: Text('Prevent device from sleeping while reading',
                style: textTheme.bodySmall),
            value: keepScreenAwake,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onKeepScreenAwakeChanged(v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Auto-Optimize for Battery', style: textTheme.labelLarge),
            subtitle: Text('Dim brightness when battery is low',
                style: textTheme.bodySmall),
            value: autoOptimizeBrightness,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onAutoOptimizeChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
