import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';

/// Playback-rate dial shared by the Now Playing sheet and the mini player.
///
/// Liquid-glass pill ([GlassCapsule] in pill mode, thrift on the shadow since
/// the control nests inside other cards) showing every [presets] value as a
/// tiny chip. The *selected* rate carries a [GlassLens] droplet, driven by a
/// simple [AnimatedPositioned] — no spring needed at one-row granularity
/// (reader glass pills plan, phase 2). Tapping a chip writes the persisted
/// narration rate so the engine picks it up immediately.
class NarrationSpeedControl extends ConsumerWidget {
  const NarrationSpeedControl({
    super.key,
    required this.accent,
    required this.color,
    this.rateOverride,
    this.onRateChanged,
  });

  static const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final Color accent;
  final Color color;

  /// Test/static host hook: renders as if the narration settings provider
  /// reported this rate. Defaults to null (live provider read).
  final double? rateOverride;

  /// Test/static host hook: receives the chosen preset instead of writing
  /// the narration settings provider. Defaults to null (live apply).
  final ValueChanged<double>? onRateChanged;

  static const _chipWidth = 30.0;
  static const _chipHeight = 26.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = rateOverride ??
        ref.watch(narrationSettingsProvider).valueOrNull?.speechRate ??
        1.0;

    return Tooltip(
      message: 'Playback speed',
      child: GlassCapsule(
        pill: true,
        blur: 18,
        strong: false,
        // Nested inside the mini player card / sheet transport row: save a
        // saveLayer per stacked glass (plan risk note).
        skipDropShadow: true,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Icon(Icons.speed, size: 14, color: accent),
              ),
              _RateDial(
                rate: rate,
                accent: accent,
                color: color,
                onRateChanged: (r) => _setRate(ref, r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setRate(WidgetRef ref, double rate) {
    HapticFeedback.selectionClick();
    final callback = onRateChanged;
    if (callback != null) {
      callback(rate);
      return;
    }
    final settings = ref.read(narrationSettingsProvider).value;
    if (settings == null) return;
    ref
        .read(narrationSettingsProvider.notifier)
        .apply(settings.copyWith(speechRate: rate, clearActiveProfile: true));
  }
}

/// The six-chip strip with the droplet on the active rate.
class _RateDial extends StatelessWidget {
  const _RateDial({
    required this.rate,
    required this.accent,
    required this.color,
    required this.onRateChanged,
  });

  final double rate;
  final Color accent;
  final Color color;
  final ValueChanged<double> onRateChanged;

  @override
  Widget build(BuildContext context) {
    final idx = NarrationSpeedControl.presets
        .indexWhere((p) => (p - rate).abs() < 0.001);
    // Unknown rates highlight the neutral 1.0 chip rather than nothing.
    final selected = idx < 0
        ? NarrationSpeedControl.presets.indexOf(1.0)
        : idx;
    const chipWidth = NarrationSpeedControl._chipWidth;
    const chipHeight = NarrationSpeedControl._chipHeight;
    final disabled = MediaQuery.disableAnimationsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: chipWidth * NarrationSpeedControl.presets.length,
      height: chipHeight,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: disabled ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: selected * chipWidth,
            top: 0,
            width: chipWidth,
            height: chipHeight,
            child: GlassLens(accent: accent, isDark: isDark, radius: chipHeight / 2),
          ),
          Row(
            children: [
              for (var i = 0; i < NarrationSpeedControl.presets.length; i++)
                Expanded(child: _chip(context, i, i == selected)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, int slot, bool selected) {
    final rate = NarrationSpeedControl.presets[slot];
    return InkWell(
      borderRadius: BorderRadius.circular(
        NarrationSpeedControl._chipHeight / 2,
      ),
      onTap: () => onRateChanged(rate),
      child: Center(
        child: Text(
          _formatRate(rate),
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? accent : color.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  String _formatRate(double r) {
    final trimmed =
        r.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '${trimmed.isEmpty ? '0' : trimmed}×';
  }
}
