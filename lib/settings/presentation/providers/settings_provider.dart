import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/infrastructure/repositories/shared_prefs_settings_repository.dart';

final settingsRepositoryProvider = Provider((ref) {
  return const SharedPrefsSettingsRepository();
});

final readingSettingsProvider =
    StateNotifierProvider<
      ReadingSettingsNotifier,
      AsyncValue<ReadingSettingsEntity>
    >((ref) {
      final repo = ref.watch(settingsRepositoryProvider);
      return ReadingSettingsNotifier(repo);
    });

class ReadingSettingsNotifier
    extends StateNotifier<AsyncValue<ReadingSettingsEntity>> {
  ReadingSettingsNotifier(this._repo) : super(const AsyncLoading()) {
    _init();
  }

  final SharedPrefsSettingsRepository _repo;

  Future<void> _init() async {
    final settings = await _repo.load();
    _apply(settings);
  }

  /// Publishes [settings] and mirrors presentation prefs onto the design
  /// system's static sheet config, which call sites read without a widget
  /// rebuild dependency.
  void _apply(ReadingSettingsEntity settings) {
    AppSheet.desktopPresentation = settings.desktopSheetPresentation;
    state = AsyncData(settings);
  }

  Future<void> setDesktopSheetPresentation(
    DesktopSheetPresentation value,
  ) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(desktopSheetPresentation: value);
    _apply(updated);
    await _repo.save(updated);
  }

  Future<void> setSystemFontFamily(String? fontFamily) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(systemFontFamily: fontFamily);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setBrand(AppBrand brand) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(brand: brand);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setFontSize(double size) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(fontSize: size.clamp(12.0, 32.0));
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setFontFamily(String? fontFamily) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(fontFamily: fontFamily);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setFontWeight(int? weight) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(fontWeight: weight);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setLineHeight(double height) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(lineHeight: height.clamp(1.0, 2.0));
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setTheme(ReadingViewTheme theme) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(theme: theme);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setReadingMode(ReadingMode mode) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(readingMode: mode);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setTextAlignment(TextAlignment alignment) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(textAlignment: alignment);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setMarginPreset(MarginPreset preset) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(marginPreset: preset);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setLetterSpacing(double spacing) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(letterSpacing: spacing.clamp(0.0, 5.0));
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setKeepScreenAwake(bool value) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(keepScreenAwake: value);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setBrightness(double value) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(brightness: value.clamp(0.0, 1.0));
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setAutoOptimizeBrightness(bool value) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(autoOptimizeBrightness: value);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setFollowSystemBrightness(bool value) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(followSystemBrightness: value);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setPageTurnAnimation(PageTurnAnimation animation) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(pageTurnAnimation: animation);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setScrollAnimation(ScrollAnimation animation) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(scrollAnimation: animation);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setChromeStyle(ReaderChromeStyle style) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(chromeStyle: style);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull ?? const ReadingSettingsEntity();
    final updated = current.copyWith(themeMode: mode);
    state = AsyncData(updated);
    await _repo.save(updated);
  }
}
