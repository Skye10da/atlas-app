import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

/// Overlay that dims the reader when native brightness is unsupported
/// (Web, Linux, or Windows without DDC/CI) and the user has disabled
/// `followSystemBrightness`.
///
/// On capable native platforms this widget renders nothing and the
/// OS brightness API is used via [PlatformService.setBrightness].
class BrightnessOverlay extends ConsumerWidget {
  const BrightnessOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();
    if (settings.followSystemBrightness) return const SizedBox.shrink();

    final isOverlayPlatform =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;
    if (isOverlayPlatform) return _buildDimOverlay(settings.brightness);

    // On non-overlay native platforms (macOS/Android/iOS), check whether
    // native brightness is actually available via a cached probe.
    final nativeAvailable = ref.watch(nativeBrightnessAvailableProvider);
    return nativeAvailable.when(
      data: (available) {
        if (available) return const SizedBox.shrink();
        return _buildDimOverlay(settings.brightness);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _buildDimOverlay(settings.brightness),
    );
  }

  Widget _buildDimOverlay(double brightness) {
    final b = brightness.clamp(0.0, 1.0);
    // Avoid 1.0 opacity overlap: cap dimming at 0.8 so text stays readable.
    // 1.0 brightness -> 0 opacity, 0.0 brightness -> 0.8 dim.
    final opacity = ((1.0 - b) * 0.8).clamp(0.0, 0.8);
    if (opacity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(color: Colors.black.withValues(alpha: opacity)),
    );
  }
}

/// Optional transient indicator shown while dragging brightness.
class BrightnessDragIndicator extends StatelessWidget {
  const BrightnessDragIndicator({
    super.key,
    required this.brightness,
    required this.visible,
  });

  final double brightness;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        color: scheme.surface.withValues(alpha: 0.9),
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                brightness < 0.3
                    ? Icons.brightness_low
                    : brightness > 0.7
                    ? Icons.brightness_high
                    : Icons.brightness_medium,
                size: 28,
                color: scheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                '${(brightness * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
