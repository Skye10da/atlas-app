import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/glossary_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/language_selector.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/layout_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/text_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_tab.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/screens/font_manager_screen.dart';
import 'package:atlas_app/wtr/presentation/widgets/wtr_translation_selector.dart';

class ReaderSettingsSheet extends ConsumerStatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.initialSettings,
    required this.bookId,
    this.rawId,
  });

  final ReadingSettingsEntity initialSettings;

  /// The book being read — used to drop stale downloaded chapter text when the
  /// WTR-Lab translation service changes.
  final String bookId;

  /// WTR-Lab raw id when the current book comes from wtr-lab.com; the
  /// translation-service tab only shows for those novels.
  final int? rawId;

  @override
  ConsumerState<ReaderSettingsSheet> createState() =>
      _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends ConsumerState<ReaderSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _fontSize;
  late String? _fontFamily;
  late int? _fontWeight;
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
  late DesktopSheetPresentation _desktopSheetPresentation;

  /// Whether this reader session is reading a WTR-Lab novel, which gains the
  /// translation-service (Web / WebPlus / AI) selector inside the Translate tab.
  bool get _hasWtrTab => widget.rawId != null;

  /// A WTR-Lab translation switch means any stored chapter text was fetched
  /// under the *previous* service. Drop the book's downloaded content and
  /// invalidate every loaded chapter so the reader refetches each one with the
  /// newly selected service.
  Future<void> _onWtrServiceChanged() async {
    final repo = ref.read(readerRepositoryProvider);
    await repo.resetChapterContent(widget.bookId);
    ref.invalidate(readerChapterContentProvider);
  }

  /// Changing the target language (WTR novels) means stored chapters were
  /// fetched under the old language — drop them so the next read refetches
  /// translated. Non-WTR novels translate at read time, so only the loaded
  /// chapters need a rebuild.
  Future<void> _onLanguageChanged() async {
    if (_hasWtrTab) {
      final repo = ref.read(readerRepositoryProvider);
      await repo.resetChapterContent(widget.bookId);
    }
    ref.invalidate(readerChapterContentProvider);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final s = widget.initialSettings;
    _fontSize = s.fontSize;
    _fontFamily = s.fontFamily;
    _fontWeight = s.fontWeight;
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
    _desktopSheetPresentation = s.desktopSheetPresentation;
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
    final fontFamilies =
        ref.watch(availableFontFamiliesProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
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
              tabs: [
                const Tab(
                  icon: Icon(Icons.palette, size: 20),
                  text: 'Appearance',
                ),
                const Tab(
                  icon: Icon(Icons.text_fields, size: 20),
                  text: 'Typography',
                ),
                const Tab(
                  icon: Icon(Icons.view_quilt, size: 20),
                  text: 'Behavior',
                ),
                const Tab(
                  icon: Icon(Icons.translate, size: 20),
                  text: 'Translate',
                ),
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
                    fontWeight: _fontWeight,
                    textAlignment: _textAlignment,
                    lineHeight: _lineHeight,
                    letterSpacing: _letterSpacing,
                    fontFamilies: fontFamilies,
                    onDownloadMore: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FontManagerScreen(),
                      ),
                    ),
                    onFontSizeChanged: (v) {
                      setState(() => _fontSize = v);
                      notifier.setFontSize(v);
                    },
                    onFontFamilyChanged: (v) {
                      setState(() => _fontFamily = v);
                      notifier.setFontFamily(v);
                    },
                    onFontWeightChanged: (v) {
                      setState(() => _fontWeight = v);
                      notifier.setFontWeight(v);
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
                    desktopSheetPresentation: _desktopSheetPresentation,
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
                    onDesktopSheetPresentationChanged: (p) {
                      setState(() => _desktopSheetPresentation = p);
                      notifier.setDesktopSheetPresentation(p);
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
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_hasWtrTab) ...[
                            WtrTranslationSelector(
                              rawId: widget.rawId!,
                              onServiceChanged: _onWtrServiceChanged,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            LanguageSelector(
                              bookId: widget.bookId,
                              onLanguageChanged: _onLanguageChanged,
                            ),
                          ] else ...[
                            _TranslationToggle(bookId: widget.bookId),
                            const SizedBox(height: AppSpacing.sm),
                            LanguageSelector(
                              bookId: widget.bookId,
                              onLanguageChanged: _onLanguageChanged,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.sm),
                          GlossaryTab(bookId: widget.bookId),
                        ],
                      ),
                    ),
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

/// Enables / disables on-device translation for a non-WTR novel. Shown only
/// for books that are not WTR-Lab — those already translate via their Web /
/// WebPlus / AI services, so they get the service selector instead.
class _TranslationToggle extends ConsumerWidget {
  const _TranslationToggle({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final enabled =
        ref.watch(translationEnabledProvider(bookId)).valueOrNull ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        value: enabled,
        title: const Text('Translate this novel'),
        subtitle: const Text(
          'Translate the source text on-device into the target language.',
        ),
        secondary: const Icon(Icons.translate),
        onChanged: (value) async {
          await ref
              .read(translationControllerProvider)
              .setEnabled(bookId, value);
          ref.invalidate(translationEnabledProvider(bookId));
          ref.invalidate(readerChapterContentProvider);
        },
      ),
    );
  }
}
