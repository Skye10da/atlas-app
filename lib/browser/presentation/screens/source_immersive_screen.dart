import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

/// Full-screen immersive webview for a single source.
/// Replaces the multi-tab browser with a clean, focused browsing experience
/// featuring a floating glass top bar with Back and Close (×) buttons and
/// a slide-up novel detection pill.
class SourceImmersiveScreen extends ConsumerStatefulWidget {
  const SourceImmersiveScreen({
    super.key,
    required this.initialUrl,
    this.sourceTitle,
  });

  final String initialUrl;
  final String? sourceTitle;

  @override
  ConsumerState<SourceImmersiveScreen> createState() =>
      _SourceImmersiveScreenState();
}

class _SourceImmersiveScreenState extends ConsumerState<SourceImmersiveScreen> {
  late final BrowserWebEngine _engine;
  String? _novelUrl;
  String? _currentDisplayUrl;

  @override
  void initState() {
    super.initState();
    _engine = InappWebviewEngine(initialUrl: widget.initialUrl);
    _currentDisplayUrl = widget.initialUrl;
    _engine.currentUrl.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    final url = _engine.currentUrl.value;
    if (url != null && url.isNotEmpty && mounted) {
      setState(() {
        _currentDisplayUrl = url;
      });
      _checkForNovel(url);
    }
  }

  void _checkForNovel(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) setState(() => _novelUrl = null);
      return;
    }
    final adapter = ref.read(sourceRegistryProvider).resolve(uri);
    final isNovel =
        adapter != null && adapter.contentCategory == ContentCategory.novel;
    if (mounted) setState(() => _novelUrl = isNovel ? url : null);
  }

  @override
  void dispose() {
    _engine.currentUrl.removeListener(_onUrlChanged);
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final host = _currentDisplayUrl != null
        ? Uri.tryParse(_currentDisplayUrl!)?.host ?? _currentDisplayUrl!
        : (widget.sourceTitle ?? 'Source');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Main Webview Column
            Column(
              children: [
                // Clean Glass Top Navigation Bar
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer.withValues(alpha: 0.95),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back in webview
                      ValueListenableBuilder<bool>(
                        valueListenable: _engine.canGoBack,
                        builder: (context, canBack, _) {
                          return IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                            ),
                            onPressed: canBack ? () => _engine.goBack() : null,
                            tooltip: 'Go back',
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // Host / Title
                      Expanded(
                        child: Text(
                          host,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // Close button (×)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close source',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Web Page Progress Indicator
                ValueListenableBuilder<double>(
                  valueListenable: _engine.progress,
                  builder: (context, p, _) {
                    if (p <= 0.0 || p >= 1.0) return const SizedBox.shrink();
                    return LinearProgressIndicator(
                      value: p,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      color: colorScheme.primary,
                    );
                  },
                ),

                // Web Platform View
                Expanded(child: _engine.buildView()),
              ],
            ),

            // Novel Detection Bottom Action Pill
            if (_novelUrl != null)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.lg,
                child: Material(
                  elevation: 6,
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusLg,
                    ),
                    onTap: () {
                      final url = _novelUrl;
                      if (url != null) {
                        showImportUrlSheet(context, initialUrl: url);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.smMd,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Novel detected on this page',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  'Tap to import into library',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              final url = _novelUrl;
                              if (url != null) {
                                showImportUrlSheet(context, initialUrl: url);
                              }
                            },
                            child: const Text('Import'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

