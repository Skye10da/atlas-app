import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

/// Builds a shimmer color scheme that stays legible across light and dark
/// reading themes by deriving the bone shades from the theme's palette.
ShimmerEffect chapterShimmerEffect(ReadingViewTheme theme) {
  final background = theme.background;
  final text = theme.text;
  return ShimmerEffect(
    baseColor: Color.lerp(background, text, 0.07)!,
    highlightColor: Color.lerp(background, text, 0.15)!,
    duration: const Duration(milliseconds: 1200),
  );
}

/// A reading-page-shaped skeleton rendered as a shimmer while a chapter's
/// content is being fetched, processed and prepared for display.
class ChapterShimmer extends StatelessWidget {
  const ChapterShimmer({
    super.key,
    required this.vt,
    this.showHeaders = true,
    this.fontSize = 20,
    this.lineHeight = 1.8,
    this.bodyLines = 12,
  });

  final ReadingViewTheme vt;
  final bool showHeaders;
  final double fontSize;
  final double lineHeight;
  final int bodyLines;

  EdgeInsetsGeometry get _padding => const EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: vt.background,
      child: Padding(
        padding: _padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0, double.infinity).toDouble();
            final bodyWidth = (width - AppSpacing.lg * 2).toDouble();
            final tileHeight = fontSize * lineHeight;
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Skeletonizer(
                enabled: true,
                effect: chapterShimmerEffect(vt),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeaders) ...[
                      Bone.text(
                        width: bodyWidth * 0.65,
                        fontSize: fontSize * 0.8,
                        style: TextStyle(height: lineHeight),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Bone(
                            width: 84,
                            height: 3,
                            uniRadius: 2,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Bone(
                            width: bodyWidth - 84 - AppSpacing.md,
                            height: 3,
                            uniRadius: 2,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Bone.text(
                        width: bodyWidth * 0.5,
                        fontSize: fontSize * 0.75,
                        style: TextStyle(height: lineHeight),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    for (var i = 0; i < bodyLines; i++) ...[
                      Bone.multiText(
                        width: width,
                        lines: (i.isEven ? 1 : 0) + 1,
                        fontSize: fontSize,
                        style: TextStyle(height: lineHeight),
                        textAlign: TextAlign.start,
                      ),
                      SizedBox(height: tileHeight * (i % 3 == 2 ? 1.4 : 0.8)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A small bottom pill that reports which stage a chapter's load is in while
/// its shimmer is shown: `Getting text → Processing text → Preparing reader → Done`.
class ReaderLoadingOverlay extends ConsumerWidget {
  const ReaderLoadingOverlay({
    super.key,
    required this.chapter,
    required this.vt,
  });

  final ChapterEntity chapter;
  final ReadingViewTheme vt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(chapterLoadPhaseProvider(chapter));
    const steps = ChapterLoadPhase.values;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: vt.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    phase == ChapterLoadPhase.done ? vt.accent : vt.text.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                phase == ChapterLoadPhase.done
                    ? 'Done'
                    : '${phase.label}  ·  ${phase.index + 1} of ${steps.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: vt.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}