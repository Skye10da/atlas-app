import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/presentation/chat/chat_screen.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// "Previously on this story" card for the novel detail page.
class StoryRecapCard extends ConsumerWidget {
  const StoryRecapCard({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final lastRead = ref.watch(lastReadChapterProvider(bookId)).valueOrNull;
    final chapter = (lastRead?.index ?? 0) + 1;
    final readThroughId =
        ref.watch(activeReadThroughProvider(bookId)).valueOrNull?.id ??
        'default';
    final recap = ref.watch(
      recapSnapshotProvider((
        bookId: bookId,
        readThroughId: readThroughId,
        chapter: chapter,
      )),
    );

    void openChat(String? prompt) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            bookId: bookId,
            readerPosition: ReaderPosition(
              bookId: bookId,
              currentChapter: chapter,
              readThroughId: readThroughId,
            ),
            initialPrompt: prompt,
          ),
        ),
      );
    }

    final body = () {
      final raw = recap.text;
      if (raw == null || raw.isEmpty) return _emptyHint;
      final text = _plain(raw);
      return text.length < 24 ? _emptyHint : text;
    }();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.55),
            cs.tertiaryContainer.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Previously on this story',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.smMd),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: () => openChat('recap'),
                child: const Text('Full recap'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Ask about the story',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => openChat(null),
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        'Ask about the story…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _emptyHint =
      'Read a few chapters and Atlas will build a spoiler-free recap here.';

  /// Flattens the engine's markdown into a few plain lines for the card.
  static String _plain(String markdown) {
    final lines = markdown
        .split('\n')
        .map(
          (l) => l
              .replaceAll(RegExp(r'[*_`]'), '')
              .replaceFirst(RegExp(r'^\s*#+\s*'), '')
              .replaceFirst(RegExp(r'^\s*[-•]\s+'), '')
              .trim(),
        )
        .where((l) => l.isNotEmpty)
        .take(4);
    return lines.join(' ');
  }
}
