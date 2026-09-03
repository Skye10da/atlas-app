import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/dictionary_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/presentation/providers/dictionary_providers.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';

class WordLookupSheet extends HookConsumerWidget {
  const WordLookupSheet({
    super.key,
    required this.word,
    this.initialLanguage = 'en',
    this.initialSource = DictionarySource.wiktionary,
    this.sourceSentence,
    this.sourceTitle,
  });

  final String word;
  final String initialLanguage;
  final DictionarySource initialSource;
  final String? sourceSentence;
  final String? sourceTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextController = useTextEditingController(
      text: sourceSentence ?? '',
    );
    final source = useState(initialSource);
    final language = useState(() {
      var lang = initialLanguage;
      if (!initialSource.languages.any((l) => l.code == lang)) {
        lang = initialSource.languages.first.code;
      }
      return lang;
    }());
    final result = useState<WiktionaryResult?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final saved = useState(false);
    final speaking = useState(false);

    Future<void> checkSaved() async {
      final id = '${word}_${language.value}';
      final exists = await ref.read(dictionaryRepositoryProvider).exists(id);
      if (context.mounted) saved.value = exists;
    }

    Future<void> lookup() async {
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
      } catch (e) {
        if (!context.mounted) return;
        loading.value = false;
        error.value = 'Could not look up "$word". Check your connection.';
      }
      await checkSaved();
    }

    useEffect(() {
      unawaited(checkSaved());
      unawaited(lookup());
      return () {
        if (speaking.value) {
          const SelectionSpeaker().stop(ref).catchError((_) {});
        }
      };
    }, const []);

    Future<void> toggleSave() async {
      final res = result.value;
      if (res == null) return;
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
        final ctxText = contextController.text.trim();
        await repo.save(
          DictionaryWordEntity(
            id: id,
            word: word,
            language: language.value,
            languageLabel: langLabel,
            source: source.value.id,
            sourceLabel: source.value.label,
            phonetic: res.phonetic,
            partOfSpeech: res.senses.first.partOfSpeech,
            definition: res.senses.map((s) => s.definition).join('\n'),
            fullJson: jsonEncode(res.toJson()),
            savedAt: DateTime.now(),
            sourceSentence: ctxText.isEmpty ? null : ctxText,
            sourceTitle: sourceTitle,
            reviewLevel: 0,
            reviewCount: 0,
            lastReviewedAt: null,
            nextReviewAt: null,
          ),
        );
      }
      ref.invalidate(savedWordsProvider);
      if (!context.mounted) return;
      saved.value = !saved.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.value ? 'Saved "$word"' : 'Removed from saved words',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    void copyWord() {
      final res = result.value;
      if (res == null) return;
      final text = res.senses
          .map((s) => '${s.partOfSpeech}: ${s.definition}')
          .join('\n');
      Clipboard.setData(ClipboardData(text: '$word\n$text'));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }

    Future<void> speak() async {
      const speaker = SelectionSpeaker();
      if (speaking.value) {
        speaking.value = false;
        await speaker.stop(ref);
        return;
      }

      final res = result.value;
      if (res == null) return;
      final firstSense = res.senses.isNotEmpty ? res.senses.first : null;
      final firstExample = firstSense != null && firstSense.examples.isNotEmpty
          ? firstSense.examples.first
          : null;
      final text = [
        res.word,
        ?firstSense?.definition,
        ?firstExample,
      ].join('. ');
      if (text.trim().isEmpty) return;

      final locale = localeForLanguageCode(language.value);
      final voiceId = await resolveVoiceIdForLanguage(ref, language.value);
      if (!context.mounted) return;

      speaking.value = true;
      await speaker.speak(
        ref: ref,
        bookId: 'dictionary',
        chapterId: '${word}_${language.value}',
        text: text,
        language: locale,
        voiceId: voiceId,
      );
      if (context.mounted) speaking.value = false;
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (result.value?.phonetic != null && result.value!.phonetic!.isNotEmpty)
                      Text(
                        result.value!.phonetic!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
              _SpeakButton(
                speaking: speaking.value,
                enabled: result.value != null,
                onPressed: speak,
              ),
              _SaveButton(
                saved: saved.value,
                enabled: result.value != null,
                onPressed: toggleSave,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContextField(
            controller: contextController,
            source: sourceTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SourceSelector(
                  selected: source.value,
                  onChanged: (src) {
                    if (src == null || src == source.value) return;
                    source.value = src;
                    if (!src.languages.any((l) => l.code == language.value)) {
                      language.value = src.languages.first.code;
                    }
                    lookup();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _LanguageSelector(
                  selected: language.value,
                  languages: source.value.languages,
                  onChanged: (code) {
                    if (code != null && code != language.value) {
                      language.value = code;
                      lookup();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading.value
                  ? const _LoadingState(key: ValueKey('loading'))
                  : error.value != null
                  ? _ErrorState(
                      key: const ValueKey('error'),
                      message: error.value!,
                      onRetry: lookup,
                    )
                  : result.value != null
                  ? SingleChildScrollView(
                      key: const ValueKey('result'),
                      child: _DefinitionCard(
                        result: result.value!,
                        language: language.value,
                        source: source.value,
                        onCopy: copyWord,
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                        relatedWords: const [],
                        onRelatedWordTap: (relatedWord) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                body: SafeArea(
                                  child: WordLookupSheet(
                                    word: relatedWord,
                                    initialLanguage: language.value,
                                    initialSource: source.value,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({
    required this.speaking,
    required this.enabled,
    required this.onPressed,
  });

  final bool speaking;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
        key: ValueKey(speaking),
      ),
      tooltip: speaking ? 'Stop reading' : 'Read aloud',
      onPressed: enabled ? onPressed : null,
      color: speaking ? colorScheme.primary : null,
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saved,
    required this.enabled,
    required this.onPressed,
  });

  final bool saved;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          key: ValueKey(saved),
          color: saved ? colorScheme.primary : null,
        ),
      ),
      tooltip: saved ? 'Remove from saved' : 'Save word',
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _ContextField extends StatelessWidget {
  const _ContextField({required this.controller, required this.source});

  final TextEditingController controller;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Found in context',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (source != null) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    source!,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
          TextField(
            controller: controller,
            maxLines: 2,
            minLines: 1,
            style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 4),
              hintText: 'Edit the sentence saved with this word…',
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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

class _SourceSelector extends StatelessWidget {
  const _SourceSelector({required this.selected, required this.onChanged});

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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Looking that up…',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    required this.result,
    required this.language,
    required this.source,
    required this.onCopy,
    required this.textTheme,
    required this.colorScheme,
    this.relatedWords = const [],
    this.onRelatedWordTap,
  });

  final WiktionaryResult result;
  final String language;
  final DictionarySource source;
  final VoidCallback onCopy;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final List<String> relatedWords;
  final ValueChanged<String>? onRelatedWordTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  result.word,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (result.phonetic != null)
                  Expanded(
                    child: Text(
                      result.phonetic!,
                      style: textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    language.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    source.label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy definition',
                  onPressed: onCopy,
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            for (var i = 0; i < result.senses.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == result.senses.length - 1 ? 0 : AppSpacing.md,
                ),
                child: _SenseTile(
                  index: i + 1,
                  sense: result.senses[i],
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ),
            if (relatedWords.isNotEmpty) ...[
              const Divider(height: AppSpacing.lg),
              Text(
                'Related words',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: relatedWords
                    .map(
                      (w) => ActionChip(
                        label: Text(w),
                        onPressed: onRelatedWordTap == null
                            ? null
                            : () => onRelatedWordTap!(w),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SenseTile extends StatelessWidget {
  const _SenseTile({
    required this.index,
    required this.sense,
    required this.textTheme,
    required this.colorScheme,
  });

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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.secondaryContainer,
          ),
          child: Text(
            '$index',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sense.partOfSpeech,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(sense.definition, style: textTheme.bodyMedium),
              if (sense.examples.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                ...sense.examples
                    .take(1)
                    .map(
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
