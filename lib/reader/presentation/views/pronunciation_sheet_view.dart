import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/view_models/pronunciation_view_model.dart';
import 'package:atlas_app/reader/speech/pronunciation/models/pronunciation_rule.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';

/// View: dumb UI for pronunciation lexicon.
/// Uses `ListenableBuilder` to listen to `PronunciationViewModel`.
/// Responsive via `LayoutBuilder` + `ConstrainedBox` + `Flexible`.
class PronunciationSheetView extends StatelessWidget {
  const PronunciationSheetView({super.key, required this.viewModel});

  final PronunciationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isLarge = constraints.maxWidth > 600;
            if (isLarge) {
              return _buildLarge(context);
            } else {
              return _buildSmall(context);
            }
          },
        );
      },
    );
  }

  Widget _buildLarge(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildList(context),
        ),
        const VerticalDivider(width: 1),
        Flexible(
          child: _buildPreview(context),
        ),
      ],
    );
  }

  Widget _buildSmall(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildList(context)),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            child: _buildPreview(context),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final rules = viewModel.rules;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          itemCount: rules.length + 1,
          itemBuilder: (context, index) {
            if (index == rules.length) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add rule'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: viewModel.resetToDefaults,
                      child: const Text('Reset defaults'),
                    ),
                  ],
                ),
              );
            }
            final rule = rules[index];
            return Dismissible(
              key: ValueKey(rule.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => viewModel.removeRule(rule.id),
              child: SwitchListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '"${rule.pattern}" → "${rule.replacement}"',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rule.isRegex)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('regex', style: TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
                subtitle: Text(rule.isEnabled ? 'Enabled' : 'Disabled'),
                value: rule.isEnabled,
                onChanged: (v) => viewModel.toggleRule(rule.id, v),
                secondary: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showEditDialog(context, rule),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preview', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Rules are applied in order. Example:\n"Hello... world -- test """quote""" → Hello, world — test "quote"',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${viewModel.rules.where((r) => r.isEnabled).length} active / ${viewModel.rules.length} total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (viewModel.error != null) ...[
                const SizedBox(height: 8),
                Text(viewModel.error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await viewModel.save();
                  if (context.mounted) {
                    AppToast.showSuccess('Pronunciations saved');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final patternCtrl = TextEditingController();
    final replacementCtrl = TextEditingController();
    bool isRegex = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: patternCtrl,
                      decoration: const InputDecoration(labelText: 'Pattern', hintText: 'e.g. ...'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: replacementCtrl,
                      decoration: const InputDecoration(labelText: 'Replacement', hintText: 'e.g. , or silence'),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('Regex'),
                value: isRegex,
                onChanged: (v) => setState(() => isRegex = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                viewModel.addRule(PronunciationRule(id: id, pattern: patternCtrl.text, replacement: replacementCtrl.text, isRegex: isRegex));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PronunciationRule rule) {
    final patternCtrl = TextEditingController(text: rule.pattern);
    final replacementCtrl = TextEditingController(text: rule.replacement);
    bool isRegex = rule.isRegex;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: patternCtrl,
                      decoration: const InputDecoration(labelText: 'Pattern'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: replacementCtrl,
                      decoration: const InputDecoration(labelText: 'Replacement'),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('Regex'),
                value: isRegex,
                onChanged: (v) => setState(() => isRegex = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                viewModel.updateRule(rule.id, rule.copyWith(pattern: patternCtrl.text, replacement: replacementCtrl.text, isRegex: isRegex));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
