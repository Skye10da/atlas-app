import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/layout_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/text_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_tab.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ReaderSettingsSheet extends ConsumerStatefulWidget {
  const ReaderSettingsSheet({super.key, required this.initialSettings});

  final ReadingSettingsEntity initialSettings;

  @override
  ConsumerState<ReaderSettingsSheet> createState() =>
      _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends ConsumerState<ReaderSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _fontSize;
  late String? _fontFamily;
  late double _lineHeight;
  late double _letterSpacing;
  late ReadingViewTheme _theme;
  late ReadingMode _readingMode;
  late TextAlignment _textAlignment;
  late MarginPreset _marginPreset;
  late bool _keepScreenAwake;
  late double _brightness;
  late bool _autoOptimizeBrightness;
  late bool _followSystemBrightness;
  late PageTurnAnimation _pageTurnAnimation;
  late ScrollAnimation _scrollAnimation;
  late ReaderChromeStyle _chromeStyle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final s = widget.initialSettings;
    _fontSize = s.fontSize;
    _fontFamily = s.fontFamily;
    _lineHeight = s.lineHeight;
    _letterSpacing = s.letterSpacing;
    _theme = s.theme;
    _readingMode = s.readingMode;
    _textAlignment = s.textAlignment;
    _marginPreset = s.marginPreset;
    _keepScreenAwake = s.keepScreenAwake;
    _brightness = s.brightness;
    _autoOptimizeBrightness = s.autoOptimizeBrightness;
    _followSystemBrightness = s.followSystemBrightness;
    _pageTurnAnimation = s.pageTurnAnimation;
    _scrollAnimation = s.scrollAnimation;
    _chromeStyle = s.chromeStyle;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(readingSettingsProvider.notifier);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Reading Settings',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TabBar(
              controller: _tabController,
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
              indicatorColor: colors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.palette, size: 20), text: 'Theme'),
                Tab(icon: Icon(Icons.text_fields, size: 20), text: 'Text'),
                Tab(icon: Icon(Icons.view_quilt, size: 20), text: 'Layout'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 360,
              child: TabBarView(
                controller: _tabController,
                children: [
                  ThemeTab(
                    theme: _theme,
                    marginPreset: _marginPreset,
                    onThemeChanged: (t) {
                      setState(() => _theme = t);
                      notifier.setTheme(t);
                    },
                    onMarginPresetChanged: (p) {
                      setState(() => _marginPreset = p);
                      notifier.setMarginPreset(p);
                    },
                  ),
                  TextTab(
                    fontSize: _fontSize,
                    fontFamily: _fontFamily,
                    textAlignment: _textAlignment,
                    lineHeight: _lineHeight,
                    letterSpacing: _letterSpacing,
                    onFontSizeChanged: (v) {
                      setState(() => _fontSize = v);
                      notifier.setFontSize(v);
                    },
                    onFontFamilyChanged: (v) {
                      setState(() => _fontFamily = v);
                      notifier.setFontFamily(v);
                    },
                    onTextAlignmentChanged: (v) {
                      setState(() => _textAlignment = v);
                      notifier.setTextAlignment(v);
                    },
                    onLineHeightChanged: (v) {
                      setState(() => _lineHeight = v);
                      notifier.setLineHeight(v);
                    },
                    onLetterSpacingChanged: (v) {
                      setState(() => _letterSpacing = v);
                      notifier.setLetterSpacing(v);
                    },
                  ),
                  LayoutTab(
                    readingMode: _readingMode,
                    keepScreenAwake: _keepScreenAwake,
                    brightness: _brightness,
                    autoOptimizeBrightness: _autoOptimizeBrightness,
                    followSystemBrightness: _followSystemBrightness,
                    pageTurnAnimation: _pageTurnAnimation,
                    scrollAnimation: _scrollAnimation,
                    chromeStyle: _chromeStyle,
                    onReadingModeChanged: (m) {
                      setState(() => _readingMode = m);
                      notifier.setReadingMode(m);
                    },
                    onPageTurnAnimationChanged: (a) {
                      setState(() => _pageTurnAnimation = a);
                      notifier.setPageTurnAnimation(a);
                    },
                    onScrollAnimationChanged: (a) {
                      setState(() => _scrollAnimation = a);
                      notifier.setScrollAnimation(a);
                    },
                    onChromeStyleChanged: (s) {
                      setState(() => _chromeStyle = s);
                      notifier.setChromeStyle(s);
                    },
                    onKeepScreenAwakeChanged: (v) {
                      setState(() => _keepScreenAwake = v);
                      notifier.setKeepScreenAwake(v);
                    },
                    onBrightnessChanged: (v) {
                      setState(() => _brightness = v);
                      notifier.setBrightness(v);
                    },
                    onAutoOptimizeChanged: (v) {
                      setState(() => _autoOptimizeBrightness = v);
                      notifier.setAutoOptimizeBrightness(v);
                    },
                    onFollowSystemBrightnessChanged: (v) {
                      setState(() => _followSystemBrightness = v);
                      notifier.setFollowSystemBrightness(v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
