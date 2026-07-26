import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class AppErrorState extends StatefulWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.technicalDetails,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? technicalDetails;

  @override
  State<AppErrorState> createState() => _AppErrorStateState();
}

class _AppErrorStateState extends State<AppErrorState> {
  var _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.message,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (widget.technicalDetails != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(_showDetails ? 'Hide details' : 'Show details'),
              ),
              if (_showDetails)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                  ),
                  child: SelectableText(
                    widget.technicalDetails!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
            if (widget.onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
