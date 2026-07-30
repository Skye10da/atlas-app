import 'package:flutter/material.dart';

class ReaderProgressBar extends StatelessWidget {
  const ReaderProgressBar({
    super.key,
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: color.withValues(alpha: 0.15),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
