import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/reading_preset.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/glossary_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/language_selector.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/layout_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/reader_settings_preview_card.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/text_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_tab.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/screens/font_manager_screen.dart';
import 'package:atlas_app/wtr/presentation/widgets/wtr_translation_selector.dart';

class ReaderSettingsSheet extends HookConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 4);

    final fontSize = useState(initialSettings.fontSize);
    final fontFamily = useState(initialSettings.fontFamily);
    final fontWeight = useState(initialSettings.fontWeight);
    final lineHeight = useState(initialSettings.lineHeight);
    final letterSpacing = useState(initialSettings.letterSpacing);
    final theme = useState(initialSettings.theme);
    final readingMode = useState(initialSettings.readingMode);
    final textAlignment = useState(initialSettings.textAlignment);
    final marginPreset = useState(initialSettings.marginPreset);
    final keepScreenAwake = useState(initialSettings.keepScreenAwake);
    final brightness = useState(initialSettings.brightness);
    final autoOptimizeBrightness =
        useState(initialSettings.autoOptimizeBrightness);
    final followSystemBrightness =
        useState(initialSettings.followSystemBrightness);
    final pageTurnAnimation = useState(initialSettings.pageTurnAnimation);
    final pageFlipGestureZone = useState(initialSettings.pageFlipGestureZone);
    final scrollAnimation = useState(initialSettings.scrollAnimation);
    final chromeStyle = useState(initialSettings.chromeStyle);
    final desktopSheetPresentation =
        useState(initialSettings.desktopSheetPresentation);
    final horizontalPadding = useState(initialSettings.horizontalPadding);
    final useBookSpread = useState(initialSettings.useBookSpread);
    final enablePageFlipSound = useState(initialSettings.enablePageFlipSound);
    final enablePageFlipHaptics = useState(initialSettings.enablePageFlipHaptics);

    final bool hasWtrTab = rawId != null;

    Future<void> onWtrServiceChanged() async {
      final repo = ref.read(readerRepositoryProvider);
      await repo.resetChapterContent(bookId);
      ref.invalidate(readerChapterContentProvider);
    }

    Future<void> onLanguageChanged() async {
      if (hasWtrTab) {
        final repo = ref.read(readerRepositoryProvider);
        await repo.resetChapterContent(bookId);
      }
      ref.invalidate(readerChapterContentProvider);
    }

    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(readingSettingsProvider.notifier);
    final fontFamilies =
        ref.watch(availableFontFamiliesProvider).valueOrNull ?? [];

    void handleApplyPreset(ReadingPreset preset) {
      theme.value = preset.theme;
      fontFamily.value = preset.fontFamily;
      fontSize.value = preset.fontSize;
      lineHeight.value = preset.lineHeight;
      letterSpacing.value = preset.letterSpacing;
      textAlignment.value = preset.textAlignment;
      marginPreset.value = preset.marginPreset;
      fontWeight.value = preset.fontWeight;

      notifier.setTheme(preset.theme);
      notifier.setFontFamily(preset.fontFamily);
      notifier.setFontSize(preset.fontSize);
      notifier.setLineHeight(preset.lineHeight);
      notifier.setLetterSpacing(preset.letterSpacing);
      notifier.setTextAlignment(preset.textAlignment);
      notifier.setMarginPreset(preset.marginPreset);
      notifier.setFontWeight(preset.fontWeight);
    }

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Live Interactive Reading Preview Card
          ReaderSettingsPreviewCard(
            theme: theme.value,
            fontSize: fontSize.value,
            fontFamily: fontFamily.value,
            fontWeight: fontWeight.value,
            lineHeight: lineHeight.value,
            letterSpacing: letterSpacing.value,
            textAlignment: textAlignment.value,
            marginPreset: marginPreset.value,
          ),
          const SizedBox(height: AppSpacing.xs),

          // Primary Category Tab Bar
          TabBar(
            controller: tabController,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
            indicatorColor: colors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: const [
              Tab(
                icon: Icon(Icons.palette_outlined, size: 18),
                text: 'Style',
              ),
              Tab(
                icon: Icon(Icons.text_fields_outlined, size: 18),
                text: 'Typography',
              ),
              Tab(
                icon: Icon(Icons.tune_outlined, size: 18),
                text: 'Display',
              ),
              Tab(
                icon: Icon(Icons.translate_outlined, size: 18),
                text: 'Translate',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Category Content View
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                ThemeTab(
                  theme: theme.value,
                  fontSize: fontSize.value,
                  fontFamily: fontFamily.value,
                  fontWeight: fontWeight.value,
                  lineHeight: lineHeight.value,
                  readingMode: readingMode.value,
                  marginPreset: marginPreset.value,
                  onApplyPreset: handleApplyPreset,
                  onThemeChanged: (t) {
                    theme.value = t;
                    notifier.setTheme(t);
                  },
                  onFontSizeChanged: (v) {
                    fontSize.value = v;
                    notifier.setFontSize(v);
                  },
                  onFontFamilyChanged: (v) {
                    fontFamily.value = v;
                    notifier.setFontFamily(v);
                  },
                  onLineHeightChanged: (v) {
                    lineHeight.value = v;
                    notifier.setLineHeight(v);
                  },
                  onReadingModeChanged: (m) {
                    readingMode.value = m;
                    notifier.setReadingMode(m);
                  },
                  onMarginPresetChanged: (p) {
                    marginPreset.value = p;
                    notifier.setMarginPreset(p);
                  },
                ),
                TextTab(
                  fontSize: fontSize.value,
                  fontFamily: fontFamily.value,
                  fontWeight: fontWeight.value,
                  textAlignment: textAlignment.value,
                  lineHeight: lineHeight.value,
                  letterSpacing: letterSpacing.value,
                  marginPreset: marginPreset.value,
                  fontFamilies: fontFamilies,
                  onDownloadMore: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FontManagerScreen(),
                    ),
                  ),
                  onFontSizeChanged: (v) {
                    fontSize.value = v;
                    notifier.setFontSize(v);
                  },
                  onFontFamilyChanged: (v) {
                    fontFamily.value = v;
                    notifier.setFontFamily(v);
                  },
                  onFontWeightChanged: (v) {
                    fontWeight.value = v;
                    notifier.setFontWeight(v);
                  },
                  onTextAlignmentChanged: (v) {
                    textAlignment.value = v;
                    notifier.setTextAlignment(v);
                  },
                  onLineHeightChanged: (v) {
                    lineHeight.value = v;
                    notifier.setLineHeight(v);
                  },
                  onLetterSpacingChanged: (v) {
                    letterSpacing.value = v;
                    notifier.setLetterSpacing(v);
                  },
                  onMarginPresetChanged: (p) {
                    marginPreset.value = p;
                    notifier.setMarginPreset(p);
                  },
                ),
                LayoutTab(
                  readingMode: readingMode.value,
                  keepScreenAwake: keepScreenAwake.value,
                  brightness: brightness.value,
                  autoOptimizeBrightness: autoOptimizeBrightness.value,
                  followSystemBrightness: followSystemBrightness.value,
                  pageTurnAnimation: pageTurnAnimation.value,
                  pageFlipGestureZone: pageFlipGestureZone.value,
                  enablePageFlipSound: enablePageFlipSound.value,
                  enablePageFlipHaptics: enablePageFlipHaptics.value,
                  scrollAnimation: scrollAnimation.value,
                  chromeStyle: chromeStyle.value,
                  desktopSheetPresentation: desktopSheetPresentation.value,
                  horizontalPadding: horizontalPadding.value,
                  useBookSpread: useBookSpread.value,
                  onReadingModeChanged: (m) {
                    readingMode.value = m;
                    notifier.setReadingMode(m);
                  },
                  onHorizontalPaddingChanged: (p) {
                    horizontalPadding.value = p;
                    notifier.setHorizontalPadding(p);
                  },
                  onUseBookSpreadChanged: (v) {
                    useBookSpread.value = v;
                    notifier.setUseBookSpread(v);
                  },
                  onPageTurnAnimationChanged: (a) {
                    pageTurnAnimation.value = a;
                    notifier.setPageTurnAnimation(a);
                  },
                  onPageFlipGestureZoneChanged: (z) {
                    pageFlipGestureZone.value = z;
                    notifier.setPageFlipGestureZone(z);
                  },
                  onEnablePageFlipSoundChanged: (s) {
                    enablePageFlipSound.value = s;
                    notifier.setPageFlipSound(s);
                  },
                  onEnablePageFlipHapticsChanged: (h) {
                    enablePageFlipHaptics.value = h;
                    notifier.setPageFlipHaptics(h);
                  },
                  onScrollAnimationChanged: (a) {
                    scrollAnimation.value = a;
                    notifier.setScrollAnimation(a);
                  },
                  onChromeStyleChanged: (s) {
                    chromeStyle.value = s;
                    notifier.setChromeStyle(s);
                  },
                  onDesktopSheetPresentationChanged: (p) {
                    desktopSheetPresentation.value = p;
                    notifier.setDesktopSheetPresentation(p);
                  },
                  onKeepScreenAwakeChanged: (v) {
                    keepScreenAwake.value = v;
                    notifier.setKeepScreenAwake(v);
                  },
                  onBrightnessChanged: (v) {
                    brightness.value = v;
                    notifier.setBrightness(v);
                  },
                  onAutoOptimizeChanged: (v) {
                    autoOptimizeBrightness.value = v;
                    notifier.setAutoOptimizeBrightness(v);
                  },
                  onFollowSystemBrightnessChanged: (v) {
                    followSystemBrightness.value = v;
                    notifier.setFollowSystemBrightness(v);
                  },
                ),
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasWtrTab) ...[
                          WtrTranslationSelector(
                            rawId: rawId!,
                            onServiceChanged: onWtrServiceChanged,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          LanguageSelector(
                            bookId: bookId,
                            onLanguageChanged: onLanguageChanged,
                          ),
                        ] else ...[
                          _TranslationToggle(bookId: bookId),
                          const SizedBox(height: AppSpacing.sm),
                          LanguageSelector(
                            bookId: bookId,
                            onLanguageChanged: onLanguageChanged,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.sm),
                        GlossaryTab(bookId: bookId),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
