import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _inkController;
  late final AnimationController _lettersController;
  late final AnimationController _subtitleController;
  late final AnimationController _pulseController;

  late final Animation<double> _inkRadiusAnimation;
  late final Animation<double> _subtitleFadeAnimation;
  late final Animation<double> _subtitleSlideAnimation;

  final List<String> _letters = ['A', 't', 'l', 'a', 's'];
  final List<Animation<double>> _letterFadeAnimations = [];
  final List<Animation<double>> _letterSlideAnimations = [];

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Ink bloom controller (0 -> 400ms)
    _inkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _inkRadiusAnimation = CurvedAnimation(
      parent: _inkController,
      curve: Curves.easeOutCubic,
    );

    // 2. Letters controller (staggered cascade 300ms -> 900ms)
    _lettersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    for (var i = 0; i < _letters.length; i++) {
      final start = (i * 0.12).clamp(0.0, 0.6);
      final end = (start + 0.4).clamp(0.0, 1.0);
      final curve = CurvedAnimation(
        parent: _lettersController,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
      _letterFadeAnimations.add(
        CurvedAnimation(
          parent: _lettersController,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
      );
      _letterSlideAnimations.add(
        Tween<double>(begin: 24.0, end: 0.0).animate(curve),
      );
    }

    // 3. Subtitle controller
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _subtitleFadeAnimation = CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    );
    _subtitleSlideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );

    // 4. Subtle pulse controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _runAnimationSequence();
  }

  Future<void> _runAnimationSequence() async {
    await _inkController.forward();
    await _lettersController.forward();
    await _subtitleController.forward();

    // Brief delay to let the reader take in the serene aesthetic
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted && !_navigated) {
      _navigated = true;
      context.go('/discover');
    }
  }

  @override
  void dispose() {
    _inkController.dispose();
    _lettersController.dispose();
    _subtitleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Ink Bloom Background
          AnimatedBuilder(
            animation: _inkRadiusAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _InkBloomPainter(
                  progress: _inkRadiusAnimation.value,
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
                  scale: _inkRadiusAnimation,
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
                      // color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Animated Wordmark letters
                AnimatedBuilder(
                  animation: _lettersController,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_letters.length, (index) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            _letterSlideAnimations[index].value,
                          ),
                          child: Opacity(
                            opacity: _letterFadeAnimations[index].value.clamp(
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
                  animation: _subtitleController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _subtitleSlideAnimation.value),
                      child: Opacity(
                        opacity: _subtitleFadeAnimation.value.clamp(0.0, 1.0),
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
              opacity: _subtitleFadeAnimation,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseController,
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
