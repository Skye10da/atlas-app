import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/molecules/icon_controls.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

/// Reader "Display" tab — icon-first: page-turn style, gesture zones,
/// sensory feedback, scroll feel and screen controls are all glyph-driven;
/// the power-user knobs (toolbar style, padding, content cards, book
/// spread, desktop sheet style) sink behind an [AdvancedDisclosure].
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
    this.enableBlockCards = true,
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
    this.onEnableBlockCardsChanged,
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
  final bool enableBlockCards;

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
  final ValueChanged<bool>? onEnableBlockCardsChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Bead + micro-label: the glyph explains, the label confirms.
    Widget beadRow({required IconToggleBead bead, required String label}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          bead,
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Page Turn / Scroll Animation + gesture zones (paged modes).
          if (readingMode == ReadingMode.page ||
              readingMode == ReadingMode.realFlip) ...[
            if (readingMode == ReadingMode.page) ...[
              const AppSectionHeader(title: 'Page Turn Animation'),
              const SizedBox(height: AppSpacing.sm),
              IconSegment<PageTurnAnimation>(
                options: const [
                  IconSegmentOption(
                    PageTurnAnimation.realFlip,
                    label: 'Page Flip',
                    icon: Icons.auto_stories,
                  ),
                  IconSegmentOption(
                    PageTurnAnimation.slide,
                    label: 'Slide',
                    icon: Icons.swap_horiz,
                  ),
                  IconSegmentOption(
                    PageTurnAnimation.fade,
                    label: 'Fade',
                    icon: Icons.blur_on,
                  ),
                  IconSegmentOption(
                    PageTurnAnimation.reveal,
                    label: 'Reveal',
                    icon: Icons.layers,
                  ),
                  IconSegmentOption(
                    PageTurnAnimation.cube,
                    label: 'Cube',
                    icon: Icons.view_in_ar,
                  ),
                ],
                selected: pageTurnAnimation ?? PageTurnAnimation.realFlip,
                onSelected: (a) => onPageTurnAnimationChanged?.call(a),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const AppSectionHeader(title: 'Edge Drag / Turn Zones'),
            const SizedBox(height: AppSpacing.sm),
            IconSegment<PageFlipGestureZone>(
              options: [
                IconSegmentOption(
                  PageFlipGestureZone.fullScreen,
                  label: PageFlipGestureZone.fullScreen.label,
                  icon: PageFlipGestureZone.fullScreen.icon,
                ),
                IconSegmentOption(
                  PageFlipGestureZone.edgesOnly,
                  label: PageFlipGestureZone.edgesOnly.label,
                  icon: PageFlipGestureZone.edgesOnly.icon,
                ),
              ],
              selected: pageFlipGestureZone,
              onSelected: (z) => onPageFlipGestureZoneChanged?.call(z),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),

            // Sensory controls: sound & haptics beads.
            const AppSectionHeader(title: 'Sensory Controls'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                beadRow(
                  label: 'Page turn sound',
                  bead: IconToggleBead(
                    active: enablePageFlipSound,
                    label: 'Page turn sound',
                    activeIcon: Icons.volume_up_rounded,
                    inactiveIcon: Icons.volume_off_rounded,
                    onChanged: (v) => onEnablePageFlipSoundChanged?.call(v),
                  ),
                ),
                beadRow(
                  label: 'Haptics feedback',
                  bead: IconToggleBead(
                    active: enablePageFlipHaptics,
                    label: 'Haptics feedback',
                    activeIcon: Icons.vibration_rounded,
                    onChanged: (v) => onEnablePageFlipHapticsChanged?.call(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (readingMode == ReadingMode.continuous) ...[
            const AppSectionHeader(title: 'Scroll Animation'),
            const SizedBox(height: AppSpacing.sm),
            IconSegment<ScrollAnimation>(
              options: const [
                IconSegmentOption(
                  ScrollAnimation.smooth,
                  label: 'Smooth',
                  icon: Icons.swap_vert,
                ),
                IconSegmentOption(
                  ScrollAnimation.snap,
                  label: 'Snap',
                  icon: Icons.vertical_align_center,
                ),
                IconSegmentOption(
                  ScrollAnimation.fadeEdges,
                  label: 'Fade Edges',
                  icon: Icons.blur_linear,
                ),
                IconSegmentOption(
                  ScrollAnimation.parallax,
                  label: 'Parallax',
                  icon: Icons.view_carousel,
                ),
                IconSegmentOption(
                  ScrollAnimation.glow,
                  label: 'Glow',
                  icon: Icons.touch_app,
                ),
              ],
              selected: scrollAnimation ?? ScrollAnimation.smooth,
              onSelected: (a) => onScrollAnimationChanged?.call(a),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
          ],

          // 2. Screen & brightness: keep-awake + system-brightness beads and
          // an icon-flanked slider.
          const AppSectionHeader(title: 'Display & Battery'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              beadRow(
                label: 'Keep screen awake',
                bead: IconToggleBead(
                  active: keepScreenAwake,
                  label: 'Keep screen awake',
                  activeIcon: Icons.lightbulb_rounded,
                  inactiveIcon: Icons.lightbulb_outline_rounded,
                  onChanged: onKeepScreenAwakeChanged,
                ),
              ),
              beadRow(
                label: 'System brightness',
                bead: IconToggleBead(
                  active: followSystemBrightness,
                  label: 'Follow system brightness',
                  activeIcon: Icons.brightness_auto_rounded,
                  inactiveIcon: Icons.brightness_medium_rounded,
                  onChanged: onFollowSystemBrightnessChanged,
                ),
              ),
            ],
          ),
          if (!followSystemBrightness) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.brightness_low_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Slider(
                    value: brightness.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: onBrightnessChanged,
                  ),
                ),
                Icon(
                  Icons.brightness_high_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // 3. Advanced — power-user knobs.
          AdvancedDisclosure(
            label: 'Advanced display',
            children: [
              const AppDivider(),
              const SizedBox(height: AppSpacing.sm),
              const AppSectionHeader(title: 'Toolbars & Controls Style'),
              const SizedBox(height: AppSpacing.sm),
              IconSegment<ReaderChromeStyle>(
                options: const [
                  IconSegmentOption(
                    ReaderChromeStyle.translucent,
                    label: 'Translucent',
                    icon: Icons.blur_on,
                  ),
                  IconSegmentOption(
                    ReaderChromeStyle.frosted,
                    label: 'Frosted',
                    icon: Icons.grain,
                  ),
                  IconSegmentOption(
                    ReaderChromeStyle.glass,
                    label: 'Liquid',
                    icon: Icons.auto_awesome,
                  ),
                ],
                selected: chromeStyle,
                onSelected: (s) => onChromeStyleChanged?.call(s),
              ),

              const SizedBox(height: AppSpacing.md),
              const AppDivider(),
              const SizedBox(height: AppSpacing.sm),

              const AppSectionHeader(title: 'Reading Width & Margins'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.format_indent_decrease,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
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
                  Icon(
                    Icons.format_indent_increase,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              const AppDivider(),
              const SizedBox(height: AppSpacing.sm),

              const AppSectionHeader(title: 'Content Cards'),
              const SizedBox(height: AppSpacing.xs),
              beadRow(
                label: 'Block cards',
                bead: IconToggleBead(
                  active: enableBlockCards,
                  label: 'Block cards',
                  activeIcon: Icons.dashboard_customize_rounded,
                  onChanged: (v) => onEnableBlockCardsChanged?.call(v),
                ),
              ),

              // Two-Page Book Spread (Page & Real Flip mode, desktop).
              if (readingMode == ReadingMode.page ||
                  readingMode == ReadingMode.realFlip) ...[
                const SizedBox(height: AppSpacing.md),
                const AppDivider(),
                const SizedBox(height: AppSpacing.sm),
                const AppSectionHeader(title: 'Two-Page Spread'),
                const SizedBox(height: AppSpacing.xs),
                beadRow(
                  label: 'Book spread view',
                  bead: IconToggleBead(
                    active: useBookSpread,
                    label: 'Book spread view',
                    activeIcon: Icons.menu_book_rounded,
                    onChanged: onUseBookSpreadChanged,
                  ),
                ),
              ],

              // Desktop Presentation (Desktop only).
              if (MediaQuery.sizeOf(context).width >=
                  AppSheet.desktopBreakpoint) ...[
                const SizedBox(height: AppSpacing.md),
                const AppDivider(),
                const SizedBox(height: AppSpacing.sm),
                const AppSectionHeader(title: 'Desktop Sheet Style'),
                const SizedBox(height: AppSpacing.sm),
                IconSegment<DesktopSheetPresentation>(
                  options: const [
                    IconSegmentOption(
                      DesktopSheetPresentation.dialog,
                      label: 'Dialogs',
                      icon: Icons.picture_in_picture_alt,
                    ),
                    IconSegmentOption(
                      DesktopSheetPresentation.sidePanel,
                      label: 'Side Panels',
                      icon: Icons.dock,
                    ),
                  ],
                  selected: desktopSheetPresentation,
                  onSelected: (p) => onDesktopSheetPresentationChanged?.call(p),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
