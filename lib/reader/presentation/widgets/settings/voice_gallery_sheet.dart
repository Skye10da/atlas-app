import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_downloader.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

/// Bottom-sheet voice gallery (M5 UI revamp): downloadable neural voice
/// families first — each with an explicit Compact/Standard/Best quality
/// choice, a CDN preview clip, and live download progress — then platform
/// voices. Picking a row writes `selectedVoiceId`; for packs that is the
/// installed flavor's pack id, which NeuralTtsDriver resolves lazily at
/// speak time (no driver rebuild needed).
class VoiceGallerySheet extends HookConsumerWidget {
  const VoiceGallerySheet({super.key, this.scrollController});

  /// From [DraggableScrollableSheet]: must drive the list so dragging the
  /// content also drags the sheet.
  final ScrollController? scrollController;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
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
                  Text('Voices', style: Theme.of(ctx).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: VoiceGallerySheet(
                key: const ValueKey('voice_gallery'),
                scrollController: scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(voicePackCatalogProvider);
    final statesAsync = ref.watch(voicePackStatesProvider);
    final voicesAsync = ref.watch(speechVoicesProvider);
    final settings = ref.watch(narrationSettingsProvider).valueOrNull;
    final entries = buildVoiceGallery(
      catalog: catalogAsync.valueOrNull,
      records: statesAsync.valueOrNull ?? const [],
      platformVoices: voicesAsync.valueOrNull ?? const [],
    );

    void select(String voiceId) {
      final current = ref.read(narrationSettingsProvider).valueOrNull;
      if (current == null) return;
      unawaited(
        ref
            .read(narrationSettingsProvider.notifier)
            .apply(
              current.copyWith(
                selectedVoiceId: voiceId,
                clearActiveProfile: true,
              ),
            ),
      );
    }

    final packEntries = entries.whereType<PackVoiceEntry>().toList();
    final platformEntries = entries.whereType<PlatformVoiceEntry>().toList();
    final hasPacks = catalogAsync.hasValue && packEntries.isNotEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (!catalogAsync.hasValue)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasPacks && platformEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'No voices available',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The voice catalog could not be loaded. Check your '
                  'connection and try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(voicePackCatalogProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else ...[
          if (hasPacks) ...[
            _sectionLabel(
              context,
              'On-device neural',
              'Download once, then works offline',
            ),
            for (final entry in packEntries)
              _PackRow(
                entry: entry,
                selectedVoiceId: settings?.selectedVoiceId,
                onSelect: select,
              ),
          ],
          if (platformEntries.isNotEmpty) ...[
            _sectionLabel(context, 'Platform voices', null),
            for (final entry in platformEntries)
              _PlatformRow(
                voice: entry.voice,
                selected: settings?.selectedVoiceId == entry.voice.id,
                onSelect: () => select(entry.voice.id),
              ),
          ],
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String title, String? hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (hint != null)
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One neural family: preview, quality chips (the explicit per-voice
/// download choice), and state (installed / downloading % / retry).
class _PackRow extends HookConsumerWidget {
  const _PackRow({
    required this.entry,
    required this.selectedVoiceId,
    required this.onSelect,
  });

  final PackVoiceEntry entry;
  final String? selectedVoiceId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final flavors = entry.family.flavors;
    final active = entry.activeRecord;
    final progress = ref.watch(voicePackProgressProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PreviewButton(family: entry.family),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.family.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _subtitle,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (active != null) ...[
                  Text(
                    _progressLabel(active, progress),
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    key: ValueKey('cancel_${entry.family.id}'),
                    onPressed: () => ref
                        .read(voicePackControllerProvider)
                        .cancel(active.packId),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final flavor in flavors)
                  _QualityChip(
                    entry: entry,
                    flavor: flavor,
                    selected:
                        entry.readyRecord(flavor.quality)?.packId ==
                        selectedVoiceId,
                    progress: active != null && active.packId == flavor.packId
                        ? progress?.fraction ??
                              (active.totalBytes > 0
                                  ? (active.bytes / active.totalBytes).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : null)
                        : null,
                    busy: active != null && active.packId == flavor.packId,
                    onChosen: () => unawaited(_choose(ref, flavor)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final family = entry.family;
    final locale = family.locale.isNotEmpty ? family.locale : family.language;
    final gender = family.gender;
    return [
      if (locale.isNotEmpty) locale,
      if (gender != null && gender.isNotEmpty) gender,
      'on-device',
    ].join(' · ');
  }

  String _progressLabel(VoicePackRecord active, VoicePackProgress? progress) {
    final frac = progress?.packId == active.packId ? progress?.fraction : null;
    final value =
        frac ??
        (active.totalBytes > 0
            ? (active.bytes / active.totalBytes).clamp(0.0, 1.0)
            : null);
    return value == null ? 'Downloading…' : '${(value * 100).round()}%';
  }

  /// Chip tap: select when installed, cancel when this flavor's download is
  /// running, otherwise download then auto-select.
  Future<void> _choose(WidgetRef ref, VoicePackFlavor flavor) async {
    final controller = ref.read(voicePackControllerProvider);
    final ready = entry.readyRecord(flavor.quality);
    if (ready != null) {
      onSelect(ready.packId);
      return;
    }
    final active = entry.activeRecord;
    if (active != null && active.packId == flavor.packId) {
      controller.cancel(active.packId);
      return;
    }
    // The captured [entry] goes stale while downloading (records rebuild
    // reactively now), so auto-select on the returned result, not a
    // re-read of the stale entry.
    final result = await controller.downloadFamily(
      entry.family.id,
      quality: flavor.quality,
    );
    if (result == VoicePackDownloadResult.ready) {
      onSelect(flavor.packId);
    }
  }
}

/// The ▶ preview affordance: streams the family's ~100 KB CDN sample clip.
/// The player lives (and dies) with the row.
class _PreviewButton extends HookConsumerWidget {
  const _PreviewButton({required this.family});

  final VoicePackFamily family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerHolder = useState<ja.AudioPlayer?>(null);
    final playing = useState(false);
    final player = playerHolder.value;
    final url = family.previewUrl;

    useEffect(() {
      if (player == null) return null;
      final sub = player.playerStateStream.listen((s) {
        playing.value = s.playing;
        if (s.processingState == ja.ProcessingState.completed) {
          unawaited(player.stop());
          unawaited(player.seek(Duration.zero));
        }
      });
      return sub.cancel;
    }, [player]);
    useEffect(() {
      return () {
        unawaited(playerHolder.value?.dispose());
        playerHolder.value = null;
      };
    });

    final enabled = url != null && url.isNotEmpty;
    return IconButton(
      key: ValueKey('preview_${family.id}'),
      tooltip: enabled ? 'Preview' : 'No preview',
      onPressed: enabled
          ? () async {
              var p = playerHolder.value;
              if (p == null) {
                p = ja.AudioPlayer();
                playerHolder.value = p;
              }
              if (playing.value) {
                await p.stop();
                return;
              }
              try {
                await p.setUrl(url);
                await p.play();
              } catch (_) {}
            }
          : null,
      icon: Icon(
        playing.value ? Icons.stop_circle_outlined : Icons.play_circle_outline,
      ),
    );
  }
}

/// Compact / Standard / Best — the explicit per-voice quality choice.
class _QualityChip extends StatelessWidget {
  const _QualityChip({
    required this.entry,
    required this.flavor,
    required this.selected,
    required this.busy,
    required this.progress,
    required this.onChosen,
  });

  final PackVoiceEntry entry;
  final VoicePackFlavor flavor;
  final bool selected;
  final bool busy;
  final double? progress;
  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final installed = entry.readyRecord(flavor.quality) != null;

    final label = '${flavor.quality.label} · ${flavor.sizeLabel}';
    final Widget child;
    if (busy) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, value: progress),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            progress == null
                ? flavor.quality.label
                : '${flavor.quality.label} · ${(progress! * 100).round()}%',
            style: theme.textTheme.labelSmall,
          ),
        ],
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (installed)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(
                selected ? Icons.check_circle : Icons.check,
                size: 14,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      );
    }

    return ChoiceChip(
      key: ValueKey('quality_${flavor.packId}'),
      label: child,
      selected: selected,
      visualDensity: VisualDensity.compact,
      selectedColor: colors.primary.withValues(alpha: 0.18),
      showCheckmark: false,
      onSelected: busy ? null : (_) => onChosen(),
    );
  }
}

/// Compact current-voice pill for the Now Playing transport row: shows the
/// active voice's name, opens the gallery on tap. Mirrors
/// [NarrationSpeedControl]'s glass pill styling.
class VoicePill extends HookConsumerWidget {
  const VoicePill({super.key, required this.accent, required this.color});

  final Color accent;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(narrationSettingsProvider).valueOrNull;
    final label = resolveVoiceLabel(
      ref.watch(voiceGalleryEntriesProvider),
      settings?.selectedVoiceId,
    );

    return Tooltip(
      message: 'Narration voice',
      child: GlassCapsule(
        pill: true,
        blur: 18,
        strong: false,
        skipDropShadow: true,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: InkWell(
            key: const ValueKey('voice_pill'),
            borderRadius: BorderRadius.circular(13),
            onTap: () => unawaited(VoiceGallerySheet.show(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.record_voice_over, size: 14, color: accent),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({
    required this.voice,
    required this.selected,
    required this.onSelect,
  });

  final VoiceDescriptor voice;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('platform_${voice.id}'),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        voice.id.split('@').first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          voice.locale,
          if (voice.gender != null && voice.gender!.isNotEmpty) voice.gender!,
          if (voice.quality != null && voice.quality!.isNotEmpty)
            voice.quality!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onSelect,
    );
  }
}
