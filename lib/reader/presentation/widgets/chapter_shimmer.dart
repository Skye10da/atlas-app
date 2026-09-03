import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

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
class ChapterShimmer extends HookWidget {
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
    final opacity = useState(0.0);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        opacity.value = 1.0;
      });
      return null;
    }, const []);

    final colors = vt.resolve(Theme.of(context).colorScheme);
    final shimmer = chapterShimmerEffect(colors);

    final skeletonTheme = SkeletonizerConfigData(
      effect: shimmer,
      containersColor: colors.background,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      opacity: opacity.value,
      child: SkeletonizerConfig(
        data: skeletonTheme,
        child: Skeletonizer(
          enabled: true,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: _padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeaders) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildHeader(colors),
                  const SizedBox(height: AppSpacing.xxl),
                ],
                _buildBody(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ReadingColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Bone(
          width: 120,
          height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: AppSpacing.md),
        Bone(
          width: double.infinity,
          height: 28,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: AppSpacing.sm),
        Bone(
          width: 220,
          height: 28,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  Widget _buildBody(ReadingColors colors) {
    // Generate varying line widths to look like real paragraphs with breaks.
    final lineWidths = <double>[
      1.0, 0.95, 0.98, 0.75, // Paragraph 1 end
      1.0, 0.92, 0.97, 0.88, 0.60, // Paragraph 2 end
      1.0, 0.96, 0.82, // Paragraph 3 end
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < bodyLines; i++) ...[
          Bone(
            width: double.infinity,
            height: fontSize * 0.75,
            borderRadius: BorderRadius.circular(4),
          ),
          if (lineWidths[i % lineWidths.length] < 0.8)
            SizedBox(height: fontSize * lineHeight)
          else
            SizedBox(height: fontSize * (lineHeight - 0.75)),
        ],
      ],
    );
  }
}

/// A shimmer variant that overlays the current backend load phase label
/// (e.g. "Getting text", "Processing text", "Preparing reader") over the
/// skeleton so the user sees live progress instead of an indefinite loader.
class ChapterStatusShimmer extends ConsumerWidget {
  const ChapterStatusShimmer({
    super.key,
    required this.chapter,
    required this.vt,
    this.fontSize = 20,
    this.lineHeight = 1.8,
  });

  final ChapterEntity chapter;
  final ReadingViewTheme vt;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(chapterLoadPhaseProvider(chapter));
    final colors = vt.resolve(Theme.of(context).colorScheme);

    return Stack(
      children: [
        ChapterShimmer(
          vt: vt,
          fontSize: fontSize,
          lineHeight: lineHeight,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.xxl,
          child: Center(
            child: _StatusPill(
              phase: phase,
              colors: colors,
            ),
          ),
        ),
      ],
    );
  }
}

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

    return Positioned(
      left: 0,
      right: 0,
      bottom: AppSpacing.xxl,
      child: Center(
        child: _StatusPill(
          phase: phase,
          colors: colors,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.phase,
    required this.colors,
  });

  final ChapterLoadPhase phase;
  final ReadingColors colors;

  @override
  Widget build(BuildContext context) {
    final bg = colors.surface.withValues(alpha: 0.92);
    final fg = colors.text.withValues(alpha: 0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        border: Border.all(
          color: colors.surface,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BouncingDots(color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              phase.label,
              key: ValueKey(phase),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three small dots that bounce in sequence to indicate ongoing work.
class _BouncingDots extends HookWidget {
  const _BouncingDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(() {
      controller.repeat();
      return null;
    }, const []);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final start = i * 0.2;
        final end = (start + 0.4).clamp(0.0, 1.0);
        final anim = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: -4)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: -4, end: 0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(start, end, curve: Curves.linear),
          ),
        );

        return AnimatedBuilder(
          animation: anim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, anim.value),
              child: child,
            );
          },
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 3 : 0),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
