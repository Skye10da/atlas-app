import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Full-screen, glass-styled browser shell backed by [BrowserWebEngine].
///
/// Phase 0: navigation chrome + URL pill over the web view. Later phases grow
/// the tab strip, start page and selection/native integrations.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  /// Optional URL to load on open; otherwise the engine default home applies.
  final String? initialUrl;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  late final BrowserWebEngine _engine;
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _engine = ref.read(browserEngineFactoryProvider)(
      initialUrl: widget.initialUrl,
    );
    _engine.currentUrl.addListener(_syncUrlField);
    _syncUrlField();
  }

  @override
  void dispose() {
    _engine.currentUrl.removeListener(_syncUrlField);
    _urlController.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _syncUrlField() {
    final url = _engine.currentUrl.value;
    if (url == null || url == 'about:blank') return;
    if (_urlController.text == url) return;
    _urlController.text = url;
  }

  Future<void> _submitUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _engine.load(trimmed);
  }

  Future<void> _openExternally() async {
    final url = _engine.currentUrl.value;
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
            _buildChrome(cs),
            _buildProgress(),
            Expanded(child: _engine.buildView()),
          ],
        ),
      ),
    );
  }

  Widget _buildChrome(ColorScheme cs) {
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
            listenable: _engine.canGoBack,
            onPressed: _engine.goBack,
          ),
          _NavIconButton(
            tooltip: 'Forward',
            icon: Icons.arrow_forward_rounded,
            listenable: _engine.canGoForward,
            onPressed: _engine.goForward,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _engine.isLoading,
            builder: (context, loading, _) => _GlassIconButton(
              tooltip: loading ? 'Stop' : 'Reload',
              icon: loading ? Icons.close_rounded : Icons.refresh_rounded,
              onPressed: loading ? _engine.stop : _engine.reload,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _urlPill(cs)),
          const SizedBox(width: AppSpacing.sm),
          _GlassIconButton(
            tooltip: 'Open externally',
            icon: Icons.open_in_new_rounded,
            onPressed: _openExternally,
          ),
        ],
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
    return ListenableBuilder(
      listenable: Listenable.merge([_engine.progress, _engine.isLoading]),
      builder: (context, _) {
        final progress = _engine.progress.value;
        if (!_engine.isLoading.value || progress >= 1) {
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