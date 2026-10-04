import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/search/domain/entities/search_engine.dart';
import 'package:atlas_app/search/presentation/providers/search_engine_provider.dart';

class SearchEnginePicker extends HookConsumerWidget {
  const SearchEnginePicker({
    super.key,
    this.compact = false,
    this.label = 'Search engine',
  });

  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSearchEngineProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (compact) {
      return DropdownButtonFormField<SearchEngine>(
        initialValue: selected,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, size: 20),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.travel_explore_rounded, size: 20),
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
        items: SearchEngine.values
            .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
            .toList(),
        onChanged: (engine) {
          if (engine != null) {
            ref.read(selectedSearchEngineProvider.notifier).select(engine);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SearchEngine.values.map((engine) {
            final isSelected = engine == selected;
            return ChoiceChip(
              label: Text(engine.label),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(selectedSearchEngineProvider.notifier).select(engine),
              avatar: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: colorScheme.onSecondaryContainer,
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class SearchEngineDropdown extends HookConsumerWidget {
  const SearchEngineDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SearchEnginePicker(compact: true);
  }
}
