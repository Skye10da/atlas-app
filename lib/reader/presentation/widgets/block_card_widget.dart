import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_intelligence.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_theme.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';

/// Renders a detected [BlockCard] using the theme resolved for the active
/// reader palette. Also exposes a local-only intelligence menu
/// (confirm / not a card / change type) that writes to `story_corrections`
/// with `entity_type='block_card'` and `book_id=<bookId>` — no global,
/// no AI second-pass.
class BlockCardWidget extends StatelessWidget {
  const BlockCardWidget({
    super.key,
    required this.card,
    required this.colors,
    this.fontSize = 18,
    this.bookId,
  });
  final BlockCard card;
  final ReadingColors colors;

  /// Current reader body font size — drives theme typography scaling
  /// so card text stays in lockstep with prose.
  final double fontSize;

  /// Book that owns the chapter containing [card]. When null the feedback
  /// menu is hidden (e.g. in widget tests).
  final String? bookId;

  bool get _useFallback =>
      card.isLowConfidence ||
      (card.type == BlockCardType.custom && card.fields.isEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = resolveBlockCardTheme(card, colors, fontSize);
    final content = _useFallback
        ? _buildFallback(theme, context)
        : _buildThemed(theme, context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _decorate(theme, content),
    );
  }

  Widget _decorate(BlockCardTheme theme, Widget child) {
    // Accent stripe flair — left 4px bar + subtle inner highlight so
    // cards are instantly distinct from prose at any reader theme.
    final inner = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: theme.radius,
        boxShadow: theme.shadows,
      ),
      child: ClipRRect(
        borderRadius: theme.radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.glowOrAccent, width: 4),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all((fontSize * 0.85).clamp(14.0, 18.0)),
            child: child,
          ),
        ),
      ),
    );

    if (theme.dashedBorder) {
      return CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: theme.border,
          radius: theme.radius,
        ),
        child: inner,
      );
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: theme.cardBorder,
        borderRadius: theme.radius,
        boxShadow: theme.shadows,
      ),
      child: inner,
    );
  }

  Widget _eyebrowRow(BlockCardTheme theme, BuildContext context) {
    // Icon scales slightly with reader fontSize for flair at large sizes.
    final iconSize = (fontSize * 0.78).clamp(13.0, 18.0);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.glowOrAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(theme.icon, size: iconSize, color: theme.glowOrAccent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            theme.label,
            style: theme.eyebrowStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (bookId != null)
          _BlockCardFeedbackMenu(
            card: card,
            bookId: bookId!,
            theme: theme,
            colors: colors,
            fontSize: fontSize,
          ),
      ],
    );
  }

  Widget _buildThemed(BlockCardTheme theme, BuildContext context) {
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
        _eyebrowRow(theme, context),
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

  Widget _buildFallback(BlockCardTheme theme, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrowRow(theme, context),
        if (card.title != null && card.title!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(card.title!, style: theme.titleStyle),
        ],
        const SizedBox(height: 8),
        Text(
          card.rawText.trim(),
          style: TextStyle(
            fontSize: (fontSize * 0.72).clamp(11.0, 15.0),
            height: 1.5,
            color: theme.valueColor,
          ),
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
    final barHeight = (fontSize * 0.30).clamp(4.0, 7.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(field.label, style: theme.labelStyle)),
            Text(field.value, style: theme.valueStyle),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: barHeight,
            backgroundColor: colors.text.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _tagRow(BlockCardTheme theme, List<String> tags) {
    final tagFontSize = (fontSize * 0.64).clamp(10.5, 13.0);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.tagBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.glowOrAccent.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: tagFontSize,
                fontWeight: FontWeight.w600,
                color: theme.tagText,
              ),
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

class _BlockCardFeedbackMenu extends ConsumerWidget {
  const _BlockCardFeedbackMenu({
    required this.card,
    required this.bookId,
    required this.theme,
    required this.colors,
    required this.fontSize,
  });

  final BlockCard card;
  final String bookId;
  final BlockCardTheme theme;
  final ReadingColors colors;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 18, color: theme.glowOrAccent),
      padding: EdgeInsets.zero,
      tooltip: 'Card feedback',
      onSelected: (value) async {
        final repo = ref.read(correctionRepositoryProvider);
        switch (value) {
          case 'confirm':
            await repo.saveCorrection(
              BlockCardFeedbackBuilder.confirm(
                bookId: bookId,
                rawText: card.rawText,
              ),
            );
            ref.invalidate(blockCardLocalCorrectionsProvider(bookId));
            AppToast.show(
              'Marked as correct — will stay themed',
              tone: AppToastTone.success,
            );
            break;
          case 'reject':
            await repo.saveCorrection(
              BlockCardFeedbackBuilder.reject(
                bookId: bookId,
                rawText: card.rawText,
              ),
            );
            ref.invalidate(blockCardLocalCorrectionsProvider(bookId));
            AppToast.show(
              'Marked not a card — will show as plain text',
              tone: AppToastTone.read,
            );
            break;
          case 'type':
            final chosen = await showDialog<BlockCardType>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('Correct type'),
                children: [
                  for (final t in BlockCardType.values.where(
                    (e) => e != BlockCardType.custom,
                  ))
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, t),
                      child: _TypeOptionRow(
                        type: t,
                        colors: colors,
                        fontSize: fontSize,
                      ),
                    ),
                ],
              ),
            );
            if (chosen != null) {
              await repo.saveCorrection(
                BlockCardFeedbackBuilder.typeCorrection(
                  bookId: bookId,
                  rawText: card.rawText,
                  correctedType: chosen,
                ),
              );
              ref.invalidate(blockCardLocalCorrectionsProvider(bookId));
              final chosenTheme = resolveBlockCardTheme(
                BlockCard(type: chosen, confidence: 0.9, rawText: ''),
                colors,
                fontSize,
              );
              AppToast.show(
                'Type corrected to ${chosenTheme.label}',
                tone: AppToastTone.read,
              );
            }
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'confirm',
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: theme.glowOrAccent,
              ),
              const SizedBox(width: 8),
              Text('Correct', style: TextStyle(color: theme.glowOrAccent)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reject',
          child: Row(
            children: [
              Icon(Icons.block_rounded, size: 16, color: theme.labelColor),
              const SizedBox(width: 8),
              const Text('Not a card'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'type',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: theme.glowOrAccent),
              const SizedBox(width: 8),
              Text('Change type', style: TextStyle(color: theme.glowOrAccent)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeOptionRow extends StatelessWidget {
  const _TypeOptionRow({
    required this.type,
    required this.colors,
    required this.fontSize,
  });

  final BlockCardType type;
  final ReadingColors colors;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = resolveBlockCardTheme(
      BlockCard(type: type, confidence: 0.9, rawText: ''),
      colors,
      fontSize,
    );
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.glowOrAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(theme.icon, size: 16, color: theme.glowOrAccent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            theme.label,
            style: theme.eyebrowStyle.copyWith(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: theme.glowOrAccent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
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
