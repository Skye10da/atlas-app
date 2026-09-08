import 'package:flutter/material.dart';
import 'package:atlas_app/core/router/app_router.dart';

class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({
    super.key,
    required this.totalBooks,
    required this.totalChapters,
    required this.totalHours,
  });

  final int totalBooks;
  final int totalChapters;
  final int totalHours;

  String _formatChapters(int ch) {
    if (ch >= 1000000) {
      return '${(ch / 1000000).toStringAsFixed(1)}M';
    }
    if (ch >= 1000) {
      return '${(ch / 1000).toStringAsFixed(1)}K';
    }
    return ch.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: '📚',
            value: '$totalBooks',
            label: 'Books',
            onTap: () => AppRouter.openAnalytics(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: '📖',
            value: _formatChapters(totalChapters),
            label: 'Chapters',
            onTap: () => AppRouter.openAnalytics(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: '⏱️',
            value: '${totalHours}h',
            label: 'Reading',
            onTap: () => AppRouter.openAnalytics(context),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

