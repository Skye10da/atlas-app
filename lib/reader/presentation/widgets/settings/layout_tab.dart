import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
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
    this.pageFlipGestureZone = PageFlipGestureZone.fullScreen,
    this.enablePageFlipSound = false,
    this.enablePageFlipHaptics = true,
    this.scrollAnimation,
    this.chromeStyle = ReaderChromeStyle.translucent,
    this.desktopSheetPresentation = DesktopSheetPresentation.dialog,
    required this.horizontalPadding,
    required this.useBookSpread,
    required this.onReadingModeChanged,
    required this.onKeepScreenAwakeChanged,
    required this.onBrightnessChanged,
    required this.onAutoOptimizeChanged,
    required this.onFollowSystemBrightnessChanged,
    this.onPageTurnAnimationChanged,
    this.onPageFlipGestureZoneChanged,
    this.onEnablePageFlipSoundChanged,
    this.onEnablePageFlipHapticsChanged,
    this.onScrollAnimationChanged,
    this.onChromeStyleChanged,
    this.onDesktopSheetPresentationChanged,
    required this.onHorizontalPaddingChanged,
    required this.onUseBookSpreadChanged,
  });

  final ReadingMode readingMode;
  final bool keepScreenAwake;
  final double brightness;
  final bool autoOptimizeBrightness;
  final bool followSystemBrightness;
  final PageTurnAnimation? pageTurnAnimation;
  final PageFlipGestureZone pageFlipGestureZone;
  final bool enablePageFlipSound;
  final bool enablePageFlipHaptics;
  final ScrollAnimation? scrollAnimation;
  final ReaderChromeStyle chromeStyle;
  final DesktopSheetPresentation desktopSheetPresentation;
  final double horizontalPadding;
  final bool useBookSpread;

  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<bool> onKeepScreenAwakeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<bool> onAutoOptimizeChanged;
  final ValueChanged<bool> onFollowSystemBrightnessChanged;
  final ValueChanged<PageTurnAnimation>? onPageTurnAnimationChanged;
  final ValueChanged<PageFlipGestureZone>? onPageFlipGestureZoneChanged;
  final ValueChanged<bool>? onEnablePageFlipSoundChanged;
  final ValueChanged<bool>? onEnablePageFlipHapticsChanged;
  final ValueChanged<ScrollAnimation>? onScrollAnimationChanged;
  final ValueChanged<ReaderChromeStyle>? onChromeStyleChanged;
  final ValueChanged<DesktopSheetPresentation>?
  onDesktopSheetPresentationChanged;
  final ValueChanged<double> onHorizontalPaddingChanged;
  final ValueChanged<bool> onUseBookSpreadChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Page Turn / Scroll Animation
          if (readingMode == ReadingMode.page || readingMode == ReadingMode.realFlip) ...[
            if (readingMode == ReadingMode.page) ...[
              const AppSectionHeader(title: 'Page Turn Animation'),
              const SizedBox(height: 4),
              Text(
                'Visual transition effect when flipping between pages',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  (PageTurnAnimation.realFlip, 'Page Flip', Icons.auto_stories, 'Physics-based 3D paper fold with sound & haptics'),
                  (PageTurnAnimation.slide, 'Slide', Icons.swap_horiz, 'Smooth horizontal transition'),
                  (PageTurnAnimation.fade, 'Fade', Icons.blur_on, 'Soft dissolve between pages'),
                  (PageTurnAnimation.reveal, 'Reveal', Icons.layers, 'Page slides over background'),
                  (PageTurnAnimation.cube, 'Cube', Icons.view_in_ar, '3D cube rotation'),
                ].map((entry) {
                  final isSelected = pageTurnAnimation == entry.$1;
                  return _AnimationCard(
                    title: entry.$2,
                    subtitle: entry.$4,
                    icon: entry.$3,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onPageTurnAnimationChanged?.call(entry.$1);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Edge Drag / Turn Zones
            const AppSectionHeader(title: 'Edge Drag / Turn Zones'),
            const SizedBox(height: 4),
            Text(
              'Configure swipe active zones to prevent accidental turns while selecting text',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (
                  PageFlipGestureZone.fullScreen,
                  PageFlipGestureZone.fullScreen.label,
                  PageFlipGestureZone.fullScreen.icon,
                  PageFlipGestureZone.fullScreen.description,
                ),
                (
                  PageFlipGestureZone.edgesOnly,
                  PageFlipGestureZone.edgesOnly.label,
                  PageFlipGestureZone.edgesOnly.icon,
                  PageFlipGestureZone.edgesOnly.description,
                ),
              ].map((entry) {
                final isSelected = pageFlipGestureZone == entry.$1;
                return _AnimationCard(
                  title: entry.$2,
                  subtitle: entry.$4,
                  icon: entry.$3,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPageFlipGestureZoneChanged?.call(entry.$1);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),

            // Sensory Controls (Sound & Haptics)
            const AppSectionHeader(title: 'Sensory Controls'),
            const SizedBox(height: 4),
            Text(
              'Physical page-turn sound effects and tactile feedback',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SwitchListTile(
              title: const Text('Page Turn Sound', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Play authentic paper rustle sound matching swipe speed', style: TextStyle(fontSize: 11)),
              secondary: const Icon(Icons.volume_up_outlined),
              value: enablePageFlipSound,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onEnablePageFlipSoundChanged?.call(v);
              },
            ),
            SwitchListTile(
              title: const Text('Haptic Feedback', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Tactile paper fold feedback during page drag', style: TextStyle(fontSize: 11)),
              secondary: const Icon(Icons.vibration),
              value: enablePageFlipHaptics,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onEnablePageFlipHapticsChanged?.call(v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (readingMode == ReadingMode.continuous) ...[
            const AppSectionHeader(title: 'Scroll Animation'),
            const SizedBox(height: 4),
            Text(
              'Physics and visual effects for vertical text scrolling',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (ScrollAnimation.smooth, 'Smooth', Icons.swap_vert, 'Natural inertial momentum'),
                (ScrollAnimation.snap, 'Snap', Icons.vertical_align_center, 'Snaps to paragraph bounds'),
                (ScrollAnimation.fadeEdges, 'Fade Edges', Icons.blur_linear, 'Soft gradient at viewport edges'),
                (ScrollAnimation.parallax, 'Parallax', Icons.view_carousel, 'Subtle layered depth'),
                (ScrollAnimation.glow, 'Glow', Icons.touch_app, 'Overscroll edge illumination'),
              ].map((entry) {
                final isSelected = scrollAnimation == entry.$1;
                return _AnimationCard(
                  title: entry.$2,
                  subtitle: entry.$4,
                  icon: entry.$3,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onScrollAnimationChanged?.call(entry.$1);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
          ],

          // 2. Reader Chrome Style
          const AppSectionHeader(title: 'Toolbars & Controls Style'),
          const SizedBox(height: 4),
          Text(
            'Visual appearance of top and bottom reading toolbars',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              (ReaderChromeStyle.translucent, 'Translucent', Icons.blur_on, 'Subtle tint overlay'),
              (ReaderChromeStyle.frosted, 'Frosted Glass', Icons.grain, 'Blur backdrop filter'),
            ].map((entry) {
              final isSelected = chromeStyle == entry.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChromeStyleChanged?.call(entry.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                entry.$3,
                                size: 18,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(Icons.check, size: 16, color: colorScheme.primary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            entry.$4,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // Reading Width & Margins
          const AppSectionHeader(title: 'Reading Width & Margins'),
          const SizedBox(height: 4),
          Text(
            'Control the horizontal padding around your text content',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Horizontal Padding', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                '${horizontalPadding.round()} dp',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.format_indent_decrease, size: 18, color: colorScheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: horizontalPadding.clamp(0.0, 80.0),
                  min: 0.0,
                  max: 80.0,
                  divisions: 16,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onHorizontalPaddingChanged(v);
                  },
                ),
              ),
              Icon(Icons.format_indent_increase, size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // Two-Page Book Spread (Page & Real Flip mode, desktop)
          if (readingMode == ReadingMode.page || readingMode == ReadingMode.realFlip) ...[
            const AppSectionHeader(title: 'Two-Page Spread'),
            const SizedBox(height: 4),
            Text(
              'Show side-by-side pages on wide desktop screens (≥ 1200dp)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SwitchListTile(
              title: const Text('Book Spread View', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Display two pages side by side like an open book on wide screens', style: TextStyle(fontSize: 11)),
              secondary: const Icon(Icons.menu_book),
              value: useBookSpread,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onUseBookSpreadChanged(v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
          ],

          // 3. Screen & Brightness
          const AppSectionHeader(title: 'Display & Battery'),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile(
            title: const Text('Keep Screen Awake', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Prevent display from timing out or dimming while reading', style: TextStyle(fontSize: 11)),
            secondary: const Icon(Icons.screen_lock_portrait),
            value: keepScreenAwake,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onKeepScreenAwakeChanged(v);
            },
          ),
          SwitchListTile(
            title: const Text('Follow System Brightness', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Use your device system brightness setting', style: TextStyle(fontSize: 11)),
            secondary: const Icon(Icons.brightness_auto),
            value: followSystemBrightness,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onFollowSystemBrightnessChanged(v);
            },
          ),

          if (!followSystemBrightness) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('In-App Brightness', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  '${(brightness * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.brightness_low, size: 18),
                Expanded(
                  child: Slider(
                    value: brightness.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) {
                      onBrightnessChanged(v);
                    },
                  ),
                ),
                const Icon(Icons.brightness_high, size: 18),
              ],
            ),
          ],

          // 4. Desktop Presentation (Desktop only)
          if (MediaQuery.sizeOf(context).width >=
              AppSheet.desktopBreakpoint) ...[
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
            const AppSectionHeader(title: 'Desktop Sheet Style'),
            const SizedBox(height: 4),
            Text(
              'Choose how settings sheets and tools appear on large displays',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                (DesktopSheetPresentation.dialog, 'Floating Dialogs', 'Centered overlay modal', Icons.picture_in_picture_alt),
                (DesktopSheetPresentation.sidePanel, 'Side Panels', 'Docked right sidebar', Icons.dock),
              ].map((entry) {
                final isSelected = desktopSheetPresentation == entry.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onDesktopSheetPresentationChanged?.call(entry.$1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(alpha: 0.4),
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              entry.$4,
                              size: 18,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              entry.$3,
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected
                                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimationCard extends StatelessWidget {
  const _AnimationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 155,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check, size: 16, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isSelected
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
