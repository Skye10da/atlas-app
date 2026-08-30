import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Grid of page thumbnails for quick navigation.
class PdfThumbnailsPanel extends StatelessWidget {
  const PdfThumbnailsPanel({
    super.key,
    required this.document,
    required this.currentPage,
    required this.onPageSelected,
    this.nightMode = false,
  });

  final PdfDocument? document;
  final int currentPage;
  final void Function(int pageNumber) onPageSelected;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final document = this.document;

    if (document == null || document.pages.isEmpty) {
      return Center(
        child: Text(
          'Document not ready',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.72,
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
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                    border: Border.all(
                      color: isCurrent
                          ? colors.primary
                          : colors.outlineVariant.withValues(alpha: 0.5),
                      width: isCurrent ? 2 : 1,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PdfPageView(
                    document: document,
                    pageNumber: pageNumber,
                    maximumDpi: 90,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$pageNumber',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
