import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';

/// Lets the reader define what a selected term should display as in this novel.
///
/// A term can carry several replacement options; the one highlighted by the
/// radio is applied at render time. Saving any change invalidates the glossary
/// provider, so the open chapter immediately re-renders with the new choice.
class GlossaryTermSheet extends HookConsumerWidget {
  const GlossaryTermSheet({
    super.key,
    required this.bookId,
    required this.term,
  });

  final String bookId;

  /// The source text the user selected (e.g. `中`).
  final String term;

  static AtlasGlossaryEntry? _firstWhereOrNull(
    List<AtlasGlossaryEntry> list,
    String term,
  ) {
    for (final e in list) {
      if (e.term == term || e.replacements.contains(term)) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replacementController = useTextEditingController();
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final entries =
        ref.watch(atlasGlossaryProvider(bookId)).valueOrNull ?? const [];
    final entry = _firstWhereOrNull(entries, term);
    final effectiveTerm = entry?.term ?? term;

    void snack(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }

    void invalidate() {
      ref.invalidate(atlasGlossaryProvider(bookId));
    }

    Future<void> apply() async {
      final text = replacementController.text.trim();
      if (text.isEmpty) return;
      await ref
          .read(atlasGlossaryControllerProvider)
          .upsertTerm(bookId, term, text);
      invalidate();
      if (context.mounted) {
        replacementController.clear();
        snack('Replaced "$term" with "$text" in this novel');
      }
    }

    Future<void> addOption(String entryId) async {
      final text = replacementController.text.trim();
      if (text.isEmpty) return;
      await ref
          .read(atlasGlossaryControllerProvider)
          .addReplacement(bookId, entryId, text);
      invalidate();
      if (context.mounted) {
        replacementController.clear();
        snack('Added "$text" as another option');
      }
    }

    Future<void> selectOption(String entryId, int index) async {
      await ref
          .read(atlasGlossaryControllerProvider)
          .setActiveReplacement(bookId, entryId, index);
      invalidate();
    }

    Future<void> remove(AtlasGlossaryEntry entryToRemove) async {
      await ref
          .read(atlasGlossaryControllerProvider)
          .removeEntry(bookId, entryToRemove.id);
      invalidate();
      if (context.mounted) {
        snack('Removed term "${entryToRemove.term}" — original text restored');
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry == null ? 'Set as term' : 'Edit term',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry == null
                          ? 'Replace "$effectiveTerm" throughout this novel'
                          : 'Display "$effectiveTerm" as',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry != null)
                TextButton.icon(
                  onPressed: () => remove(entry),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove term'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (entry != null && entry.replacements.isNotEmpty) ...[
            Text('Options', style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < entry.replacements.length; i++)
              // ignore: deprecated_member_use
              RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: i,
                // ignore: deprecated_member_use
                groupValue: entry.activeIndex,
                title: Text(entry.replacements[i]),
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) selectOption(entry.id, val);
                },
              ),
            const SizedBox(height: AppSpacing.xs),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replacementController,
                  autofocus: entry == null,
                  decoration: InputDecoration(
                    labelText: entry == null
                        ? 'Display as…'
                        : 'Add another option…',
                    hintText: 'e.g. middle',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    if (entry == null) {
                      apply();
                    } else {
                      addOption(entry.id);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () {
                  if (entry == null) {
                    apply();
                  } else {
                    addOption(entry.id);
                  }
                },
                child: Text(entry == null ? 'Set as term' : 'Add option'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
