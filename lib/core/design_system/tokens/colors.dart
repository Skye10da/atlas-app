import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1A73E8);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD3E3FD);
  static const onPrimaryContainer = Color(0xFF041E49);

  static const secondary = Color(0xFF5F6368);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE8EAED);
  static const onSecondaryContainer = Color(0xFF1F1F1F);

  static const surface = Color(0xFFFFFBFE);
  static const onSurface = Color(0xFF1C1B1F);
  static const surfaceVariant = Color(0xFFE7E0EC);
  static const onSurfaceVariant = Color(0xFF49454F);

  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFF9DEDC);
  static const onErrorContainer = Color(0xFF410E0B);

  static const outline = Color(0xFF79747E);
  static const outlineVariant = Color(0xFFCAC4D0);

  static const readerBackground = Color(0xFFF5F0E8);
  static const readerBackgroundDark = Color(0xFF1A1A1A);
  static const readerSepia = Color(0xFFF5F0E8);
  static const readerText = Color(0xFF1C1B1F);
  static const readerTextDark = Color(0xFFE3E3E3);

  // Semantic App Accent & Atmosphere Tokens
  static const parchment = Color(0xFFF5F0E6);
  static const aiViolet = Color(0xFF7C3AED);
  static const aiIndigo = Color(0xFF4F46E5);
  static const successSurface = Color(0xFFE8F5E9);

  // Warm library palette (Atlas default theme / mockup frames E-F-G).
  // Fixed neutrals of the parchment look; accents still flow from the
  // active AppBrand via colorScheme.
  static const surfaceCard = Color(0xFFFBF8F1);
  static const ink = Color(0xFF1E1B16);
  static const inkMuted = Color(0xFF6B6458);
  static const brandGreen = Color(0xFF2F5D50);
  static const greenTint = Color(0xFFDCE8E1);
  static const mint = Color(0xFF8FD3B6);
  static const sage = Color(0xFFB3CCC1);
  static const terracotta = Color(0xFFB5532A);
  static const hairline = Color(0xFFE4DCCB);
  static const hairlineStrong = Color(0xFFCFC5AF);
}
