import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';

/// Tappable playback-rate pill shared by the Now Playing sheet and the mini
/// player. Tapping cycles through [presets] and writes the persisted
/// narration rate so the engine picks it up immediately.
class NarrationSpeedControl extends ConsumerWidget {
  const NarrationSpeedControl({
    super.key,
    required this.accent,
    required this.color,
  });

  static const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final Color accent;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate =
        ref.watch(narrationSettingsProvider).valueOrNull?.speechRate ?? 1.0;

    return Tooltip(
      message: 'Playback speed',
      child: InkWell(
        onTap: () => _cycle(ref, rate),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                _formatRate(rate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cycle(WidgetRef ref, double current) {
    final idx = presets.indexWhere((p) => (p - current).abs() < 0.001);
    final next = idx < 0 ? presets.last : presets[(idx + 1) % presets.length];
    final settings = ref.read(narrationSettingsProvider).value;
    if (settings == null) return;
    ref
        .read(narrationSettingsProvider.notifier)
        .apply(settings.copyWith(speechRate: next, clearActiveProfile: true));
  }

  String _formatRate(double r) {
    final trimmed = r.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '${trimmed.isEmpty ? '0' : trimmed}×';
  }
}
