import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

class CoverPalette {
  const CoverPalette({
    required this.dominant,
    required this.dark,
    required this.accent,
  });

  final Color dominant;
  final Color dark;
  final Color accent;

  static const fallback = CoverPalette(
    dominant: Color(0xFF1A73E8),
    dark: Color(0xFF0F172A),
    accent: Color(0xFF60A5FA),
  );
}

final coverPaletteServiceProvider = Provider((ref) => CoverPaletteService());

final coverPaletteProvider =
    FutureProvider.family<CoverPalette, String?>((ref, coverPath) async {
  if (coverPath == null || coverPath.isEmpty) return CoverPalette.fallback;
  final service = ref.watch(coverPaletteServiceProvider);
  return service.extractPalette(coverPath);
});

class CoverPaletteService {
  final Map<String, CoverPalette> _cache = {};

  Future<CoverPalette> extractPalette(String coverPath) async {
    if (_cache.containsKey(coverPath)) {
      return _cache[coverPath]!;
    }

    try {
      final file = File(coverPath);
      if (!await file.exists()) {
        return CoverPalette.fallback;
      }

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return CoverPalette.fallback;
      }

      // Fast downsample to 16x16
      final thumbnail = img.copyResize(decoded, width: 16, height: 16);

      int totalR = 0;
      int totalG = 0;
      int totalB = 0;
      int count = 0;

      for (int y = 0; y < thumbnail.height; y++) {
        for (int x = 0; x < thumbnail.width; x++) {
          final pixel = thumbnail.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // Filter out near-white or extreme pure black pixels
          final brightness = (r * 299 + g * 587 + b * 114) / 1000;
          if (brightness > 20 && brightness < 235) {
            totalR += r;
            totalG += g;
            totalB += b;
            count++;
          }
        }
      }

      if (count == 0) {
        return CoverPalette.fallback;
      }

      final avgR = (totalR / count).round().clamp(0, 255);
      final avgG = (totalG / count).round().clamp(0, 255);
      final avgB = (totalB / count).round().clamp(0, 255);

      final dominantColor = Color.fromARGB(255, avgR, avgG, avgB);
      final hsl = HSLColor.fromColor(dominantColor);

      // Construct a rich, saturated dark tone for backdrop gradients
      final darkColor = hsl
          .withLightness((hsl.lightness * 0.3).clamp(0.08, 0.22))
          .withSaturation((hsl.saturation * 1.1).clamp(0.3, 0.9))
          .toColor();

      // Construct vibrant accent
      final accentColor = hsl
          .withLightness((hsl.lightness * 1.3).clamp(0.55, 0.85))
          .withSaturation((hsl.saturation * 1.2).clamp(0.5, 1.0))
          .toColor();

      final palette = CoverPalette(
        dominant: dominantColor,
        dark: darkColor,
        accent: accentColor,
      );

      _cache[coverPath] = palette;
      return palette;
    } catch (_) {
      return CoverPalette.fallback;
    }
  }
}

