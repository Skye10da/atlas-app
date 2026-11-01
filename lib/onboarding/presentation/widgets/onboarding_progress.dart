import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/animation.dart';

/// Row of dots showing position in the flow; the active one stretches.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: 'Step ${current + 1} of $total',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: reduceMotion ? Duration.zero : AppAnimation.fast,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 8,
                width: i == current ? 24 : 8,
                decoration: BoxDecoration(
                  color: i == current ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
