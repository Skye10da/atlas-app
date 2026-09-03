import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/presentation/providers/dictionary_providers.dart';
import 'package:atlas_app/dictionary/presentation/screens/review_scheduler.dart';

class WordReviewScreen extends HookConsumerWidget {
  const WordReviewScreen({super.key, required this.dueWords});

  final List<DictionaryWordEntity> dueWords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = useMemoized(() => [...dueWords], [dueWords]);
    final index = useState(0);
    final revealed = useState(false);
    final correctCount = useState(0);

    final isDone = index.value >= queue.length;
    final current = !isDone ? queue[index.value] : null;

    Future<void> answer(bool correct) async {
      if (current == null) return;
      final nextLevel = ReviewScheduler.nextLevel(
        current.reviewLevel,
        correct: correct,
      );
      final updated = current.copyWith(
        reviewLevel: nextLevel,
        reviewCount: current.reviewCount + 1,
        lastReviewedAt: DateTime.now(),
        nextReviewAt: ReviewScheduler.nextReviewDate(nextLevel),
      );
      await ref.read(dictionaryRepositoryProvider).save(updated);
      ref.invalidate(savedWordsProvider);

      if (!context.mounted) return;
      if (correct) correctCount.value++;
      index.value++;
      revealed.value = false;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(isDone ? 'Session complete' : 'Review')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: isDone
              ? _SessionSummary(
                  total: queue.length,
                  correct: correctCount.value,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                )
              : Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: queue.isNotEmpty ? index.value / queue.length : 0,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${index.value + 1} of ${queue.length}',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () => revealed.value = !revealed.value,
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (!revealed.value) return;
                            if (velocity < -200) {
                              answer(true);
                            } else if (velocity > 200) {
                              answer(false);
                            }
                          },
                          child: _FlashCard(
                            word: current!,
                            revealed: revealed.value,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        ),
                      ),
                    ),
                    if (revealed.value)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => answer(false),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Still learning'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => answer(true),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Got it'),
                            ),
                          ),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'Tap the card to reveal · swipe to answer',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FlashCard extends StatelessWidget {
  const _FlashCard({
    required this.word,
    required this.revealed,
    required this.colorScheme,
    required this.textTheme,
  });

  final DictionaryWordEntity word;
  final bool revealed;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        key: ValueKey('${word.id}_$revealed'),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: revealed ? _buildBack(context) : _buildFront(context),
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          word.word,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (word.phonetic != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            word.phonetic!,
            style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ReviewScheduler.levelLabel(word.reviewLevel),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBack(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          word.definition,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
        if (word.sourceSentence != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '"${word.sourceSentence}"',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (word.sourceTitle != null) ...[
            const SizedBox(height: 2),
            Text(
              '— ${word.sourceTitle}',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.total,
    required this.correct,
    required this.colorScheme,
    required this.textTheme,
  });

  final int total;
  final int correct;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration_rounded, size: 56, color: colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text('$correct / $total remembered', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Come back tomorrow for the next batch.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
