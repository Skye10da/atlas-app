import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';

/// Atlas vs. plain EPUB readers vs. closed cloud apps — honest, restrained.
/// Rendered as label-lanes rows so it reflows on narrow viewports without
/// overflow (no `Table`).
class LandingComparison extends StatelessWidget {
  const LandingComparison({super.key});

  static const String _atlasLane = 'Atlas';
  static const String _epubLane = 'EPUB readers';
  static const String _cloudLane = 'Cloud apps';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: GlassCapsule(
            borderRadius: 28,
            blur: 18,
            strong: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'How Atlas compares',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Free & open source (MIT) against the tools you already use.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Header row
                  const Row(
                    children: [
                      Spacer(flex: 5),
                      Expanded(
                        flex: 3,
                        child: _HeaderCell(
                          label: _atlasLane,
                          highlighted: true,
                        ),
                      ),
                      Expanded(flex: 3, child: _HeaderCell(label: _epubLane)),
                      Expanded(flex: 3, child: _HeaderCell(label: _cloudLane)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final row in landingComparison) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            row.capability,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _Cell(value: row.atlas, highlighted: true),
                        ),
                        Expanded(flex: 3, child: _Cell(value: row.epubReaders)),
                        Expanded(flex: 3, child: _Cell(value: row.cloudApps)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: highlighted
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, this.highlighted = false});

  /// true = yes, false = no, null = partial/varies.
  final bool? value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final (icon, color) = switch (value) {
      true => (Icons.check_rounded, accent),
      false => (Icons.remove, theme.colorScheme.onSurfaceVariant),
      null => (Icons.remove, theme.colorScheme.onSurfaceVariant),
    };
    final opacity = value == null ? 0.55 : 1.0;
    return Opacity(
      opacity: opacity,
      child: Icon(icon, size: 20, color: value == true ? accent : color),
    );
  }
}
