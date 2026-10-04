import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/pronunciation_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/views/pronunciation_sheet_view.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Narration settings panel: voice, speed/pitch, sleep timer and profiles.
/// Reads and writes through [narrationSettingsProvider], live-applying to the
/// engine so an active session picks changes up immediately.
class NarrationTab extends ConsumerWidget {
  const NarrationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(narrationSettingsProvider);
    final settings = async.value;
    if (settings == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    void apply(NarrationSettings next) {
      ref.read(narrationSettingsProvider.notifier).apply(next);
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        Text('Narration', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),

        _VoicePicker(
          voices: ref.watch(speechVoicesProvider).valueOrNull ?? const [],
          selectedVoiceId: settings.selectedVoiceId,
          onSelected: (id) => apply(
            settings.copyWith(selectedVoiceId: id, clearActiveProfile: true),
          ),
        ),
        const Divider(height: AppSpacing.lg),

        _profileSection(context, settings, apply),
        const Divider(height: AppSpacing.lg),

        _labeledSlider(
          context,
          'Speech rate',
          settings.speechRate,
          0.4,
          2.0,
          (v) =>
              apply(settings.copyWith(speechRate: v, clearActiveProfile: true)),
        ),
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
        const Divider(height: AppSpacing.lg),

        _sleepTimerSection(context, settings, apply),
        const Divider(height: AppSpacing.lg),

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
          onChanged: (v) => apply(settings.copyWith(announceChapterTitle: v)),
        ),
        SwitchListTile(
          title: const Text('Sync scroll to narration'),
          value: settings.syncScrollToNarration,
          onChanged: (v) => apply(settings.copyWith(syncScrollToNarration: v)),
        ),
        const Divider(height: AppSpacing.lg),
        SwitchListTile(
          title: const Text('Offline TTS cache'),
          subtitle: const Text(
            'Cache synthesis for faster gapless playback (currently-reading only)',
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
        const Divider(height: AppSpacing.lg),
        SwitchListTile(
          title: const Text('Pronunciation'),
          subtitle: const Text('Apply ...  --  """  and custom rules'),
          value: settings.pronunciationEnabled,
          onChanged: (v) => apply(settings.copyWith(pronunciationEnabled: v)),
        ),
        if (settings.pronunciationEnabled) ...[
          const SizedBox(height: AppSpacing.xs),
          const _PronunciationSection(),
        ],
      ],
    );
  }

  Widget _profileSection(
    BuildContext context,
    NarrationSettings settings,
    void Function(NarrationSettings) apply,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profiles', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final profile in NarrationProfile.defaults)
              ChoiceChip(
                label: Text(profile.name),
                selected: settings.activeProfile == profile.name,
                selectedColor: colors.primary.withValues(alpha: 0.15),
                onSelected: (_) => apply(profile.applyTo(settings)),
              ),
          ],
        ),
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

class _VoicePicker extends StatelessWidget {
  const _VoicePicker({
    required this.voices,
    required this.selectedVoiceId,
    required this.onSelected,
  });

  final List<VoiceDescriptor> voices;
  final String? selectedVoiceId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voice', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String?>(
          initialValue: selectedVoiceId != null && _hasVoice(selectedVoiceId!)
              ? selectedVoiceId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Platform default'),
            ),
            ...voices.map(
              (v) => DropdownMenuItem<String?>(
                value: v.id,
                child: Text(
                  '${v.locale} — ${v.id.split('@').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onSelected,
        ),
      ],
    );
  }

  bool _hasVoice(String id) => voices.any((v) => v.id == id);
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
                  Text('Custom rules', style: Theme.of(context).textTheme.bodyMedium),
                  Text('$active active / $count total', style: Theme.of(context).textTheme.bodySmall),
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
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  children: [
                    Text('Pronunciations', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
