import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/find_new/presentation/screens/find_new_screen.dart';
import 'package:atlas_app/search/presentation/widgets/library_search_tab.dart';
import 'package:atlas_app/search/presentation/widgets/lookup_search_tab.dart';

/// The Search branch, relabelled "Find new". Its default tab is the discovery
/// surface that used to be the standalone Discover page; Library search and
/// Lookup remain as sibling tabs. The former Saved tab now lives in the
/// Saved bottom-nav branch (`/bookmarks`).
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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Title style comes from the shared AppBar theme (serif, left-aligned).
      appBar: AppBar(
        title: const Text('Find new'),
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'Library'),
            Tab(text: 'Lookup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          const FindNewScreen(),
          LibrarySearchTab(initialQuery: initialTabIndex == 1 ? initialQuery : null),
          LookupSearchTab(initialQuery: initialTabIndex == 2 ? initialQuery : null),
        ],
      ),
    );
  }
}
