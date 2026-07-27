import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/presentation/providers/dictionary_providers.dart';

class DictionaryScreen extends ConsumerWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedWordsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Could not load saved words.')),
        data: (words) {
          if (words.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 64,
                        color: colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.md),
                    Text('No saved words',
                        style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Select text in the reader and tap "Define" to save words here.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: words.length,
            itemBuilder: (context, index) =>
                _WordCard(word: words[index], ref: ref),
          );
        },
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.ref});

  final DictionaryWordEntity word;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(word.word,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(word.languageLabel,
                      style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer)),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: colorScheme.error),
                  onPressed: () {
                    ref.read(dictionaryRepositoryProvider).delete(word.id);
                    ref.invalidate(savedWordsProvider);
                  },
                ),
              ],
            ),
            if (word.phonetic != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(word.phonetic!,
                  style: textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(word.partOfSpeech,
                  style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(word.definition,
                style: textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
