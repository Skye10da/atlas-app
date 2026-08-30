import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Text search panel bound to a [PdfTextSearcher] created by the viewer.
class PdfSearchPanel extends StatefulWidget {
  const PdfSearchPanel({
    super.key,
    required this.textSearcher,
    this.nightMode = false,
  });

  final PdfTextSearcher textSearcher;
  final bool nightMode;

  @override
  State<PdfSearchPanel> createState() => _PdfSearchPanelState();
}

class _PdfSearchPanelState extends State<PdfSearchPanel> {
  final _searchTextController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.textSearcher.addListener(_onSearcherChanged);
    _searchTextController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    widget.textSearcher.removeListener(_onSearcherChanged);
    _searchTextController.removeListener(_onQueryChanged);
    _scrollController.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    widget.textSearcher.startTextSearch(_searchTextController.text);
  }

  void _onSearcherChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _goToNextMatch() async {
    await widget.textSearcher.goToNextMatch();
    _revealCurrent();
  }

  Future<void> _goToPrevMatch() async {
    await widget.textSearcher.goToPrevMatch();
    _revealCurrent();
  }

  Future<void> _goToMatchAt(int index) async {
    await widget.textSearcher.goToMatchOfIndex(index);
    _revealCurrent();
  }

  void _revealCurrent() {
    if (!_scrollController.hasClients) return;
    final index = widget.textSearcher.currentIndex;
    if (index == null) return;
    final target = 44.0 * index.toDouble();
    final position = _scrollController.position;
    _scrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searcher = widget.textSearcher;
    final matches = searcher.matches;
    final isSearching = searcher.isSearching;
    final hasQuery = _searchTextController.text.isNotEmpty;

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
                  controller: _searchTextController,
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
                onPressed: matches.isEmpty ? null : _goToPrevMatch,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                tooltip: 'Next match',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: matches.isEmpty ? null : _goToNextMatch,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: hasQuery
                    ? () {
                        _searchTextController.clear();
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
                  controller: _scrollController,
                  itemExtent: 44,
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _ResultTile(
                    match: matches[index],
                    isCurrent: index == searcher.currentIndex,
                    onTap: () => _goToMatchAt(index),
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
