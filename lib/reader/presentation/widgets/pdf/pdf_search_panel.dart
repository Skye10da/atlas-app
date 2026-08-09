import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Text search panel bound to a [PdfTextSearcher] created by the viewer.
class PdfSearchPanel extends StatefulWidget {
  const PdfSearchPanel({required this.textSearcher, required this.nightMode, super.key});

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
    final searcher = widget.textSearcher;
    final matches = searcher.matches;
    final isSearching = searcher.isSearching;
    final hasQuery = _searchTextController.text.isNotEmpty;
    final nightMode = widget.nightMode;

    return Column(
      children: [
        SizedBox(
          height: 2,
          child: isSearching
              ? LinearProgressIndicator(value: searcher.searchProgress, minHeight: 2)
              : null,
        ),
        Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchTextController,
                decoration: const InputDecoration(
                  hintText: 'Search document',
                  isDense: true,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            if (searcher.hasMatches || isSearching)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${(searcher.currentIndex ?? -1) + 1}/${matches.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: nightMode ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: _CompactIconButton(
                icon: Icons.arrow_upward,
                tooltip: 'Previous match',
                onPressed: matches.isEmpty ? null : _goToPrevMatch,
              ),
            ),
            Flexible(
              child: _CompactIconButton(
                icon: Icons.arrow_downward,
                tooltip: 'Next match',
                onPressed: matches.isEmpty ? null : _goToNextMatch,
              ),
            ),
            Flexible(
              child: _CompactIconButton(
                icon: Icons.close,
                tooltip: 'Clear search',
                onPressed: hasQuery
                    ? () {
                        _searchTextController.clear();
                        searcher.resetTextSearch();
                      }
                    : null,
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    hasQuery ? 'No results' : 'Search document',
                    style: TextStyle(color: nightMode ? Colors.white70 : Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemExtent: 44,
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _ResultTile(
                    match: matches[index],
                    isCurrent: index == searcher.currentIndex,
                    nightMode: nightMode,
                    onTap: () => _goToMatchAt(index),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.match,
    required this.isCurrent,
    required this.nightMode,
    required this.onTap,
  });

  final PdfPageTextRange match;
  final bool isCurrent;
  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.amber.withAlpha(90) : null,
          border: Border(
            bottom: BorderSide(color: nightMode ? Colors.white12 : Colors.black12, width: 0.5),
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
                      style: const TextStyle(
                        backgroundColor: Colors.yellow,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: nightMode ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'page ${match.pageNumber}',
              style: TextStyle(
                fontSize: 11,
                color: nightMode ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}