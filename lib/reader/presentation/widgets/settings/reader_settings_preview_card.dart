import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ReaderSettingsPreviewCard extends StatelessWidget {
  const ReaderSettingsPreviewCard({
    super.key,
    required this.theme,
    required this.fontSize,
    this.fontFamily,
    this.fontWeight,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textAlignment,
    required this.marginPreset,
  });

  final ReadingViewTheme theme;
  final double fontSize;
  final String? fontFamily;
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final readingColors = theme.resolve(colorScheme);

    final previewFontSize = (fontSize * 0.82).clamp(12.0, 22.0);
    final previewPadding = switch (marginPreset) {
      MarginPreset.narrow => const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      MarginPreset.normal => const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      MarginPreset.wide => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
    };

    final fontDisplayName = fontFamily ?? 'System Font';
    final weightStyle = fontWeight != null ? FontWeight(fontWeight!) : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: readingColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: readingColors.text.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: previewPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header indicator
              Center(
                child: Text(
                  'LIVE READING PREVIEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: readingColors.text.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Chapter Four: The Silent River',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: previewFontSize + 2,
                    fontWeight: FontWeight.w600,
                    color: readingColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Sample prose
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: previewFontSize,
                  height: lineHeight,
                  letterSpacing: letterSpacing,
                  fontWeight: weightStyle,
                  color: readingColors.text,
                ),
                child: Text(
                  'The evening air was crisp and tranquil. A gentle glow from the lantern illuminated the quiet path ahead, whispering tales of forgotten journeys under the starlit sky.',
                  textAlign: textAlignment.flutterTextAlign,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              // Footer chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: readingColors.text.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$fontDisplayName • ${fontSize.round()} pt',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: readingColors.text.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: readingColors.text.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${theme.label} • ${lineHeight.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: readingColors.text.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

