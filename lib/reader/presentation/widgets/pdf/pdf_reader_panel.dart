import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_markers_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_notes_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_outline_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_search_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_thumbnails_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

/// Left-hand side panel with Search / Outline / Pages / Markers / Notes tabs.
class PdfReaderPanel extends StatelessWidget {
  const PdfReaderPanel({
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
    required this.nightMode,
    super.key,
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
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final nightMode = this.nightMode;
    return Container(
      decoration: BoxDecoration(
        color: nightMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          right: BorderSide(color: nightMode ? Colors.white12 : Colors.black12),
        ),
      ),
      child: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            SizedBox(
              height: 46,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: nightMode ? Colors.white : Colors.black87,
                unselectedLabelColor: nightMode ? Colors.white54 : Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.search), iconMargin: EdgeInsets.zero),
                  Tab(icon: Icon(Icons.menu_book), iconMargin: EdgeInsets.zero),
                  Tab(icon: Icon(Icons.grid_view), iconMargin: EdgeInsets.zero),
                  Tab(icon: Icon(Icons.bookmark), iconMargin: EdgeInsets.zero),
                  Tab(icon: Icon(Icons.sticky_note_2_outlined), iconMargin: EdgeInsets.zero),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSearch(),
                  _buildOutline(),
                  _buildThumbnails(),
                  _buildMarkers(),
                  _buildNotes(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    final searcher = textSearcher;
    if (searcher == null) {
      return _empty('Open document to search');
    }
    return PdfSearchPanel(textSearcher: searcher, nightMode: nightMode);
  }

  Widget _buildOutline() {
    final outline = this.outline;
    if (outline == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfOutlinePanel(outline: outline, onSelected: onOutlineSelected, nightMode: nightMode);
  }

  Widget _buildThumbnails() {
    final document = this.document;
    if (document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfThumbnailsPanel(
      document: document,
      currentPage: currentPage,
      onPageSelected: onPageSelected,
      nightMode: nightMode,
    );
  }

  Widget _buildMarkers() {
    return PdfMarkersPanel(
      markers: markers,
      onSelected: onMarkerSelected,
      onDelete: onMarkerDeleted,
      nightMode: nightMode,
    );
  }

  Widget _buildNotes() {
    return PdfNotesPanel(
      notes: notes,
      onSelected: onNoteSelected,
      onDelete: onNoteDeleted,
      nightMode: nightMode,
    );
  }

  Widget _empty(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: nightMode ? Colors.white70 : Colors.grey),
      ),
    );
  }
}