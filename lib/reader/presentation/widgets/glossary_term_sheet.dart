import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';

/// Lets the reader define what a selected term should display as in this novel.
///
/// A term can carry several replacement options; the one highlighted by the
/// radio is applied at render time. Saving any change invalidates the glossary
/// provider, so the open chapter immediately re-renders with the new choice.
class GlossaryTermSheet extends ConsumerStatefulWidget {
  const GlossaryTermSheet({
    super.key,
    required this.bookId,
    required this.term,
  });

  final String bookId;

  /// The source text the user selected (e.g. `中`).
  final String term;

  @override
  ConsumerState<GlossaryTermSheet> createState() => _GlossaryTermSheetState();
}

class _GlossaryTermSheetState extends ConsumerState<GlossaryTermSheet> {
  final _replacementController = TextEditingController();

  @override
  void dispose() {
    _replacementController.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(atlasGlossaryProvider(widget.bookId));
  }

  Future<void> _apply() async {
    final text = _replacementController.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(atlasGlossaryControllerProvider)
        .upsertTerm(widget.bookId, widget.term, text);
    _invalidate();
    if (mounted) {
      _replacementController.clear();
      _snack('Replaced "${widget.term}" with "$text" in this novel');
    }
  }

  Future<void> _addOption(String entryId) async {
    final text = _replacementController.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(atlasGlossaryControllerProvider)
        .addReplacement(widget.bookId, entryId, text);
    _invalidate();
    if (mounted) {
      _replacementController.clear();
      _snack('Added "$text" as another option');
    }
  }

  Future<void> _selectOption(String entryId, int index) async {
    await ref
        .read(atlasGlossaryControllerProvider)
        .setActiveReplacement(widget.bookId, entryId, index);
    _invalidate();
  }

  Future<void> _remove(AtlasGlossaryEntry entry) async {
    await ref
        .read(atlasGlossaryControllerProvider)
        .removeEntry(widget.bookId, entry.id);
    _invalidate();
    if (mounted) {
      _snack('Removed term "${entry.term}" — original text restored');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final entries = ref
        .watch(atlasGlossaryProvider(widget.bookId))
        .valueOrNull ??
        const [];
    final entry = _firstWhereOrNull(entries, widget.term);
    final effectiveTerm = entry?.term ?? widget.term;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  entry == null ? 'Set as term' : 'Edit term',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Display "$effectiveTerm" as…',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (entry != null) ...[
              const SizedBox(height: AppSpacing.md),
              RadioGroup<int>(
                groupValue: entry.activeIndex,
                onChanged: (value) {
                  if (value != null) _selectOption(entry.id, value);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < entry.replacements.length; i++)
                      RadioListTile<int>(
                        value: i,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.replacements[i]),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _remove(entry),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove term'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replacementController,
                    decoration: InputDecoration(
                      labelText: 'Replacement text',
                      hintText: 'e.g. middle',
                      isDense: true,
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) =>
                        entry == null ? _apply() : _addOption(entry.id),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => entry == null ? _apply() : _addOption(entry.id),
                  child: Text(entry == null ? 'Set as term' : 'Add option'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Finds the entry for the selected text, whether the selection is the
  /// stored term or one of its (currently displayed) replacement options.
  static AtlasGlossaryEntry? _firstWhereOrNull(
    List<AtlasGlossaryEntry> entries,
    String term,
  ) {
    for (final e in entries) {
      if (e.term == term || e.replacements.contains(term)) return e;
    }
    return null;
  }
}