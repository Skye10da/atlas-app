import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Text search panel bound to a [PdfTextSearcher] created by the viewer.
class PdfSearchPanel extends HookWidget {
  const PdfSearchPanel({
    super.key,
    required this.textSearcher,
    this.nightMode = false,
  });

  final PdfTextSearcher textSearcher;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    useListenable(textSearcher);
    final searchTextController = useTextEditingController();
    final scrollController = useScrollController();

    useEffect(() {
      void onQueryChanged() {
        textSearcher.startTextSearch(searchTextController.text);
      }

      searchTextController.addListener(onQueryChanged);
      return () => searchTextController.removeListener(onQueryChanged);
    }, [searchTextController, textSearcher]);

    void revealCurrent() {
      if (!scrollController.hasClients) return;
      final index = textSearcher.currentIndex;
      if (index == null) return;
      final target = 44.0 * index.toDouble();
      final position = scrollController.position;
      scrollController.animateTo(
        target.clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    Future<void> goToNextMatch() async {
      await textSearcher.goToNextMatch();
      revealCurrent();
    }

    Future<void> goToPrevMatch() async {
      await textSearcher.goToPrevMatch();
      revealCurrent();
    }

    Future<void> goToMatchAt(int index) async {
      await textSearcher.goToMatchOfIndex(index);
      revealCurrent();
    }

    final colors = Theme.of(context).colorScheme;
    final searcher = textSearcher;
    final matches = searcher.matches;
    final isSearching = searcher.isSearching;
    final hasQuery = searchTextController.text.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          height: 2,
          child: isSearching
              ? LinearProgressIndicator(
                  value: searcher.searchProgress,
                  minHeight: 2,
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchTextController,
                  decoration: InputDecoration(
                    hintText: 'Search document…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 4),
              if (searcher.hasMatches || isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${(searcher.currentIndex ?? -1) + 1}/${matches.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                tooltip: 'Previous match',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: matches.isEmpty ? null : goToPrevMatch,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                tooltip: 'Next match',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: matches.isEmpty ? null : goToNextMatch,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: hasQuery
                    ? () {
                        searchTextController.clear();
                        searcher.resetTextSearch();
                      }
                    : null,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
        Expanded(
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    hasQuery ? 'No results found' : 'Type to search document',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemExtent: 44,
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _ResultTile(
                    match: matches[index],
                    isCurrent: index == searcher.currentIndex,
                    onTap: () => goToMatchAt(index),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.match,
    required this.isCurrent,
    required this.onTap,
  });

  final PdfPageTextRange match;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isCurrent ? colors.primary.withValues(alpha: 0.12) : null,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: match.text,
                      style: TextStyle(
                        backgroundColor: Colors.amber.withValues(alpha: 0.35),
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Page ${match.pageNumber}',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
