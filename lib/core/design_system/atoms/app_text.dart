import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.style = AppTextStyle.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  const AppText.headlineLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.headlineLarge;

  const AppText.headlineMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.headlineMedium;

  const AppText.titleLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.titleLarge;

  const AppText.titleMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.titleMedium;

  const AppText.bodyLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.bodyLarge;

  const AppText.bodyMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.bodyMedium;

  const AppText.bodySmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.bodySmall;

  const AppText.labelLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.labelLarge;

  const AppText.labelSmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : style = AppTextStyle.labelSmall;

  final String text;
  final AppTextStyle style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = _resolveStyle(theme);

    return Text(
      text,
      style: textStyle?.copyWith(color: color),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextStyle? _resolveStyle(ThemeData theme) {
    return switch (style) {
      AppTextStyle.headlineLarge => theme.textTheme.headlineLarge,
      AppTextStyle.headlineMedium => theme.textTheme.headlineMedium,
      AppTextStyle.titleLarge => theme.textTheme.titleLarge,
      AppTextStyle.titleMedium => theme.textTheme.titleMedium,
      AppTextStyle.bodyLarge => theme.textTheme.bodyLarge,
      AppTextStyle.bodyMedium => theme.textTheme.bodyMedium,
      AppTextStyle.bodySmall => theme.textTheme.bodySmall,
      AppTextStyle.labelLarge => theme.textTheme.labelLarge,
      AppTextStyle.labelSmall => theme.textTheme.labelSmall,
    };
  }
}

enum AppTextStyle {
  headlineLarge,
  headlineMedium,
  titleLarge,
  titleMedium,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelSmall,
}
