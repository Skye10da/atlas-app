import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/dock_prefs_provider.dart';

/// "Customize reader dock": reorder/trim the capsule row, toggle what the
/// chapter strip shows, and set the auto-scroll start speed. Opens from the
/// dock's More menu or a long-press on the chapter strip. Writes through
/// [readerDockPrefsProvider] (persisted globally).
class ReaderDockCustomizeSheet extends ConsumerWidget {
  const ReaderDockCustomizeSheet({super.key, required this.availablePromotable});

  /// Actions the consuming layout actually supports (non-null callbacks).
  /// Everything the user enables but isn't here is silently skipped at render
  /// time by the dock itself; the sheet only needs it to avoid showing
  /// chips that could never render.
  final List<ReaderDockAction> availablePromotable;

  static Future<void> show(
    BuildContext context, {
    required List<ReaderDockAction> availablePromotable,
  }) {
    return AppSheet.show<void>(
      context: context,
      id: 'reader_dock_customize',
      title: 'Customize dock',
      fitToContent: true,
      maxWidth: 520,
      child: ReaderDockCustomizeSheet(availablePromotable: availablePromotable),
    );
  }

  static const _presets = <(String, double)>[
    ('20', 1.0),
    ('30', 1.5),
    ('45', 2.25),
    ('70', 3.5),
    ('100', 5.0),
  ];

  static const _actionLabels = <ReaderDockAction, String>{
    ReaderDockAction.contents: 'Contents',
    ReaderDockAction.annotations: 'Notes',
    ReaderDockAction.listen: 'Listen',
    ReaderDockAction.aa: 'Text & theme',
    ReaderDockAction.flow: 'Auto-scroll',
    ReaderDockAction.search: 'Search',
    ReaderDockAction.atlas: 'Atlas',
    ReaderDockAction.redownload: 'Redownload',
  };

  static const _actionIcons = <ReaderDockAction, IconData>{
    ReaderDockAction.contents: Icons.format_list_numbered_rounded,
    ReaderDockAction.annotations: Icons.sticky_note_2_outlined,
    ReaderDockAction.listen: Icons.headphones_rounded,
    ReaderDockAction.aa: Icons.text_fields_rounded,
    ReaderDockAction.flow: Icons.bolt_outlined,
    ReaderDockAction.search: Icons.search_rounded,
    ReaderDockAction.atlas: Icons.psychology_outlined,
    ReaderDockAction.redownload: Icons.refresh_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final prefs = ref.watch(readerDockPrefsProvider);
    final notifier = ref.read(readerDockPrefsProvider.notifier);

    Widget labelOf(String text, String? sub) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    Widget chip(
      String text, {
      required bool active,
      required VoidCallback onTap,
      IconData? icon,
      String? tooltip,
    }) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.xs),
      child: FilterChip(
        selected: active,
        label: Text(text),
        tooltip: tooltip,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
    );

    Widget spineChip(String text, bool active, VoidCallback onTap) =>
      chip(text, active: active, onTap: onTap);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelOf(
              'Capsule actions',
              'More stays last; prev / next chapter stay at the ends.',
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              children: [
                for (final action in availablePromotable)
                  if (action != ReaderDockAction.more)
                    chip(
                      _actionLabels[action] ?? action.name,
                      icon: _actionIcons[action],
                      tooltip: prefs.actions.contains(action)
                          ? 'Remove from the dock'
                          : 'Add to the dock',
                      active: prefs.actions.contains(action),
                      onTap: () => notifier.spliceAction(
                        action,
                        include: !prefs.actions.contains(action),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            labelOf(
              'Spine shows',
              'The slim strip when the dock is tucked away.',
            ),
            Wrap(
              children: [
                spineChip(
                  'Chapter · %',
                  prefs.spine.chapterProgress,
                  () => notifier.setSpine(
                    prefs.spine.copyWith(
                      chapterProgress: !prefs.spine.chapterProgress,
                    ),
                  ),
                ),
                spineChip(
                  'Clock',
                  prefs.spine.clock,
                  () => notifier.setSpine(
                    prefs.spine.copyWith(clock: !prefs.spine.clock),
                  ),
                ),
                spineChip(
                  'Battery',
                  prefs.spine.battery,
                  () => notifier.setSpine(
                    prefs.spine.copyWith(battery: !prefs.spine.battery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            labelOf('Auto-scroll speed', 'Where auto-scroll starts. Change it any time on the strip.'),
            Wrap(
              children: [
                for (final (label, speed) in _presets)
                  chip(
                    '$label px/s',
                    active: (prefs.autoScrollSpeed - speed).abs() < 0.26,
                    onTap: () => notifier.setAutoScrollSpeed(speed),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: notifier.reset,
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
