import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/dictionary/presentation/screens/dictionary_screen.dart';
import 'package:atlas_app/search/presentation/widgets/library_search_tab.dart';
import 'package:atlas_app/search/presentation/widgets/lookup_search_tab.dart';

class SearchScreen extends HookConsumerWidget {
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialTabIndex,
  });

  final String? initialQuery;
  final int? initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(
      initialLength: 3,
      initialIndex: (initialTabIndex ?? 0).clamp(0, 2),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Search & Lookup',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_stories_rounded, size: 20),
              text: 'Library',
            ),
            Tab(
              icon: Icon(Icons.translate_rounded, size: 20),
              text: 'Lookup',
            ),
            Tab(
              icon: Icon(Icons.bookmark_rounded, size: 20),
              text: 'Saved',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          LibrarySearchTab(initialQuery: initialTabIndex == 0 ? initialQuery : null),
          LookupSearchTab(initialQuery: initialTabIndex == 1 ? initialQuery : null),
          const DictionaryScreen(),
        ],
      ),
    );
  }
}
