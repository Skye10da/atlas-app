import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ImportProgressDialog extends HookWidget {
  const ImportProgressDialog({
    super.key,
    required this.future,
    this.progress,
    this.label = 'Importing...',
  });

  final Future<void> future;

  /// Optional real import progress (0.0 → 1.0). When null, the ring's sweep
  /// animation drives the displayed percentage.
  final ValueListenable<double>? progress;

  /// Status text shown under the progress ring.
  final String label;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    final done = useState(false);
    if (progress != null) useListenable(progress!);

    useEffect(() {
      controller.repeat();

      future.then((_) {
        if (!context.mounted) return;
        controller.stop();
        controller.duration = const Duration(milliseconds: 600);
        controller.forward(from: 0).then((_) {
          if (!context.mounted) return;
          done.value = true;
          controller.duration = const Duration(milliseconds: 400);
          controller.forward(from: 0).then((_) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            });
          });
        });
      }).catchError((_) {
        if (!context.mounted) return;
        Navigator.of(context).pop(false);
      });

      return null;
    }, const []);

    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SizedBox(
        width: 160,
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (ctx, _) {
                final real = progress?.value;
                final percent =
                    (real ?? controller.value).clamp(0.0, 1.0) * 100;
                return SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ProgressPainter(
                        progress: controller.value,
                        done: done.value,
                        color: done.value ? const Color(0xFF34C759) : cs.primary,
                        size: 72,
                      ),
                      Text(
                        done.value ? '100%' : '${percent.round()}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: done.value ? const Color(0xFF34C759) : cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              done.value ? 'Done' : label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressPainter extends StatelessWidget {
  const ProgressPainter({
    super.key,
    required this.progress,
    required this.done,
    required this.color,
    required this.size,
  });

  final double progress;
  final bool done;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircleCheckPainter(
          progress: progress,
          done: done,
          color: color,
        ),
      ),
    );
  }
}

class _CircleCheckPainter extends CustomPainter {
  _CircleCheckPainter({
    required this.progress,
    required this.done,
    required this.color,
  });

  final double progress;
  final bool done;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (done) {
      final morphProgress = (progress * 2).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        radius,
        paint..color = color.withValues(alpha: 1.0 - morphProgress * 0.6),
      );

      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final scale = 0.3 + 0.7 * morphProgress;
      final bounce = 1.0 + 0.15 * (1.0 - (morphProgress * 2 - 1).abs());

      final path = Path();
      final startX = center.dx - radius * 0.3 * scale * bounce;
      final startY = center.dy;
      final midX = center.dx - radius * 0.05 * scale * bounce;
      final midY = center.dy + radius * 0.35 * scale * bounce;
      final endX = center.dx + radius * 0.45 * scale * bounce;
      final endY = center.dy - radius * 0.3 * scale * bounce;

      final drawLength = (morphProgress * 2).clamp(0.0, 1.0);
      if (drawLength < 0.5) {
        final t = drawLength / 0.5;
        path.moveTo(startX, startY);
        path.lineTo(startX + (midX - startX) * t, startY + (midY - startY) * t);
      } else {
        final t = (drawLength - 0.5) / 0.5;
        path.moveTo(startX, startY);
        path.lineTo(midX, midY);
        path.lineTo(midX + (endX - midX) * t, midY + (endY - midY) * t);
      }

      canvas.drawPath(path, checkPaint);
    } else {
      const startAngle = -math.pi / 2;
      final sweepAngle = math.pi * 2 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepAngle * 0.8,
        sweepAngle * 0.2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleCheckPainter old) =>
      old.progress != progress || old.done != done || old.color != color;
}
