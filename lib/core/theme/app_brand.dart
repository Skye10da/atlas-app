import 'package:flutter/material.dart';

enum AppBrand {
  violet,
  emerald,
  ruby,
  sapphire,
  amber,
  rose,
  coral,
  peach,
  lime,
  teal,
  sky,
  indigo,
  slate,
  charcoal;

  Color get seed => switch (this) {
    AppBrand.violet => const Color(0xFF8B5CF6),
    AppBrand.emerald => const Color(0xFF10B981),
    AppBrand.ruby => const Color(0xFFEF4444),
    AppBrand.sapphire => const Color(0xFF3B82F6),
    AppBrand.amber => const Color(0xFFF59E0B),
    AppBrand.rose => const Color(0xFFF43F5E),
    AppBrand.coral => const Color(0xFFFB7185),
    AppBrand.peach => const Color(0xFFFB923C),
    AppBrand.lime => const Color(0xFF84CC16),
    AppBrand.teal => const Color(0xFF14B8A6),
    AppBrand.sky => const Color(0xFF0EA5E9),
    AppBrand.indigo => const Color(0xFF6366F1),
    AppBrand.slate => const Color(0xFF64748B),
    AppBrand.charcoal => const Color(0xFF374151),
  };

  String get label => switch (this) {
    AppBrand.violet => 'Violet',
    AppBrand.emerald => 'Emerald',
    AppBrand.ruby => 'Ruby',
    AppBrand.sapphire => 'Sapphire',
    AppBrand.amber => 'Amber',
    AppBrand.rose => 'Rose',
    AppBrand.coral => 'Coral',
    AppBrand.peach => 'Peach',
    AppBrand.lime => 'Lime',
    AppBrand.teal => 'Teal',
    AppBrand.sky => 'Sky',
    AppBrand.indigo => 'Indigo',
    AppBrand.slate => 'Slate',
    AppBrand.charcoal => 'Charcoal',
  };

  IconData get icon => switch (this) {
    AppBrand.violet => Icons.local_florist,
    AppBrand.emerald => Icons.diamond_outlined,
    AppBrand.ruby => Icons.favorite_outline,
    AppBrand.sapphire => Icons.water_drop_outlined,
    AppBrand.amber => Icons.wb_sunny_outlined,
    AppBrand.rose => Icons.local_fire_department,
    AppBrand.coral => Icons.wb_sunny,
    AppBrand.peach => Icons.light_mode,
    AppBrand.lime => Icons.grass,
    AppBrand.teal => Icons.water,
    AppBrand.sky => Icons.air,
    AppBrand.indigo => Icons.auto_stories,
    AppBrand.slate => Icons.menu_book,
    AppBrand.charcoal => Icons.brightness_2,
  };
}
