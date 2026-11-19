import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/pronunciation_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/views/pronunciation_sheet_view.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/voice_gallery_sheet.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_providers.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';

/// Narration settings panel, revamped around the M5 voice gallery: a voice
/// hero card opening the bottom-sheet gallery, an everyday row (speed pill +
/// sleep timer), and a collapsed "Behavior & storage" group. Reads and
/// writes through [narrationSettingsProvider], live-applying to the engine
/// so an active session picks changes up immediately.
class NarrationTab extends ConsumerWidget {
  const NarrationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(narrationSettingsProvider);
    final settings = async.value;
    if (settings == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final entries = ref.watch(voiceGalleryEntriesProvider);

    void apply(NarrationSettings next) {
      ref.read(narrationSettingsProvider.notifier).apply(next);
    }

    final voiceLabel = resolveVoiceLabel(entries, settings.selectedVoiceId);
    // Pitch is a platform-TTS axis only; VITS packs have no pitch control
    // (NTD §3.3), so the slider hides whenever a neural pack is selected.
    final isPlatformVoice = isPlatformVoiceSelected(
      entries,
      settings.selectedVoiceId,
    );

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        Text('Narration', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),

        _VoiceCard(
          label: voiceLabel,
          selectedVoiceId: settings.selectedVoiceId,
        ),
        const SizedBox(height: AppSpacing.md),

        // Everyday row: speed presets (glass chip-pill) and the sleep timer.
        Row(
          children: [
            Text('Speed', style: theme.textTheme.bodyMedium),
            const Spacer(),
            NarrationSpeedControl(
              accent: theme.colorScheme.primary,
              color: theme.colorScheme.onSurface,
            ),
          ],
        ),
        _sleepTimerSection(context, settings, apply),

        if (isPlatformVoice) ...[
          _labeledSlider(
            context,
            'Pitch',
            settings.speechPitch,
            0.4,
            2.0,
            (v) => apply(
              settings.copyWith(speechPitch: v, clearActiveProfile: true),
            ),
          ),
        ],
        const Divider(height: AppSpacing.lg),

        _behaviorSection(context, settings, apply),
      ],
    );
  }

  Widget _sleepTimerSection(
    BuildContext context,
    NarrationSettings settings,
    void Function(NarrationSettings) apply,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final timer = settings.sleepTimer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('Sleep timer', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('Off'),
              selected: timer == null,
              onSelected: (_) =>
                  apply(settings.copyWith(clearSleepTimer: true)),
            ),
            for (final minutes in const [5, 10, 15, 30, 60])
              ChoiceChip(
                label: Text('$minutes min'),
                selected: timer?.duration.inMinutes == minutes,
                onSelected: (_) => apply(
                  settings.copyWith(
                    sleepTimer: SleepTimerConfig(
                      duration: Duration(minutes: minutes),
                      boundary:
                          timer?.boundary ?? SleepTimerBoundary.endOfChapter,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (timer != null) ...[
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<SleepTimerBoundary>(
            key: const ValueKey('sleep_boundary'),
            initialValue: timer.boundary,
            decoration: const InputDecoration(
              labelText: 'Stop at',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: SleepTimerBoundary.immediate,
                child: Text('Immediately'),
              ),
              DropdownMenuItem(
                value: SleepTimerBoundary.endOfSentence,
                child: Text('End of sentence'),
              ),
              DropdownMenuItem(
                value: SleepTimerBoundary.endOfParagraph,
                child: Text('End of paragraph'),
              ),
              DropdownMenuItem(
                value: SleepTimerBoundary.endOfChapter,
                child: Text('End of chapter'),
              ),
            ],
            onChanged: (b) {
              if (b != null) {
                apply(
                  settings.copyWith(
                    sleepTimer: SleepTimerConfig(
                      duration: timer.duration,
                      boundary: b,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ],
    );
  }

  /// Collapsed secondary group: playback behavior switches, TTS cache and
  /// pronunciation. Hidden behind an expansion tile so the everyday row
  /// stays short.
  Widget _behaviorSection(
    BuildContext context,
    NarrationSettings settings,
    void Function(NarrationSettings) apply,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('behavior_storage'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text('Behavior & storage'),
          initiallyExpanded: false,
          children: [
            SwitchListTile(
              title: const Text('Auto-advance chapters'),
              subtitle: const Text('Continuously play across all chapters'),
              value: settings.autoAdvanceChapter,
              onChanged: (v) => apply(settings.copyWith(autoAdvanceChapter: v)),
            ),
            SwitchListTile(
              title: const Text('Announce chapter title'),
              subtitle: const Text('Speak chapter title before each chapter'),
              value: settings.announceChapterTitle,
              onChanged: (v) =>
                  apply(settings.copyWith(announceChapterTitle: v)),
            ),
            SwitchListTile(
              title: const Text('Sync scroll to narration'),
              value: settings.syncScrollToNarration,
              onChanged: (v) =>
                  apply(settings.copyWith(syncScrollToNarration: v)),
            ),
            SwitchListTile(
              title: const Text('Offline TTS cache'),
              subtitle: const Text(
                'Cache synthesis for faster gapless playback '
                '(currently-reading only)',
              ),
              value: settings.ttsCacheEnabled,
              onChanged: (v) => apply(settings.copyWith(ttsCacheEnabled: v)),
            ),
            if (settings.ttsCacheEnabled) ...[
              const SizedBox(height: AppSpacing.sm),
              _CacheSizePicker(
                value: settings.ttsCacheMaxMb,
                onChanged: (v) => apply(settings.copyWith(ttsCacheMaxMb: v)),
              ),
            ],
            SwitchListTile(
              title: const Text('Pronunciation'),
              subtitle: const Text('Apply ...  --  """  and custom rules'),
              value: settings.pronunciationEnabled,
              onChanged: (v) =>
                  apply(settings.copyWith(pronunciationEnabled: v)),
            ),
            if (settings.pronunciationEnabled) ...[
              const SizedBox(height: AppSpacing.xs),
              const _PronunciationSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labeledSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final divisions = ((max - min) / 0.05).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: textTheme.bodyMedium),
            const Spacer(),
            Text('${value.toStringAsFixed(2)}x', style: textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toStringAsFixed(2)}x',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Hero card for the current voice: label + source tag, tap opens the
/// [VoiceGallerySheet]. Expressive shape: large-radius tonal card with the
/// source icon riding a [GlassLens] droplet, matching the glass pills the
/// rest of the narration UI speaks.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.label, required this.selectedVoiceId});

  final String label;
  final String? selectedVoiceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isNeural = _looksLikePackId(selectedVoiceId);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('voice_card'),
        onTap: () => unawaited(VoiceGallerySheet.show(context)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: GlassLens(
                        accent: colors.primary,
                        isDark: isDark,
                        radius: 13,
                      ),
                    ),
                    Icon(
                      isNeural ? Icons.auto_awesome : Icons.record_voice_over,
                      size: 20,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isNeural
                          ? 'On-device neural · offline'
                          : 'Platform voice · tap to browse',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static bool _looksLikePackId(String? id) =>
      id != null && (id.startsWith('vits-') || id.contains('piper-'));
}

class _CacheSizePicker extends StatelessWidget {
  const _CacheSizePicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cache size', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<int>(
          initialValue: value,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 100, child: Text('100 MB')),
            DropdownMenuItem(value: 250, child: Text('250 MB')),
            DropdownMenuItem(value: 500, child: Text('500 MB')),
            DropdownMenuItem(value: 1000, child: Text('1 GB')),
            DropdownMenuItem(value: 0, child: Text('Unlimited')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _PronunciationSection extends ConsumerWidget {
  const _PronunciationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(pronunciationViewModelProvider);
    final count = vm.rules.length;
    final active = vm.rules.where((r) => r.isEnabled).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final content = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom rules',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '$active active / $count total',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: FilledButton.tonal(
                onPressed: () => _openSheet(context, ref),
                child: const Text('Manage'),
              ),
            ),
          ],
        );
        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    final vm = ref.read(pronunciationViewModelProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Pronunciations',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: PronunciationSheetView(viewModel: vm)),
            ],
          );
        },
      ),
    );
  }
}
