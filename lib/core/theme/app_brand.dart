import 'package:flutter/material.dart';

enum AppBrand {
  violet,
  emerald,
  ruby,
  sapphire,
  amber;

  Color get seed => switch (this) {
    AppBrand.violet => const Color(0xFF8B5CF6),
    AppBrand.emerald => const Color(0xFF10B981),
    AppBrand.ruby => const Color(0xFFEF4444),
    AppBrand.sapphire => const Color(0xFF3B82F6),
    AppBrand.amber => const Color(0xFFF59E0B),
  };

  String get label => switch (this) {
    AppBrand.violet => 'Violet',
    AppBrand.emerald => 'Emerald',
    AppBrand.ruby => 'Ruby',
    AppBrand.sapphire => 'Sapphire',
    AppBrand.amber => 'Amber',
  };

  IconData get icon => switch (this) {
    AppBrand.violet => Icons.local_florist,
    AppBrand.emerald => Icons.diamond_outlined,
    AppBrand.ruby => Icons.favorite_outline,
    AppBrand.sapphire => Icons.water_drop_outlined,
    AppBrand.amber => Icons.wb_sunny_outlined,
  };
}
