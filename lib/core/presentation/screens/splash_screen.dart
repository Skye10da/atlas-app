import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class SplashScreen extends HookWidget {
  const SplashScreen({super.key});

  static const List<String> _letters = ['A', 't', 'l', 'a', 's'];

  @override
  Widget build(BuildContext context) {
    // 1. Ink bloom controller (0 -> 400ms)
    final inkController = useAnimationController(
      duration: const Duration(milliseconds: 450),
    );
    final inkRadiusAnimation = useMemoized(
      () => CurvedAnimation(
        parent: inkController,
        curve: Curves.easeOutCubic,
      ),
      [inkController],
    );

    // 2. Letters controller (staggered cascade 300ms -> 900ms)
    final lettersController = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );

    final letterAnimations = useMemoized(() {
      final fades = <Animation<double>>[];
      final slides = <Animation<double>>[];
      for (var i = 0; i < _letters.length; i++) {
        final start = (i * 0.12).clamp(0.0, 0.6);
        final end = (start + 0.4).clamp(0.0, 1.0);
        final curve = CurvedAnimation(
          parent: lettersController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        );
        fades.add(
          CurvedAnimation(
            parent: lettersController,
            curve: Interval(start, end, curve: Curves.easeIn),
          ),
        );
        slides.add(
          Tween<double>(begin: 24.0, end: 0.0).animate(curve),
        );
      }
      return (fades: fades, slides: slides);
    }, [lettersController]);

    // 3. Subtitle controller
    final subtitleController = useAnimationController(
      duration: const Duration(milliseconds: 400),
    );
    final subtitleFadeAnimation = useMemoized(
      () => CurvedAnimation(
        parent: subtitleController,
        curve: Curves.easeIn,
      ),
      [subtitleController],
    );
    final subtitleSlideAnimation = useMemoized(
      () => Tween<double>(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(parent: subtitleController, curve: Curves.easeOut),
      ),
      [subtitleController],
    );

    // 4. Subtle pulse controller
    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    final navigated = useRef(false);

    useEffect(() {
      pulseController.repeat(reverse: true);

      Future<void> runSequence() async {
        await inkController.forward();
        await lettersController.forward();
        await subtitleController.forward();

        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (context.mounted && !navigated.value) {
          navigated.value = true;
          context.go('/discover');
        }
      }

      runSequence();
      return null;
    }, const []);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Ink Bloom Background
          AnimatedBuilder(
            animation: inkRadiusAnimation,
            builder: (ctx, child) {
              return CustomPaint(
                painter: _InkBloomPainter(
                  progress: inkRadiusAnimation.value,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  accentColor: colorScheme.secondary.withValues(alpha: 0.06),
                ),
              );
            },
          ),

          // Central Brand Lockup
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Atlas Compass Emblem (◈)
                ScaleTransition(
                  scale: inkRadiusAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Animated Wordmark letters
                AnimatedBuilder(
                  animation: lettersController,
                  builder: (ctx, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_letters.length, (index) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            letterAnimations.slides[index].value,
                          ),
                          child: Opacity(
                            opacity: letterAnimations.fades[index].value.clamp(
                              0.0,
                              1.0,
                            ),
                            child: Text(
                              _letters[index],
                              style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                AnimatedBuilder(
                  animation: subtitleController,
                  builder: (ctx, child) {
                    return Transform.translate(
                      offset: Offset(0, subtitleSlideAnimation.value),
                      child: Opacity(
                        opacity: subtitleFadeAnimation.value.clamp(0.0, 1.0),
                        child: Text(
                          'Your sanctuary for stories',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom loading state
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xxl,
            child: FadeTransition(
              opacity: subtitleFadeAnimation,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: pulseController,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Opening your library…',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InkBloomPainter extends CustomPainter {
  const _InkBloomPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
  });

  final double progress;
  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.85;
    final radius = maxRadius * progress;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, accentColor, Colors.transparent],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_InkBloomPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
