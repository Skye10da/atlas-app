import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/browser/domain/controllers/browser_tabs_controller.dart';
import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/widgets/browser_library_sheets.dart';
import 'package:atlas_app/browser/presentation/widgets/browser_start_page.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Full-screen, glass-styled browser shell backed by [BrowserWebEngine].
///
/// Phase 1: multi-tab strip over an [IndexedStack] of live engines, native
/// start page, one-tap home reset and history recording on navigation.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  /// Optional URL to load on open. When null the persisted tab strip is
  /// restored (or a fresh tab lands on the start page).
  final String? initialUrl;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  late final BrowserTabsController _tabs;
  final _urlController = TextEditingController();

  BrowserWebEngine? _boundEngine;
  String? _lastRecordedUrl;

  @override
  void initState() {
    super.initState();
    _tabs = BrowserTabsController(
      repository: ref.read(browserRepositoryProvider),
      engineFactory: ref.read(browserEngineFactoryProvider),
    );
    if (widget.initialUrl != null) {
      _tabs.addTab(url: widget.initialUrl);
    } else {
      _tabs.restore();
    }
    _tabs.addListener(_onTabsChanged);
    _onTabsChanged();
  }

  @override
  void dispose() {
    _bindUrlListener(null);
    _tabs.removeListener(_onTabsChanged);
    _tabs.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onTabsChanged() {
    _bindUrlListener(_tabs.activeTab?.engine);
    _syncUrlField();
  }

  void _bindUrlListener(BrowserWebEngine? engine) {
    if (_boundEngine == engine) return;
    _boundEngine?.currentUrl.removeListener(_recordNavigation);
    _boundEngine = engine;
    _boundEngine?.currentUrl.addListener(_recordNavigation);
  }

  Future<void> _recordNavigation() async {
    final url = _boundEngine?.currentUrl.value;
    if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;
    if (url == _lastRecordedUrl) return;
    _lastRecordedUrl = url;
    await ref.read(browserRepositoryProvider).recordVisit(
          url: url,
          title: _boundEngine?.currentTitle.value,
        );
  }

  void _syncUrlField() {
    final url = _tabs.activeTab?.url;
    final text = url;
    if (text == null || text == kBrowserStartPageUrl) return;
    if (_urlController.text == text) return;
    _urlController.text = text;
  }

  Future<void> _submitUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _tabs.activeTab?.engine.load(trimmed);
  }

  Future<void> _openExternally() async {
    final url = _tabs.activeTab?.url;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !uri.hasScheme) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open in system browser?'),
        content: Text('$url\n\nThis leaves the Atlas reader view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTabStrip(cs),
            _buildChrome(cs),
            _buildProgress(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabStrip(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: ListenableBuilder(
        listenable: _tabs,
        builder: (context, _) {
          return SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.tabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final tab = _tabs.tabs[index];
                      return _TabChip(
                        tab: tab,
                        selected: index == _tabs.activeIndex,
                        onTap: () => _tabs.activate(index),
                        onClose: () => _tabs.close(index),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'New tab',
                  icon: const Icon(Icons.add_rounded, size: 20),
                  onPressed:
                      _tabs.canAddTab ? () => _tabs.addTab() : null,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChrome(ColorScheme cs) {
    final engine = _tabs.activeTab?.engine;
    final currentUrl = _tabs.activeTab?.url;
    final isBookmarked = ref
            .watch(webBookmarksProvider)
            .value
            ?.any((b) => b.url == currentUrl) ??
        false;
    final canBookmark = currentUrl != null && currentUrl != kBrowserStartPageUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          _NavIconButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_rounded,
            listenable: engine?.canGoBack ?? _constFalse,
            onPressed: () => engine?.goBack(),
          ),
          _NavIconButton(
            tooltip: 'Forward',
            icon: Icons.arrow_forward_rounded,
            listenable: engine?.canGoForward ?? _constFalse,
            onPressed: () => engine?.goForward(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: engine?.isLoading ?? _constFalse,
            builder: (context, loading, _) => _GlassIconButton(
              tooltip: loading ? 'Stop' : 'Reload',
              icon: loading ? Icons.close_rounded : Icons.refresh_rounded,
              onPressed: () => loading ? engine?.stop() : engine?.reload(),
            ),
          ),
          _GlassIconButton(
            tooltip: 'Home',
            icon: Icons.home_rounded,
            onPressed: () => engine?.load(kBrowserStartPageUrl),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _urlPill(cs)),
          const SizedBox(width: AppSpacing.sm),
          _GlassIconButton(
            tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark this page',
            icon: isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            enabled: canBookmark,
            onPressed: () => _toggleBookmark(),
          ),
          _GlassIconButton(
            tooltip: 'History & bookmarks',
            icon: Icons.history_rounded,
            onPressed: _openLibrarySheets,
          ),
          _GlassIconButton(
            tooltip: 'Open externally',
            icon: Icons.open_in_new_rounded,
            onPressed: _openExternally,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final url = _tabs.activeTab?.url;
    final title = _tabs.activeTab?.title;
    if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;

    final repo = ref.read(browserRepositoryProvider);
    final alreadyBookmarked = (ref.read(webBookmarksProvider).value ?? const [])
        .any((b) => b.url == url);
    if (alreadyBookmarked) {
      await repo.removeBookmark(url);
      return;
    }
    final now = DateTime.now();
    await repo.addBookmark(BrowserBookmark(
      id: url,
      url: url,
      title: title == 'New tab' ? null : title,
      createdAt: now,
      updatedAt: now,
    ));
  }

  void _openLibrarySheets() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(ctx);
                showBrowserHistorySheet(context, onOpenUrl: (url) {
                  _tabs.activeTab?.engine.load(url);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: const Text('Bookmarks'),
              onTap: () {
                Navigator.pop(ctx);
                showBrowserBookmarksSheet(context, onOpenUrl: (url) {
                  _tabs.activeTab?.engine.load(url);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _urlPill(ColorScheme cs) {
    return TextField(
      controller: _urlController,
      textInputAction: TextInputAction.go,
      onSubmitted: (value) => _submitUrl(value),
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search or enter address',
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final engine = _tabs.activeTab?.engine;
    if (engine == null) return const SizedBox(height: 0);
    return ListenableBuilder(
      listenable: Listenable.merge([engine.progress, engine.isLoading]),
      builder: (context, _) {
        final progress = engine.progress.value;
        if (!engine.isLoading.value || progress >= 1) {
          return const SizedBox(height: 0);
        }
        return LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.transparent,
        );
      },
    );
  }

  Widget _buildContent() {
    final active = _tabs.activeTab;
    if (active == null) return const SizedBox.shrink();
    if (active.isOnStartPage) {
      return BrowserStartPage(
        onOpenSite: (url) => active.engine.load(url),
      );
    }
    return IndexedStack(
      index: _tabs.activeIndex,
      children: [for (final tab in _tabs.tabs) tab.engine.buildView()],
    );
  }

  static final ValueNotifier<bool> _constFalse = ValueNotifier<bool>(false);
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: tab.engine.currentTitle,
      builder: (context, _, _) {
        return Material(
          color: selected
              ? cs.primaryContainer
              : cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: selected
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.tooltip,
    required this.icon,
    required this.listenable,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final ValueListenable<bool> listenable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, enabled, _) => _GlassIconButton(
        tooltip: tooltip,
        icon: icon,
        enabled: enabled,
        onPressed: onPressed,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: cs.onSurface,
          onPressed: enabled ? onPressed : null,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}