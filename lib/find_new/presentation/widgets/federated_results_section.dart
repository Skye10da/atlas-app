import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/find_new/presentation/widgets/import_confirm_sheet.dart';
import 'package:atlas_app/core/design_system/atoms/source_visuals.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/search/domain/federated_search.dart';
import 'package:atlas_app/search/presentation/providers/federated_search_provider.dart';

/// The deduplicated results of a federated search, one card per unique
/// book. Cards found on several sites carry an "on N sites" badge; the
/// Add action hands every site offering to the choose-a-source confirm
/// sheet (with the healthiest source pre-marked "Recommended").
/// A book that is already in the library shows "In library" and opens
/// the book instead of re-importing.
class FederatedResultsSection extends ConsumerWidget {
  const FederatedResultsSection({
    required this.term,
    required this.results,
    required this.statuses,
    super.key,
  });

  final String term;
  final List<FederatedBook> results;
  final List<SiteSearchStatus> statuses;

  /// Lazy library index — used only while cards are on screen.
  Map<String, BookEntity> _libraryByKey(WidgetRef ref) {
    final books = ref.watch(libraryBooksProvider).valueOrNull?.valueOrNull ??
        const <BookEntity>[];
    return {
      for (final book in books) federatedMatchKey(book.title, book.author): book,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFinished = statuses.every(
      (s) =>
          s.state == SiteSearchState.done ||
          s.state == SiteSearchState.empty ||
          s.state == SiteSearchState.error ||
          s.state == SiteSearchState.skipped,
    );

    if (results.isEmpty && allFinished) {
      return _EmptyResults(term: term);
    }

    final libraryByKey = _libraryByKey(ref);

    return Column(
      children: [
        for (final book in results) ...[
          _ResultCard(
            book: book,
            libraryMatch: libraryByKey[book.matchKey],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: cs.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nothing found for "$term"',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try fewer words or just the author\'s name.\n'
              'You can also paste a link directly to import.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.book,
    required this.libraryMatch,
  });

  final FederatedBook book;
  final BookEntity? libraryMatch;

  void _addToLibrary(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(federatedSearchProvider.notifier);
    final ranked = notifier.rankOfferings(book.offerings);
    showImportConfirmSheet(
      context,
      title: book.title,
      author: book.author,
      recommendedUrl: ranked.isEmpty ? null : ranked.first.importUrl,
      candidates: [
        for (final offering in ranked)
          ImportCandidate(
            siteName: offering.sourceName,
            url: offering.importUrl,
            coverUrl: offering.coverUrl,
            description: offering.description,
          ),
      ],
    );
  }

  void _openBook(BuildContext context, BookEntity book) {
    context.go(
      book.isNovel ? '/novel/${book.id}' : '/book/${book.id}',
    );
  }

  /// Title tap: an in-library book opens its local details page; an
  /// unimported result opens the novel's page on its source site in the
  /// immersive source browser (the app's current web view).
  void _openNovelPage(BuildContext context, WidgetRef ref) {
    final match = libraryMatch;
    if (match != null) {
      _openBook(context, match);
      return;
    }
    final url = book.primaryOffering?.importUrl ?? '';
    if (url.isEmpty) return;
    context.push('/web?url=${Uri.encodeComponent(url)}');
  }

  /// The site's own home page, resolved through the canonical registry: the
  /// plugin's declared base URL first (which can carry a path — Novel Hub's
  /// site home IS `https://live.mangabooth.com/novelreader`), then the
  /// offered page's site origin as a fallback. Never a search page.
  String? _siteHomePageUrl() {
    final offering = book.primaryOffering;
    if (offering == null) return null;
    return sourceHomeUrl(offering.sourceName, sitePageUrl: offering.importUrl);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = book.primaryOffering;
    final (icon, boxBg, iconColor) = themedSourceVisuals(
      sourceName: primary?.sourceName ?? '',
      isNovel: true,
      brightness: theme.brightness,
    );
    final inLibrary = libraryMatch;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.smMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              width: 52,
              height: 76,
            ),
            const SizedBox(width: AppSpacing.smMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openNovelPage(context, ref),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'Fraunces',
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          // Reads as tappable without shouting.
                          color: cs.primary.withValues(
                            alpha: 0.92,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (book.author != null && book.author!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'by ${book.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (book.description != null &&
                      book.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Site badge(s) — visually consistent with the tiles.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: boxBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 11, color: isDark ? iconColor.withValues(alpha: 0.9) : iconColor),
                            const SizedBox(width: 4),
                            Text(
                              primary?.sourceName ?? '',
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (book.isMultiSource)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'on ${book.offerings.length} sites',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (inLibrary != null)
                        FilledButton.tonalIcon(
                          onPressed: () => _openBook(context, inLibrary),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('In library'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: () => _addToLibrary(context, ref),
                          icon: const Icon(
                            Icons.bookmark_add_rounded,
                            size: 18,
                          ),
                          label: const Text('Add to Library'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // "More from site": the site itself, straight into the
                      // immersive source browser (never the per-site search
                      // page).
                      if (_siteHomePageUrl() case final homeUrl?)
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/web?url=${Uri.encodeComponent(homeUrl)}',
                          ),
                          icon: const Icon(Icons.public_rounded, size: 18),
                          label: const Text('More from site'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

