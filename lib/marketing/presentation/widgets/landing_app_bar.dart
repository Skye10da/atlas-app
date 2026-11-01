import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';

/// Floating glass pill navigation for the public Atlas landing page.
///
/// Desktop/tablet renders the inline links; underneath 720px the links fold
/// into a hamburger sheet (glass, same anchors) so the pill stays slim.
class LandingAppBar extends StatelessWidget {
  const LandingAppBar({
    super.key,
    required this.onNavigate,
    required this.onDownload,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback onDownload;

  static const List<({String label, String anchor})> _links = [
    (label: 'Features', anchor: '#features'),
    (label: 'Stories', anchor: '#stories'),
    (label: "What's new", anchor: '#release'),
    (label: 'FAQ', anchor: '#faq'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final compact = MediaQuery.sizeOf(context).width < 880;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: GlassCapsule(
        borderRadius: AppSpacing.borderRadiusFull,
        blur: 28,
        strong: true,
        skipDropShadow: true,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _BrandMark(accent: accent),
              if (!compact)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final link in _links)
                        TextButton(
                          onPressed: () => onNavigate(link.anchor),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                          child: Text(
                            link.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                const Spacer(),
              if (compact)
                IconButton(
                  tooltip: 'Sections',
                  icon: const Icon(Icons.menu),
                  color: theme.colorScheme.onSurface,
                  onPressed: () => _openMenu(context),
                ),
              if (!compact)
                _NavCta(accent: accent, onPressed: onDownload)
              else
                Padding(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.insetSm,
                    left: AppSpacing.xs,
                  ),
                  child: _NavCta(accent: accent, onPressed: onDownload),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMenu(BuildContext context) {
    final theme = Theme.of(context);
    final sheetNavigator = Navigator.of(context);
    AppSheet.show<void>(
      context: context,
      id: 'landing_sections_menu',
      title: 'Sections',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final link in _links)
            ListTile(
              title: Text(
                link.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                sheetNavigator.pop();
                onNavigate(link.anchor);
              },
            ),
          ListTile(
            title: Text(
              'Download',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            subtitle: Text(
              'Auto-detected build for your device',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.download),
            onTap: () {
              sheetNavigator.pop();
              onNavigate('#download');
            },
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.55)],
            ),
          ),
          child: Icon(
            Icons.book_rounded,
            size: 18,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Atlas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _NavCta extends StatelessWidget {
  const _NavCta({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      child: GlassCapsule(
        borderRadius: AppSpacing.borderRadiusFull,
        blur: 16,
        strong: true,
        fill: accent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download,
                size: 16,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Download',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
