import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';

/// Manages the per-novel glossary from reader settings.
///
/// Lists every term set for the book, shows which replacement is active, and
/// offers add / edit / remove. Editing a term reopens the same bottom sheet the
/// reader's selection menu uses; every change invalidates the glossary provider
/// so the open chapter re-renders immediately.
class GlossaryTab extends ConsumerStatefulWidget {
  const GlossaryTab({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<GlossaryTab> createState() => _GlossaryTabState();
}

class _GlossaryTabState extends ConsumerState<GlossaryTab> {
  Future<void> _addTerm() async {
    final term = await _promptForText(
      title: 'Add term',
      label: 'Term',
      hint: 'Original text (e.g. 中)',
    );
    if (term == null || !mounted) return;
    final replacement = await _promptForText(
      title: 'Display "$term" as…',
      label: 'Replacement',
      hint: 'e.g. middle',
    );
    if (replacement == null || !mounted) return;
    await ref
        .read(atlasGlossaryControllerProvider)
        .upsertTerm(widget.bookId, term, replacement);
    ref.invalidate(atlasGlossaryProvider(widget.bookId));
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    required String hint,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label, hintText: hint),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTerm(AtlasGlossaryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          GlossaryTermSheet(bookId: widget.bookId, term: entry.term),
    );
  }

  Future<void> _removeTerm(AtlasGlossaryEntry entry) async {
    await ref
        .read(atlasGlossaryControllerProvider)
        .removeEntry(widget.bookId, entry.id);
    if (!mounted) return;
    ref.invalidate(atlasGlossaryProvider(widget.bookId));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '"${entry.term}" removed — the original text renders again.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final entries = ref.watch(atlasGlossaryProvider(widget.bookId)).valueOrNull;
    final list = entries ?? const <AtlasGlossaryEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Glossary terms',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _addTerm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add term'),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'No glossary terms yet. Select a word in the reader and choose '
              '"Set as term", or add one here to change how it displays.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final entry in list)
            _TermTile(
              entry: entry,
              onTap: () => _editTerm(entry),
              onDelete: () => _removeTerm(entry),
            ),
      ],
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final AtlasGlossaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active = entry.activeReplacement;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.term,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (active != null)
                        Text(
                          active,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      Text(
                        entry.replacements.length == 1
                            ? '1 option'
                            : '${entry.replacements.length} options',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove term',
                  iconSize: 20,
                  color: colors.onSurfaceVariant,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
