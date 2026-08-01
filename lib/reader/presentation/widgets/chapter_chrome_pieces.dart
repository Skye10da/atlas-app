import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';

/// The numbered-circle-plus-title banner shown at the start of a chapter.
/// Built inline (with identical code) by ContinuousReaderLayout's
/// `_buildChapterHeader` and by `_PagedPageView`'s header block — this is
/// the single shared version.
class ChapterHeaderBanner extends StatelessWidget {
  const ChapterHeaderBanner({
    super.key,
    required this.chapterNumber,
    required this.title,
    required this.style,
  });

  /// 1-based chapter number to show inside the circle.
  final int chapterNumber;
  final String title;
  final ChapterStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: style.bannerBackground.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: style.accentColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.accentColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$chapterNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: style.titleStyle)),
        ],
      ),
    );
  }
}

/// The small centered ornamental glyph used above/below chapter content.
class ChapterOrnamentalDivider extends StatelessWidget {
  const ChapterOrnamentalDivider({
    super.key,
    required this.accentColor,
    this.verticalPadding = 8,
  });

  final Color accentColor;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Center(
        child: Text(
          ChapterStyle.ornamentalDivider,
          style: TextStyle(
            color: accentColor.withValues(alpha: 0.4),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// The "— End of Chapter N —" footer shown after the last block/page of a
/// chapter.
class ChapterEndFooter extends StatelessWidget {
  const ChapterEndFooter({
    super.key,
    required this.chapterNumber,
    required this.textColor,
    required this.baseFontSize,
  });

  /// 1-based chapter number.
  final int chapterNumber;
  final Color textColor;
  final double baseFontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Divider(color: textColor.withValues(alpha: 0.15)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '— End of Chapter $chapterNumber —',
            style: TextStyle(
              fontSize: baseFontSize * 0.85,
              color: textColor.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
