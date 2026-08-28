import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/tokens/animation.dart';

/// [key] must come from `GoRouterState.pageKey`: go_router assigns every
/// imperative push a unique key, so pushing the same location twice stacks two
/// pages instead of tripping Navigator's duplicate-page-key assertion. A
/// hand-written constant key (e.g. `'book_$id'`) defeats that uniqueness.
CustomTransitionPage buildPageTransition({
  required Widget child,
  required ValueKey<String> key,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(
          Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: AppAnimation.defaultCurve)),
        ),
        child: SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: AppAnimation.defaultCurve)),
          ),
          child: child,
        ),
      );
    },
    transitionDuration: AppAnimation.medium,
    reverseTransitionDuration: AppAnimation.fast,
  );
}
