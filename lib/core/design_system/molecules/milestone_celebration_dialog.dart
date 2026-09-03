import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

enum MilestoneType {
  firstBookFinished(
    title: 'First Story Conquered! 🏆',
    subtitle: 'You completed your first entire book.',
    icon: Icons.emoji_events_rounded,
    accentColor: Color(0xFFFFD700),
  ),
  fiveBooksFinished(
    title: 'Literary Adventurer! 📚',
    subtitle: '5 novels completed and added to your hall of fame.',
    icon: Icons.auto_stories_rounded,
    accentColor: Color(0xFF64B5F6),
  ),
  tenBooksFinished(
    title: 'Grandmaster Reader! 👑',
    subtitle: '10 entire novels conquered. An unmatched feat.',
    icon: Icons.workspace_premium_rounded,
    accentColor: Color(0xFFFFB300),
  ),
  streakThreeDays(
    title: '3-Day Reading Streak! 🔥',
    subtitle: 'Your reading momentum is heating up.',
    icon: Icons.local_fire_department_rounded,
    accentColor: Color(0xFFFF7043),
  ),
  streakSevenDays(
    title: '1-Week Reading Mastery! ⚡',
    subtitle: '7 days of uninterrupted reading focus.',
    icon: Icons.bolt_rounded,
    accentColor: Color(0xFFFFCA28),
  ),
  streakThirtyDays(
    title: '30-Day Dedication! 💎',
    subtitle: 'A whole month of continuous devotion to stories.',
    icon: Icons.diamond_rounded,
    accentColor: Color(0xFF4DD0E1),
  ),
  hundredChapters(
    title: 'Century Milestone! 💯',
    subtitle: '100 chapters read across your library.',
    icon: Icons.military_tech_rounded,
    accentColor: Color(0xFF81C784),
  ),
  thousandChapters(
    title: 'Mythic Reader! 🌟',
    subtitle: '1,000 chapters read. Reality bows to your imagination.',
    icon: Icons.star_rounded,
    accentColor: Color(0xFFBA68C8),
  );

  const MilestoneType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}

class MilestoneCelebrationDialog extends HookWidget {
  const MilestoneCelebrationDialog({
    super.key,
    required this.milestone,
    this.customMessage,
  });

  final MilestoneType milestone;
  final String? customMessage;

  static Future<void> show(
    BuildContext context, {
    required MilestoneType milestone,
    String? customMessage,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MilestoneCelebrationDialog(
        milestone: milestone,
        customMessage: customMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 1600),
    );

    final scaleAnimation = useMemoized(
      () => CurvedAnimation(
        parent: animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
      [animController],
    );

    final fadeAnimation = useMemoized(
      () => CurvedAnimation(
        parent: animController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
      [animController],
    );

    useEffect(() {
      animController.forward();
      return null;
    }, const []);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Confetti & Particle Burst
          Positioned.fill(
            child: AnimatedBuilder(
              animation: animController,
              builder: (_, _) => CustomPaint(
                painter: _ConfettiPainter(
                  progress: animController.value,
                  baseColor: milestone.accentColor,
                ),
              ),
            ),
          ),

          // 2. Main Celebration Card
          ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                  border: Border.all(
                    color: milestone.accentColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: milestone.accentColor.withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Emblem with Glow
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: milestone.accentColor.withValues(alpha: 0.18),
                        border: Border.all(
                          color: milestone.accentColor,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: milestone.accentColor.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          milestone.icon,
                          size: 38,
                          color: milestone.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Milestone Title
                    Text(
                      milestone.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Subtitle / Achievement Message
                    Text(
                      customMessage ?? milestone.subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // CTA Buttons
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: milestone.accentColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusFull,
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Keep Reading ✨',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.baseColor}) {
    _initParticles();
  }

  final double progress;
  final Color baseColor;

  static final List<({double angle, double distance, double size, Color color, double spin})>
      _particles = [];

  void _initParticles() {
    if (_particles.isNotEmpty) return;
    final random = math.Random(42);
    final colors = [
      baseColor,
      const Color(0xFFFFD700),
      const Color(0xFFFF4081),
      const Color(0xFF00E676),
      const Color(0xFF00B0FF),
      const Color(0xFFFF9100),
      const Color(0xFFE040FB),
    ];

    for (int i = 0; i < 48; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = 90.0 + random.nextDouble() * 160.0;
      final size = 5.0 + random.nextDouble() * 7.0;
      final color = colors[random.nextInt(colors.length)];
      final spin = (random.nextDouble() - 0.5) * 6;
      _particles.add((
        angle: angle,
        distance: distance,
        size: size,
        color: color,
        spin: spin,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in _particles) {
      final currentDistance = p.distance * math.sin(progress * math.pi / 2);
      final x = center.dx + math.cos(p.angle) * currentDistance;
      final y = center.dy +
          math.sin(p.angle) * currentDistance +
          (progress * progress * 50); // slight gravity

      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * progress * math.pi);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.7,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

