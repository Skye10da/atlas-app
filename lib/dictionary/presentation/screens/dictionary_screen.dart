import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/dictionary_service.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/presentation/providers/dictionary_providers.dart';
import 'package:atlas_app/dictionary/presentation/screens/review_scheduler.dart';
import 'package:atlas_app/dictionary/presentation/screens/word_review_screen.dart';

enum _SortMode { alphabetical, byLanguage }

class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedLanguage;
  _SortMode _sortMode = _SortMode.alphabetical;
  final Set<String> _expandedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DictionaryWordEntity> _filterAndSort(List<DictionaryWordEntity> words) {
    final result = words.where((w) {
      final matchesQuery = _query.isEmpty ||
          w.word.toLowerCase().contains(_query) ||
          w.definition.toLowerCase().contains(_query);
      final matchesLanguage =
          _selectedLanguage == null || w.languageLabel == _selectedLanguage;
      return matchesQuery && matchesLanguage;
    }).toList();

    result.sort((a, b) => _sortMode == _SortMode.alphabetical
        ? a.word.toLowerCase().compareTo(b.word.toLowerCase())
        : a.languageLabel
            .toLowerCase()
            .compareTo(b.languageLabel.toLowerCase()));

    return result;
  }

  Future<void> _confirmDelete(DictionaryWordEntity word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove word?'),
        content: Text('"${word.word}" will be removed from your dictionary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(dictionaryRepositoryProvider).delete(word.id);
      ref.invalidate(savedWordsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "${word.word}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(savedWordsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (words) {
          if (words.isEmpty) {
            return _EmptyState(colorScheme: colorScheme);
          }

          final languages = words.map((w) => w.languageLabel).toSet().toList()
            ..sort();
          final filtered = _filterAndSort(words);

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('Dictionary'),
                actions: [
                  PopupMenuButton<_SortMode>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    initialValue: _sortMode,
                    onSelected: (mode) => setState(() => _sortMode = mode),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _SortMode.alphabetical,
                        child: Text('A → Z'),
                      ),
                      PopupMenuItem(
                        value: _SortMode.byLanguage,
                        child: Text('By language'),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                    child: _SearchField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.toLowerCase()),
                    ),
                  ),
                ),
              ),
              if (languages.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      scrollDirection: Axis.horizontal,
                      itemCount: languages.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ChoiceChip(
                            label: const Text('All'),
                            selected: _selectedLanguage == null,
                            onSelected: (_) =>
                                setState(() => _selectedLanguage = null),
                          );
                        }
                        final lang = languages[index - 1];
                        return ChoiceChip(
                          label: Text(lang),
                          selected: _selectedLanguage == lang,
                          onSelected: (_) => setState(() =>
                              _selectedLanguage = _selectedLanguage == lang
                                  ? null
                                  : lang),
                        );
                      },
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
                sliver: SliverToBoxAdapter(
                  child: _StatsBanner(
                    words: words,
                    colorScheme: colorScheme,
                    onReview: (due) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WordReviewScreen(dueWords: due),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm),
                    child: Text(
                      '${filtered.length} ${filtered.length == 1 ? 'word' : 'words'}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoResultsState(colorScheme: colorScheme),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final word = filtered[index];
                      final isExpanded = _expandedIds.contains(word.id);
                      return Dismissible(
                        key: ValueKey(word.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _confirmDelete(word);
                          return false;
                        },
                        background: _DismissBackground(colorScheme: colorScheme),
                        child: _WordCard(
                          word: word,
                          expanded: isExpanded,
                          onTap: () => setState(() {
                            if (isExpanded) {
                              _expandedIds.remove(word.id);
                            } else {
                              _expandedIds.add(word.id);
                            }
                          }),
                          onCopy: () {
                            Clipboard.setData(ClipboardData(
                                text: '${word.word} — ${word.definition}'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Copied to clipboard')),
                            );
                          },
                          onDelete: () => _confirmDelete(word),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.words,
    required this.colorScheme,
    required this.onReview,
  });

  final List<DictionaryWordEntity> words;
  final ColorScheme colorScheme;
  final ValueChanged<List<DictionaryWordEntity>> onReview;

  @override
  Widget build(BuildContext context) {
    final due = ReviewScheduler.dueWords(words);
    final mastered = ReviewScheduler.masteredCount(words);
    final streak = ReviewScheduler.currentStreak(words);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.local_fire_department_rounded,
            label: '$streak day${streak == 1 ? '' : 's'}',
            colorScheme: colorScheme,
          ),
          const SizedBox(width: AppSpacing.md),
          _StatChip(
            icon: Icons.emoji_events_rounded,
            label: '$mastered mastered',
            colorScheme: colorScheme,
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: due.isEmpty ? null : () => onReview(due),
            icon: const Icon(Icons.style_rounded, size: 18),
            label: Text(due.isEmpty ? 'All caught up' : 'Review (${due.length})'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: colorScheme.onPrimaryContainer)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search words or definitions',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 44, color: colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No saved words yet', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Select text in the reader and tap "Define" to build your personal dictionary.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Text('No matches', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try a different search term or filter.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.label});

  final String label;

  static const _palette = [
    (Colors.indigo, Colors.white),
    (Colors.teal, Colors.white),
    (Colors.deepOrange, Colors.white),
    (Colors.purple, Colors.white),
    (Colors.blueGrey, Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    final index = label.codeUnits.fold<int>(0, (sum, c) => sum + c) %
        _palette.length;
    final (background, foreground) = _palette[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.expanded,
    required this.onTap,
    required this.onCopy,
    required this.onDelete,
  });

  final DictionaryWordEntity word;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final parsed = expanded && word.fullJson.isNotEmpty
        ? WiktionaryResult.tryParse(word.fullJson)
        : null;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onCopy,
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
                  _SourceBadge(label: word.sourceLabel),
                  const SizedBox(width: AppSpacing.xs),
                  _LanguageBadge(label: word.languageLabel),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: colorScheme.error),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (word.phonetic != null) ...[
                const SizedBox(height: 2),
                Text(word.phonetic!,
                    style: textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
              const SizedBox(height: AppSpacing.xs),
              if (parsed != null && parsed.senses.length > 1) ...[
                for (final entry in parsed.senses.asMap().entries)
                  _RichSenseTile(
                    index: entry.key + 1,
                    sense: entry.value,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(word.partOfSpeech,
                      style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer)),
                ),
                const SizedBox(height: AppSpacing.xs),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Text(
                    word.definition,
                    style: textTheme.bodySmall,
                    maxLines: expanded ? null : 2,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                ),
                if (parsed != null && parsed.senses.length == 1)
                  ...parsed.senses.first.examples.take(1).map(
                        (ex) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('"$ex"',
                              style: textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6))),
                        ),
                      ),
              ],
              if (word.sourceSentence != null && word.sourceSentence!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded,
                            size: 14,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            word.sourceSentence!,
                            style: textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (word.sourceTitle != null) ...[
                const SizedBox(height: 2),
                Text(word.sourceTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RichSenseTile extends StatelessWidget {
  const _RichSenseTile({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
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
            child: Text('$index',
                style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600)),
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
                  child: Text(sense.partOfSpeech,
                      style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(sense.definition, style: textTheme.bodySmall),
                if (sense.examples.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  for (final ex in sense.examples.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '"$ex"',
                        style: textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
