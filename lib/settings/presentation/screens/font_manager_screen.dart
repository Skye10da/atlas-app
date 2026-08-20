import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/settings/infrastructure/repositories/font_download_repository.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

/// Weights that the reader font picker exposes — download all of them so the
/// font renders correctly for any weight the user might select.
const _weightsToFetch = <FontWeight>[
  FontWeight.w300,
  FontWeight.w400,
  FontWeight.w500,
  FontWeight.w600,
  FontWeight.w700,
  FontWeight.w800,
];

class FontManagerScreen extends ConsumerStatefulWidget {
  const FontManagerScreen({super.key});

  @override
  ConsumerState<FontManagerScreen> createState() => _FontManagerScreenState();
}

class _FontManagerScreenState extends ConsumerState<FontManagerScreen> {
  /// Families currently being fetched — used to render hidden Text widgets
  /// that trigger Google Fonts runtime caching.
  final Set<String> _fetching = {};

  @override
  Widget build(BuildContext context) {
    final fontState = ref.watch(fontDownloadProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Download Fonts')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'Bundled fonts are always available offline. '
              'Other fonts are downloaded from Google Fonts and cached '
              'for offline use.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SectionHeader(title: 'Bundled'),
          ...FontDownloadRepository.bundledFamilies.map(
            (family) => ListTile(
              title: Text(family),
              subtitle: Text(
                'Bundled with app',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.check_circle_outline,
                color: colors.primary,
                size: 20,
              ),
            ),
          ),
          const SectionHeader(title: 'Downloadable'),
          ...FontDownloadRepository.downloadableFamilies.map(
            (family) => _FontTile(
              family: family,
              isDownloaded: fontState.downloaded.contains(family),
              isDownloading: fontState.downloading.contains(family),
              hasError: fontState.errors.contains(family),
              onDownload: () => _downloadFamily(family),
              onRemove: () =>
                  ref.read(fontDownloadProvider.notifier).remove(family),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Hidden text widgets that trigger Google Fonts caching.
          ..._fetching.map(
            (family) => Offstage(
              child: Column(
                children: _weightsToFetch
                    .map(
                      (w) => Text(
                        '',
                        style: GoogleFonts.getFont(
                          family,
                          textStyle: TextStyle(
                            fontWeight: w,
                            fontSize: 1,
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFamily(String family) async {
    final notifier = ref.read(fontDownloadProvider.notifier);
    notifier.markDownloading(family);

    setState(() => _fetching.add(family));

    // Give the engine a frame to render the hidden Text widgets and
    // trigger Google Fonts runtime fetching + disk caching.
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _fetching.remove(family));

    // Mark as downloaded — the fonts are now in the app-support dir.
    await ref.read(fontDownloadRepositoryProvider).markDownloaded(family);
    notifier.markDownloaded(family);
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({
    required this.family,
    required this.isDownloaded,
    required this.isDownloading,
    required this.hasError,
    required this.onDownload,
    required this.onRemove,
  });

  final String family;
  final bool isDownloaded;
  final bool isDownloading;
  final bool hasError;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final previewStyle = GoogleFonts.getFont(
      family,
      textStyle: textTheme.bodyLarge,
    );

    return ListTile(
      title: Text(family, style: previewStyle),
      subtitle: Text(
        hasError
            ? 'Download failed — tap to retry'
            : isDownloaded
            ? 'Downloaded'
            : 'Not downloaded',
        style: textTheme.bodySmall?.copyWith(
          color: hasError
              ? colors.error
              : isDownloaded
              ? colors.primary
              : colors.onSurfaceVariant,
        ),
      ),
      trailing: isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isDownloaded
          ? IconButton(
              icon: Icon(Icons.cloud_done, color: colors.primary),
              onPressed: onRemove,
              tooltip: 'Remove download',
            )
          : IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: onDownload,
              tooltip: 'Download font',
            ),
    );
  }
}
