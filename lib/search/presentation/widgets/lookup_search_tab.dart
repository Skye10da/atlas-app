import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/widgets/sheet_browser.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/dictionary_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/presentation/providers/dictionary_providers.dart';
import 'package:atlas_app/search/domain/entities/search_engine.dart';
import 'package:atlas_app/search/presentation/providers/search_engine_provider.dart';
import 'package:atlas_app/search/presentation/widgets/search_engine_picker.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';

class LookupSearchTab extends HookConsumerWidget {
  const LookupSearchTab({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(text: initialQuery ?? '');
    final source = useState(DictionarySource.wiktionary);
    final language = useState(() {
      var lang = 'en';
      if (!DictionarySource.wiktionary.languages.any((l) => l.code == lang)) {
        lang = DictionarySource.wiktionary.languages.first.code;
      }
      return lang;
    }());
    final result = useState<WiktionaryResult?>(null);
    final loading = useState(false);
    final error = useState<String?>(null);
    final hasSearched = useState(false);
    final saved = useState(false);

    final selectedEngine = ref.watch(selectedSearchEngineProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Future<void> checkSaved(String word) async {
      if (word.isEmpty) {
        saved.value = false;
        return;
      }
      final id = '${word.trim()}_${language.value}';
      final exists = await ref.read(dictionaryRepositoryProvider).exists(id);
      if (context.mounted) saved.value = exists;
    }

    Future<void> lookup() async {
      final word = controller.text.trim();
      if (word.isEmpty) {
        result.value = null;
        error.value = null;
        hasSearched.value = false;
        loading.value = false;
        return;
      }
      // Single word lookup for dictionary; multi-word still shows web search.
      hasSearched.value = true;
      loading.value = true;
      result.value = null;
      error.value = null;
      final svc = ref.read(dictionaryServiceProvider(source.value));
      try {
        final res = await svc.lookup(word, language.value);
        if (!context.mounted) return;
        result.value = res;
        loading.value = false;
        if (res == null) {
          error.value = 'No definition found for "$word".';
        }
      } catch (_) {
        if (!context.mounted) return;
        loading.value = false;
        error.value = 'Could not look up "$word". Check your connection.';
      }
      await checkSaved(word);
    }

    useEffect(() {
      if (initialQuery != null && initialQuery!.trim().isNotEmpty) {
        Future.microtask(lookup);
      }
      return null;
    }, const []);

    Future<void> toggleSave() async {
      final res = result.value;
      if (res == null) return;
      final word = controller.text.trim();
      if (word.isEmpty) return;
      final id = '${word}_${language.value}';
      final repo = ref.read(dictionaryRepositoryProvider);
      await HapticFeedback.lightImpact();
      if (saved.value) {
        await repo.delete(id);
      } else {
        final langLabel = source.value.languages
            .firstWhere(
              (l) => l.code == language.value,
              orElse: () => const WiktionaryLanguage('en', 'English'),
            )
            .label;
        await repo.save(
          DictionaryWordEntity(
            id: id,
            word: word,
            language: language.value,
            languageLabel: langLabel,
            source: source.value.id,
            sourceLabel: source.value.label,
            phonetic: res.phonetic,
            partOfSpeech:
                res.senses.isNotEmpty ? res.senses.first.partOfSpeech : 'unknown',
            definition: res.senses.map((s) => s.definition).join('\n'),
            fullJson: jsonEncode(res.toJson()),
            savedAt: DateTime.now(),
            reviewLevel: 0,
            reviewCount: 0,
          ),
        );
      }
      ref.invalidate(savedWordsProvider);
      if (!context.mounted) return;
      saved.value = !saved.value;
      AppToast.show(
        saved.value ? 'Saved "$word"' : 'Removed from saved words',
        tone: AppToastTone.bookmark,
        duration: const Duration(seconds: 2),
      );
    }

    Future<void> webSearch() async {
      final query = controller.text.trim();
      if (query.isEmpty) return;
      final url = selectedEngine.buildUrl(query);
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await ref
            .read(browserSessionRepositoryProvider)
            .captureForOrigin(uri)
            .catchError((_) {});
      }
      if (!context.mounted) return;
      await showSearchSheetBrowser(context, ref, url);
    }

    void copyDefinition() {
      final res = result.value;
      if (res == null) return;
      final text = res.senses.map((s) => '${s.partOfSpeech}: ${s.definition}').join('\n');
      Clipboard.setData(ClipboardData(text: '${res.word}\n$text'));
      AppToast.show(
        'Copied to clipboard',
        emoji: '📋',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => lookup(),
            decoration: InputDecoration(
              hintText: 'Look up a word or search the web…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        controller.clear();
                        result.value = null;
                        error.value = null;
                        hasSearched.value = false;
                        loading.value = false;
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    tooltip: 'Look up',
                    onPressed: lookup,
                  ),
                ],
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SourceDropdown(
                  selected: source.value,
                  onChanged: (src) {
                    if (src == null || src == source.value) return;
                    source.value = src;
                    if (!src.languages.any((l) => l.code == language.value)) {
                      language.value = src.languages.first.code;
                    }
                    if (hasSearched.value) lookup();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _LanguageDropdown(
                  selected: language.value,
                  languages: source.value.languages,
                  onChanged: (code) {
                    if (code != null && code != language.value) {
                      language.value = code;
                      if (hasSearched.value) lookup();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const SearchEnginePicker(compact: true),
          const SizedBox(height: AppSpacing.sm),
          // Always-visible web search action when there is a query
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: webSearch,
                  icon: const Icon(Icons.travel_explore_rounded, size: 18),
                  label: Text('Search "${value.text.trim()}" on ${selectedEngine.label}'),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading.value
                  ? const _LookupLoading(key: ValueKey('lookup-loading'))
                  : error.value != null
                      ? _LookupError(
                          key: const ValueKey('lookup-error'),
                          message: error.value!,
                          onRetry: lookup,
                        )
                      : result.value != null
                          ? SingleChildScrollView(
                              key: const ValueKey('lookup-result'),
                              child: _LookupDefinitionCard(
                                result: result.value!,
                                language: language.value,
                                source: source.value,
                                saved: saved.value,
                                onToggleSave: toggleSave,
                                onCopy: copyDefinition,
                                onWebSearch: webSearch,
                                selectedEngine: selectedEngine,
                                textTheme: textTheme,
                                colorScheme: colorScheme,
                              ),
                            )
                          : hasSearched.value
                              ? const SizedBox.shrink()
                              : _LookupEmptyHint(
                                  key: const ValueKey('lookup-hint'),
                                  colorScheme: colorScheme,
                                  textTheme: textTheme,
                                ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({required this.selected, required this.onChanged});

  final DictionarySource selected;
  final ValueChanged<DictionarySource?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<DictionarySource>(
      initialValue: selected,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, size: 20),
      decoration: InputDecoration(
        labelText: 'Source',
        prefixIcon: const Icon(Icons.book_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      items: DictionarySource.values.map((s) {
        return DropdownMenuItem(value: s, child: Text(s.label));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.selected,
    required this.languages,
    required this.onChanged,
  });

  final String selected;
  final List<WiktionaryLanguage> languages;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, size: 20),
      decoration: InputDecoration(
        labelText: 'Language',
        prefixIcon: const Icon(Icons.translate_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      items: languages.map((l) {
        return DropdownMenuItem(
          value: l.code,
          child: Text('${l.label} (${l.code.toUpperCase()})'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _LookupLoading extends StatelessWidget {
  const _LookupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Looking that up…',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupError extends StatelessWidget {
  const _LookupError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupEmptyHint extends StatelessWidget {
  const _LookupEmptyHint({super.key, required this.colorScheme, required this.textTheme});

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Text('Look up any word', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter a word above, pick a dictionary source and language, then tap Look up. Use the web search button to open results in your chosen engine.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupDefinitionCard extends StatelessWidget {
  const _LookupDefinitionCard({
    required this.result,
    required this.language,
    required this.source,
    required this.saved,
    required this.onToggleSave,
    required this.onCopy,
    required this.onWebSearch,
    required this.selectedEngine,
    required this.textTheme,
    required this.colorScheme,
  });

  final WiktionaryResult result;
  final String language;
  final DictionarySource source;
  final bool saved;
  final VoidCallback onToggleSave;
  final VoidCallback onCopy;
  final VoidCallback onWebSearch;
  final SearchEngine selectedEngine;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(result.word, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (result.phonetic != null && result.phonetic!.isNotEmpty)
                  Flexible(
                    child: Text(
                      result.phonetic!,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    language.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    source.label,
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: saved ? colorScheme.primary : null),
                  tooltip: saved ? 'Remove from saved' : 'Save word',
                  onPressed: onToggleSave,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy definition',
                  onPressed: onCopy,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onWebSearch,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('Search on ${selectedEngine.label}'),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            for (var i = 0; i < result.senses.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == result.senses.length - 1 ? 0 : AppSpacing.md),
                child: _SenseTile(index: i + 1, sense: result.senses[i], textTheme: textTheme, colorScheme: colorScheme),
              ),
          ],
        ),
      ),
    );
  }
}

class _SenseTile extends StatelessWidget {
  const _SenseTile({required this.index, required this.sense, required this.textTheme, required this.colorScheme});

  final int index;
  final WiktionarySense sense;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.secondaryContainer),
          child: Text('$index',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                child: Text(sense.partOfSpeech,
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(sense.definition, style: textTheme.bodyMedium),
              if (sense.examples.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                ...sense.examples.take(1).map(
                      (ex) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '"$ex"',
                          style: textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
