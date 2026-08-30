import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_markers_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_notes_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_outline_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_search_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_thumbnails_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

/// Right-hand side panel (or sheet) for PDF navigation with Outline / Pages /
/// Markers / Notes / Search tabs, matching the [ReaderRightPanel] visual styling.
class PdfReaderPanel extends StatefulWidget {
  const PdfReaderPanel({
    super.key,
    required this.controller,
    required this.document,
    required this.outline,
    required this.textSearcher,
    required this.currentPage,
    required this.markers,
    required this.notes,
    required this.onOutlineSelected,
    required this.onPageSelected,
    required this.onMarkerSelected,
    required this.onMarkerDeleted,
    required this.onNoteSelected,
    required this.onNoteDeleted,
    required this.onClose,
    this.initialTabIndex = 0,
  });

  final PdfViewerController controller;
  final PdfDocument? document;
  final List<PdfOutlineNode>? outline;
  final PdfTextSearcher? textSearcher;
  final int currentPage;
  final List<PdfMarker> markers;
  final List<PdfNoteEntry> notes;
  final void Function(PdfOutlineNode node) onOutlineSelected;
  final void Function(int pageNumber) onPageSelected;
  final void Function(PdfMarker marker) onMarkerSelected;
  final void Function(PdfMarker marker) onMarkerDeleted;
  final void Function(PdfNoteEntry note) onNoteSelected;
  final void Function(PdfNoteEntry note) onNoteDeleted;
  final VoidCallback onClose;
  final int initialTabIndex;

  @override
  State<PdfReaderPanel> createState() => _PdfReaderPanelState();
}

class _PdfReaderPanelState extends State<PdfReaderPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 4,
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'Document',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                  tooltip: 'Close panel',
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
            indicatorColor: colors.primary,
            labelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Outline'),
              Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Pages'),
              Tab(icon: Icon(Icons.bookmark_rounded, size: 18), text: 'Markers'),
              Tab(
                icon: Icon(Icons.sticky_note_2_outlined, size: 18),
                text: 'Notes',
              ),
              Tab(icon: Icon(Icons.search_rounded, size: 18), text: 'Search'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOutline(),
                _buildThumbnails(),
                _buildMarkers(),
                _buildNotes(),
                _buildSearch(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutline() {
    final outline = widget.outline;
    if (outline == null) {
      return Center(
        child: Text(
          'Loading outline…',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return PdfOutlinePanel(
      outline: outline,
      onSelected: widget.onOutlineSelected,
      nightMode: false,
    );
  }

  Widget _buildThumbnails() {
    return PdfThumbnailsPanel(
      document: widget.document,
      currentPage: widget.currentPage,
      onPageSelected: widget.onPageSelected,
      nightMode: false,
    );
  }

  Widget _buildMarkers() {
    return PdfMarkersPanel(
      markers: widget.markers,
      onSelected: widget.onMarkerSelected,
      onDelete: widget.onMarkerDeleted,
      nightMode: false,
    );
  }

  Widget _buildNotes() {
    return PdfNotesPanel(
      notes: widget.notes,
      onSelected: widget.onNoteSelected,
      onDelete: widget.onNoteDeleted,
      nightMode: false,
    );
  }

  Widget _buildSearch() {
    final searcher = widget.textSearcher;
    if (searcher == null) {
      return Center(
        child: Text(
          'Open document to search',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return PdfSearchPanel(textSearcher: searcher, nightMode: false);
  }
}
