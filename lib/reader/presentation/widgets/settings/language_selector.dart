import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

/// Picks the target language a novel's text is translated into.
///
/// Applies to the WTR Web / WebPlus on-device translation (the AI service is
/// always English) and to the reader-wide translation toggle for non-WTR
/// novels. The choice persists per book; [onLanguageChanged] fires only when
/// the selection actually changes so hosts can drop stale translated content.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({
    super.key,
    required this.bookId,
    this.onLanguageChanged,
  });

  /// The book being read — keys the persisted language preference.
  final String bookId;

  /// Invoked when the user picks a *different* language.
  final VoidCallback? onLanguageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(targetLanguageProvider(bookId)).valueOrNull;
    final languagesAsync = ref.watch(supportedLanguagesProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final effectiveSelected =
        selected ??
        SupportedLanguage.defaults.firstWhere((l) => l.code == 'en');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target language',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              CountryFlag.fromLanguageCode(
                effectiveSelected.code,
                theme: const ImageTheme(width: 24, height: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: languagesAsync.when(
                  loading: () => const Text('Loading languages...'),
                  error: (e, _) => _buildDropdown(
                    context,
                    ref,
                    effectiveSelected,
                    SupportedLanguage.defaults,
                  ),
                  data: (languages) => _buildDropdown(
                    context,
                    ref,
                    effectiveSelected,
                    languages,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    WidgetRef ref,
    SupportedLanguage? selected,
    List<SupportedLanguage> languages,
  ) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<SupportedLanguage>(
        value: selected,
        isExpanded: true,
        items: [
          for (final language in languages)
            DropdownMenuItem(
              value: language,
              child: Row(
                children: [
                  CountryFlag.fromLanguageCode(
                    language.code,
                    theme: const ImageTheme(width: 24, height: 16),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${language.nativeName} (${language.name})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (language) {
          if (language == null) return;
          final changed = language != selected;
          ref
              .read(translationControllerProvider)
              .setTargetLanguage(bookId, language);
          ref.invalidate(targetLanguageProvider(bookId));
          if (changed) onLanguageChanged?.call();
        },
      ),
    );
  }
}
