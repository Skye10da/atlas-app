import 'package:flutter/material.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_theme.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

/// Presentation-only widget that renders a detected [BlockCard] using
/// the theme resolved for the active reader palette. It knows nothing
/// about detection, parsing, or the AI extractor.
class BlockCardWidget extends StatelessWidget {
  const BlockCardWidget({super.key, required this.card, required this.colors});
  final BlockCard card;
  final ReadingColors colors;

  bool get _useFallback =>
      card.isLowConfidence ||
      (card.type == BlockCardType.custom && card.fields.isEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = resolveBlockCardTheme(card, colors);
    final content = _useFallback ? _buildFallback(theme) : _buildThemed(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: _decorate(theme, content),
    );
  }

  Widget _decorate(BlockCardTheme theme, Widget child) {
    final decoration = BoxDecoration(
      color: theme.background,
      borderRadius: theme.radius,
      boxShadow: theme.shadows,
    );
    final container = Container(
      width: double.infinity,
      decoration: decoration,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );

    if (theme.dashedBorder) {
      return CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: theme.border,
          radius: theme.radius,
        ),
        child: container,
      );
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.background,
        border: theme.cardBorder,
        borderRadius: theme.radius,
        boxShadow: theme.shadows,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _eyebrowRow(BlockCardTheme theme) {
    return Row(
      children: [
        Icon(theme.icon, size: 14, color: theme.glowOrAccent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            theme.label,
            style: theme.eyebrowStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildThemed(BlockCardTheme theme) {
    final tagValues = <String>[...card.tags];
    final fieldWidgets = <Widget>[];

    for (final field in card.fields) {
      switch (field.display) {
        case FieldDisplay.tag:
          if (!tagValues.contains(field.value)) tagValues.add(field.value);
          continue;
        case FieldDisplay.bar:
          fieldWidgets.add(_barField(theme, field));
        case FieldDisplay.list:
          fieldWidgets.add(_listField(theme, field));
        case FieldDisplay.text:
          fieldWidgets.add(_textField(theme, field));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrowRow(theme),
        if (card.title != null && card.title!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(card.title!, style: theme.titleStyle),
        ],
        if (card.subtitle != null && card.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(card.subtitle!, style: theme.labelStyle),
        ],
        if (fieldWidgets.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...intersperse(fieldWidgets, const SizedBox(height: 8)),
        ],
        if (tagValues.isNotEmpty) ...[
          if (fieldWidgets.isNotEmpty) const SizedBox(height: 12),
          _tagRow(theme, tagValues),
        ],
        if (card.footnote != null && card.footnote!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(card.footnote!, style: theme.footnoteStyle),
        ],
      ],
    );
  }

  Widget _buildFallback(BlockCardTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrowRow(theme),
        if (card.title != null && card.title!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(card.title!, style: theme.titleStyle),
        ],
        const SizedBox(height: 8),
        Text(
          card.rawText.trim(),
          style: TextStyle(fontSize: 13, height: 1.5, color: theme.valueColor),
        ),
      ],
    );
  }

  Widget _textField(BlockCardTheme theme, BlockCardField field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, maxWidth: 140),
          child: Text(field.label, style: theme.labelStyle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            field.value,
            style: theme.valueStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _listField(BlockCardTheme theme, BlockCardField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: theme.labelStyle),
        const SizedBox(height: 4),
        Text(field.value, style: theme.valueStyle.copyWith(height: 1.5)),
      ],
    );
  }

  Widget _barField(BlockCardTheme theme, BlockCardField field) {
    final labelKey = field.label.toLowerCase();
    final barColor = theme.barColors[labelKey] ?? theme.glowOrAccent;
    final ratio = field.ratio ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(field.label, style: theme.labelStyle)),
            Text(field.value, style: theme.valueStyle),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: colors.text.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _tagRow(BlockCardTheme theme, List<String> tags) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.tagBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: TextStyle(fontSize: 11.5, color: theme.tagText),
            ),
          ),
      ],
    );
  }

  static List<Widget> intersperse(Iterable<Widget> widgets, Widget separator) {
    final result = <Widget>[];
    final list = widgets.toList();
    for (var i = 0; i < list.length; i++) {
      result.add(list[i]);
      if (i != list.length - 1) result.add(separator);
    }
    return result;
  }
}

/// Paints a dashed rounded-rectangle border, used by the low-confidence
/// fallback theme (Atlas has no dashed-border package dependency).
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    this.radius = BorderRadius.zero,
    this.dashWidth = 5,
    this.dashGap = 4,
    this.strokeWidth = 1,
  });
  final Color color;
  final BorderRadius radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = radius.toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length);
        dashed.addPath(
          metric.extractPath(distance, end.toDouble()),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashGap != dashGap ||
      oldDelegate.strokeWidth != strokeWidth;
}
