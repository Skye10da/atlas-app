import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.brandPrimary,
    required this.brandSecondary,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.elevation0,
    required this.elevation1,
    required this.elevation2,
    required this.elevation3,
    required this.opacityDisabled,
    required this.opacityHover,
    required this.opacityPress,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  });

  final Color brandPrimary;
  final Color brandSecondary;
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double elevation0;
  final double elevation1;
  final double elevation2;
  final double elevation3;
  final double opacityDisabled;
  final double opacityHover;
  final double opacityPress;
  final Shadow shadowSm;
  final Shadow shadowMd;
  final Shadow shadowLg;

  @override
  AppThemeTokens copyWith({
    Color? brandPrimary,
    Color? brandSecondary,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? elevation0,
    double? elevation1,
    double? elevation2,
    double? elevation3,
    double? opacityDisabled,
    double? opacityHover,
    double? opacityPress,
    Shadow? shadowSm,
    Shadow? shadowMd,
    Shadow? shadowLg,
  }) {
    return AppThemeTokens(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      elevation0: elevation0 ?? this.elevation0,
      elevation1: elevation1 ?? this.elevation1,
      elevation2: elevation2 ?? this.elevation2,
      elevation3: elevation3 ?? this.elevation3,
      opacityDisabled: opacityDisabled ?? this.opacityDisabled,
      opacityHover: opacityHover ?? this.opacityHover,
      opacityPress: opacityPress ?? this.opacityPress,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
    );
  }

  @override
  AppThemeTokens lerp(AppThemeTokens? other, double t) {
    if (other == null) return this;
    return AppThemeTokens(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t)!,
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      elevation0: lerpDouble(elevation0, other.elevation0, t)!,
      elevation1: lerpDouble(elevation1, other.elevation1, t)!,
      elevation2: lerpDouble(elevation2, other.elevation2, t)!,
      elevation3: lerpDouble(elevation3, other.elevation3, t)!,
      opacityDisabled: lerpDouble(opacityDisabled, other.opacityDisabled, t)!,
      opacityHover: lerpDouble(opacityHover, other.opacityHover, t)!,
      opacityPress: lerpDouble(opacityPress, other.opacityPress, t)!,
      shadowSm: Shadow(
        blurRadius: lerpDouble(
          shadowSm.blurRadius,
          other.shadowSm.blurRadius,
          t,
        )!,
        offset: Offset.lerp(shadowSm.offset, other.shadowSm.offset, t)!,
        color: Color.lerp(shadowSm.color, other.shadowSm.color, t)!,
      ),
      shadowMd: Shadow(
        blurRadius: lerpDouble(
          shadowMd.blurRadius,
          other.shadowMd.blurRadius,
          t,
        )!,
        offset: Offset.lerp(shadowMd.offset, other.shadowMd.offset, t)!,
        color: Color.lerp(shadowMd.color, other.shadowMd.color, t)!,
      ),
      shadowLg: Shadow(
        blurRadius: lerpDouble(
          shadowLg.blurRadius,
          other.shadowLg.blurRadius,
          t,
        )!,
        offset: Offset.lerp(shadowLg.offset, other.shadowLg.offset, t)!,
        color: Color.lerp(shadowLg.color, other.shadowLg.color, t)!,
      ),
    );
  }
}
