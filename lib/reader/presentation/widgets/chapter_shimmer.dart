import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

/// Builds a shimmer color scheme that stays legible across light and dark
/// reading themes by deriving the bone shades from the theme's palette.
ShimmerEffect chapterShimmerEffect(ReadingColors colors) {
  final background = colors.background;
  final text = colors.text;
  return ShimmerEffect(
    baseColor: Color.lerp(background, text, 0.07)!,
    highlightColor: Color.lerp(background, text, 0.15)!,
    duration: const Duration(milliseconds: 1200),
  );
}

/// A reading-page-shaped skeleton rendered as a shimmer while a chapter's
/// content is being fetched, processed and prepared for display.
class ChapterShimmer extends StatefulWidget {
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

  @override
  State<ChapterShimmer> createState() => _ChapterShimmerState();
}

class _ChapterShimmerState extends State<ChapterShimmer> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Fade in smoothly after the first frame to avoid a jarring pop-in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  EdgeInsetsGeometry get _padding => const EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _opacity,
      child: Container(
        color: widget.vt.resolve(Theme.of(context).colorScheme).background,
        child: Padding(
          padding: _padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth
                  .clamp(0, double.infinity)
                  .toDouble();
              final bodyWidth = (width - AppSpacing.lg * 2).toDouble();
              final tileHeight = widget.fontSize * widget.lineHeight;
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Skeletonizer(
                  enabled: true,
                  effect: chapterShimmerEffect(
                    widget.vt.resolve(Theme.of(context).colorScheme),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showHeaders) ...[
                        Bone.text(
                          width: bodyWidth * 0.65,
                          fontSize: widget.fontSize * 0.8,
                          style: TextStyle(height: widget.lineHeight),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            const Bone(width: 84, height: 3, uniRadius: 2),
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
                          fontSize: widget.fontSize * 0.75,
                          style: TextStyle(height: widget.lineHeight),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      for (var i = 0; i < widget.bodyLines; i++) ...[
                        Bone.multiText(
                          width: width,
                          lines: (i.isEven ? 1 : 0) + 1,
                          fontSize: widget.fontSize,
                          style: TextStyle(height: widget.lineHeight),
                          textAlign: TextAlign.start,
                        ),
                        SizedBox(
                          height: tileHeight * (i % 3 == 2 ? 1.4 : 0.8),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A bottom overlay that shows a chapter title, animated progress bar,
/// and bouncing dots while the chapter content loads. Replaces the old
/// text-based phase pill with a more informative and visually engaging design.
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
    final colors = vt.resolve(Theme.of(context).colorScheme);

    // Progress value: 0.0 → 0.25 → 0.5 → 0.75 → 1.0
    final progress = (phase.index + 1) / ChapterLoadPhase.values.length;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chapter title
            Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.text.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            // Progress bar
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: 3,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: colors.text.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      height: 3,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            // Bouncing dots + step label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BouncingDots(color: colors.text.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  '${phase.index + 1}/${ChapterLoadPhase.values.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.text.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Three small dots that bounce in sequence to indicate ongoing work.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots({required this.color});

  final Color color;

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -4).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    while (mounted) {
      for (var i = 0; i < _controllers.length; i++) {
        if (!mounted) return;
        await _controllers[i].forward();
        if (!mounted) return;
        await _controllers[i].reverse();
      }
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        );
      }),
    );
  }
}
