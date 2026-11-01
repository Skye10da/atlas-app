import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/design_system/atoms/source_visuals.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

/// A single, concrete import target: one book on one supported site.
class ImportCandidate {
  const ImportCandidate({
    required this.siteName,
    required this.url,
    this.coverUrl,
    this.description,
  });

  final String siteName;
  final String url;
  final String? coverUrl;
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ImportCandidate && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Entry point for every "Add to Library" action on the Find new hub.
///
/// Decision flow:
/// * 0 candidates → friendly snack bar (nothing to import);
/// * 1 candidate → straight into the standard import sheet, no extra step;
/// * N candidates → the same novel was found on several supported sites:
///   a chooser sheet lists them as site options and the picked one is
///   handed to the standard import pipeline.
///
/// Import results navigate to the imported book, mirroring
/// [SourceSearchScreen]'s flow (the import sheet's done stage returns the
/// [ImportOutcome]).
Future<ImportOutcome?> showImportConfirmSheet(
  BuildContext context, {
  required List<ImportCandidate> candidates,
  required String title,
  String? author,

  /// URL of the pre-selected best-guess source (chosen by site health
  /// and response speed). Its tile gets a "Recommended" badge so the user
  /// can confirm in one tap; `null` marks nothing.
  String? recommendedUrl,
  Future<ImportOutcome?> Function(
    BuildContext context,
    ImportCandidate candidate,
  )?
  onSelected,
}) {
  // Collapse identical URLs (the same page reached via two offers).
  final unique = <ImportCandidate>[];
  for (final candidate in candidates) {
    if (candidate.url.isEmpty) continue;
    final match = unique.any((c) => c.url == candidate.url);
    if (!match) unique.add(candidate);
  }

  if (unique.isEmpty) {
    AppToast.showError('No supported site found for "$title".');
    return Future.value();
  }

  if (unique.length == 1) {
    return _importCandidate(context, unique.single, onSelected);
  }

  return showModalBottomSheet<ImportOutcome?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _SourceChoiceView(
      // The sheet context dies on pop — run the follow-up import off the
      // outer context that opened the chooser.
      parentContext: context,
      candidates: unique,
      title: title,
      author: author,
      recommendedUrl: recommendedUrl,
      onSelected: onSelected,
    ),
  );
}

Future<ImportOutcome?> _defaultSelected(
  BuildContext context,
  ImportCandidate candidate,
) {
  return showImportUrlSheet(
    context,
    title: candidate.siteName,
    skipInputStage: true,
    initialUrl: candidate.url,
  );
}

Future<ImportOutcome?> _importCandidate(
  BuildContext context,
  ImportCandidate candidate,
  Future<ImportOutcome?> Function(BuildContext, ImportCandidate)? onSelected,
) async {
  final selected = onSelected ?? _defaultSelected;
  final outcome = await selected(context, candidate);
  if (outcome != null && context.mounted && outcome.bookId.isNotEmpty) {
    context.go(
      outcome.category == ContentCategory.novel
          ? '/novel/${outcome.bookId}'
          : '/book/${outcome.bookId}',
    );
  }
  return outcome;
}

/// The chooser: shows the book identity once, then lists every site that
/// carries it. Tapping a site hands off to the standard import sheet.
class _SourceChoiceView extends StatelessWidget {
  const _SourceChoiceView({
    required this.parentContext,
    required this.candidates,
    required this.title,
    this.recommendedUrl,
    this.author,
    this.onSelected,
  });

  final BuildContext parentContext;
  final List<ImportCandidate> candidates;
  final String title;
  final String? author;

  /// URL of the pre-selected "Recommended" source, or `null`.
  final String? recommendedUrl;
  final Future<ImportOutcome?> Function(
    BuildContext,
    ImportCandidate,
  )?
  onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSheetPadding.horizontal,
        AppSheetPadding.top,
        AppSheetPadding.horizontal,
        AppSheetPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add to Library',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: 'Fraunces',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"$title" is available on ${candidates.length} sites. '
            'Pick the one to import from.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (author != null && author!.trim().isNotEmpty)
            Text(
              'by $author',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final (icon, boxBg, iconColor) = themedSourceVisuals(
                  sourceName: candidate.siteName,
                  isNovel: true,
                  brightness: theme.brightness,
                );
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _importCandidate(parentContext, candidate, onSelected);
                    },
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: boxBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isDark ? iconColor.withValues(alpha: 0.9) : iconColor,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            candidate.siteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (candidate.url == recommendedUrl) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Recommended',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: candidate.description == null ||
                            candidate.description!.isEmpty
                        ? null
                        : Text(
                            candidate.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Icon(
                      Icons.arrow_forward_rounded,
                      color: cs.primary,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All sites import the same content into your library — '
            'pick whichever one responds fastest for you.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Paddings chosen to match the width of the shared modal sheets.
abstract final class AppSheetPadding {
  static const horizontal = 24.0;
  static const top = 8.0;
  static const bottom = 32.0;
}

