import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/search/domain/entities/search_engine.dart';
import 'package:atlas_app/search/presentation/providers/search_engine_provider.dart';

class SearchEngineSettingsScreen extends HookConsumerWidget {
  const SearchEngineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSearchEngineProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Engine')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.shellContentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              Text(
                'Choose the web search engine used for address-bar fallback, Lookup tab, and Word Lookup sheet. Redirect will open in the in-app browser.',
                style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                  side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < SearchEngine.values.length; i++) ...[
                      RadioGroup<SearchEngine>(
                        groupValue: selected,
                        onChanged: (engine) {
                          if (engine != null) {
                            ref.read(selectedSearchEngineProvider.notifier).select(engine);
                          }
                        },
                        child: RadioListTile<SearchEngine>(
                          value: SearchEngine.values[i],
                          title: Text(SearchEngine.values[i].label),
                          subtitle: Text(
                            SearchEngine.values[i].buildUrl('example'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          secondary: Icon(
                            SearchEngine.values[i] == selected
                                ? Icons.check_circle_rounded
                                : Icons.travel_explore_rounded,
                            color: SearchEngine.values[i] == selected ? colors.primary : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (i != SearchEngine.values.length - 1)
                        Divider(height: 1, indent: 56, color: colors.outlineVariant.withValues(alpha: 0.3)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Preview: ${selected.buildUrl('atlas book')}',
                style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
