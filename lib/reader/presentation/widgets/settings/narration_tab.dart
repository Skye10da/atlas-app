import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Narration settings panel: voice, speed/pitch, sleep timer and profiles.
/// Reads and writes through [narrationSettingsProvider], live-applying to the
/// engine so an active session picks changes up immediately.
class NarrationTab extends ConsumerStatefulWidget {
  const NarrationTab({super.key});

  @override
  ConsumerState<NarrationTab> createState() => _NarrationTabState();
}

class _NarrationTabState extends ConsumerState<NarrationTab> {
  NarrationSettings? _settings;

  void _apply(NarrationSettings next) {
    setState(() => _settings = next);
    ref.read(narrationSettingsProvider.notifier).apply(next);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(narrationSettingsProvider);
    _settings ??= async.value;
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

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
          onSelected: (id) => _apply(
            settings.copyWith(selectedVoiceId: id, clearActiveProfile: true),
          ),
        ),
        const Divider(height: AppSpacing.lg),

        _profileSection(settings),
        const Divider(height: AppSpacing.lg),

        _labeledSlider(
          'Speech rate',
          settings.speechRate,
          0.4,
          2.0,
          (v) => _apply(
            settings.copyWith(speechRate: v, clearActiveProfile: true),
          ),
        ),
        _labeledSlider(
          'Pitch',
          settings.speechPitch,
          0.4,
          2.0,
          (v) => _apply(
            settings.copyWith(speechPitch: v, clearActiveProfile: true),
          ),
        ),
        const Divider(height: AppSpacing.lg),

        _sleepTimerSection(settings),
        const Divider(height: AppSpacing.lg),

        SwitchListTile(
          title: const Text('Auto-advance chapters'),
          value: settings.autoAdvanceChapter,
          onChanged: (v) => _apply(settings.copyWith(autoAdvanceChapter: v)),
        ),
        SwitchListTile(
          title: const Text('Sync scroll to narration'),
          value: settings.syncScrollToNarration,
          onChanged: (v) => _apply(settings.copyWith(syncScrollToNarration: v)),
        ),
      ],
    );
  }

  Widget _profileSection(NarrationSettings settings) {
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
                onSelected: (_) => _apply(profile.applyTo(settings)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sleepTimerSection(NarrationSettings settings) {
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
                  _apply(settings.copyWith(clearSleepTimer: true)),
            ),
            for (final minutes in const [5, 10, 15, 30, 60])
              ChoiceChip(
                label: Text('$minutes min'),
                selected: timer?.duration.inMinutes == minutes,
                onSelected: (_) => _apply(
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
                _apply(
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
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final textTheme = Theme.of(context).textTheme;
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
        Slider(value: value, min: min, max: max, onChanged: onChanged),
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
