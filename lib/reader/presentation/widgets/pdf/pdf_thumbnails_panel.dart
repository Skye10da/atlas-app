import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Grid of page thumbnails for quick navigation.
class PdfThumbnailsPanel extends StatelessWidget {
  const PdfThumbnailsPanel({
    required this.document,
    required this.currentPage,
    required this.onPageSelected,
    required this.nightMode,
    super.key,
  });

  final PdfDocument? document;
  final int currentPage;
  final void Function(int pageNumber) onPageSelected;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final document = this.document;
    if (document == null || document.pages.isEmpty) {
      return Center(
        child: Text(
          'Document not ready',
          style: TextStyle(color: nightMode ? Colors.white70 : Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.707,
      ),
      itemCount: document.pages.length,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final isCurrent = pageNumber == currentPage;
        return GestureDetector(
          onTap: () => onPageSelected(pageNumber),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCurrent
                          ? Colors.amber
                          : (nightMode ? Colors.white24 : Colors.black26),
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: PdfPageView(
                    document: document,
                    pageNumber: pageNumber,
                    maximumDpi: 90,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$pageNumber',
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent
                      ? Colors.amber
                      : (nightMode ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
