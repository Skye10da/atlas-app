import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/find_new/presentation/widgets/federated_results_section.dart';
import 'package:atlas_app/find_new/presentation/widgets/hero_search_header.dart';
import 'package:atlas_app/find_new/presentation/widgets/import_confirm_sheet.dart';
import 'package:atlas_app/find_new/presentation/widgets/recent_searches_panel.dart';
import 'package:atlas_app/find_new/presentation/widgets/search_summary_line.dart';
import 'package:atlas_app/library/presentation/widgets/source_directory_section.dart';
import 'package:atlas_app/search/domain/federated_search.dart';
import 'package:atlas_app/search/presentation/providers/federated_search_provider.dart';
import 'package:atlas_app/search/presentation/providers/recent_searches_provider.dart';

/// "Find new" — one search field that does the right thing with whatever
/// you give it. Recent searches show while the field is focused; the saved
/// supported-sites directory sits below the search header on this screen.
/// Everything the old dashboard had (trending, For You, genres, stats) is
/// gone: this is the finder, not a feed.
///
/// * Typing switches to federated results over every supported site.
/// * Pasting a link skips search and opens the import confirm sheet.
/// * Recent searches appear while the field is focused and empty.
/// * Failures stay quiet: one summary line; blocked/timeout sites are
///   "couldn't be reached", retry re-queries only those.
///
/// Nothing runs at app start — the provider only exists while the
/// screen does, with a short keep-alive grace for back-navigation.
class FindNewScreen extends HookConsumerWidget {
  const FindNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    // Shared focus so the keyboard survives the dashboard ↔ results mode
    // switch.
    final focusNode = useFocusNode();
    // Rebuild on focus changes so the recent-searches rows can appear.
    final focused = useListenable(focusNode).hasFocus;
    final term = useState('');

    final resultsMode = term.value.trim().length >= minSearchCharacters;

    // Subscribe only while a search is on screen; leaving results mode
    // releases the provider (with a short keep-alive grace).
    final federated = resultsMode
        ? ref.watch(federatedSearchProvider)
        : null;

    if (resultsMode && federated != null) {
      return _ResultsMode(
        controller: controller,
        focusNode: focusNode,
        term: term.value.trim(),
        state: federated,
        onQuery: (value) {
          term.value = value;
          ref.read(federatedSearchProvider.notifier).query(value);
        },
        onSubmitted: (value) => _submit(context, ref, controller, term, value),
        onCleared: () {
          term.value = '';
          ref.read(federatedSearchProvider.notifier).clear();
        },
        onRetry: () =>
            ref.read(federatedSearchProvider.notifier).retryUnreachable(),
      );
    }

    return _MinimalDashboard(
      controller: controller,
      focusNode: focusNode,
      focused: focused,
      onQuery: (value) {
        term.value = value;
        ref.read(federatedSearchProvider.notifier).query(value);
      },
      onSubmitted: (value) => _submit(context, ref, controller, term, value),
      onCleared: () {
        term.value = '';
        ref.read(federatedSearchProvider.notifier).clear();
      },
      onSelectRecent: (value) {
        controller.text = value;
        term.value = value;
        ref.read(recentSearchesProvider.notifier).add(value);
        ref.read(federatedSearchProvider.notifier).run(value);
      },
    );
  }

  /// Handles submit: a link opens the import confirm sheet directly, a
  /// plain query runs the search immediately (skipping the debounce) and
  /// is remembered under recents.
  void _submit(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    ValueNotifier<String> term,
    String raw,
  ) {
    final text = raw.trim();
    if (text.isEmpty) return;

    // URL detection — a link skips search entirely.
    final link = asImportLink(text);
    if (link != null) {
      final resolved = ref.read(sourceRegistryProvider).resolve(link);
      unawaited(() async {
        await showImportConfirmSheet(
          context,
          title: link.pathSegments.isNotEmpty
              ? Uri.decodeComponent(link.pathSegments.last)
              : link.host,
          candidates: [
            ImportCandidate(
              siteName: resolved?.sourceName ?? 'Direct URL',
              url: link.toString(),
            ),
          ],
        );
      }());
      controller.clear();
      term.value = '';
      ref.read(federatedSearchProvider.notifier).clear();
      return;
    }

    if (text.length < minSearchCharacters) return;

    term.value = text;
    unawaited(ref.read(recentSearchesProvider.notifier).add(text));
    ref.read(federatedSearchProvider.notifier).run(text);
  }
}

class _ResultsMode extends StatelessWidget {
  const _ResultsMode({
    required this.controller,
    required this.focusNode,
    required this.term,
    required this.state,
    required this.onQuery,
    required this.onSubmitted,
    required this.onCleared,
    required this.onRetry,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String term;
  final FederatedSearchState state;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.smMd,
          ),
          child: HeroSearchHeader(
            controller: controller,
            focusNode: focusNode,
            onChanged: onQuery,
            onSubmitted: onSubmitted,
            onCleared: onCleared,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              SearchSummaryLine(
                statuses: state.sites,
                matchCount: state.results.length,
                onRetry: onRetry,
              ),
              const SizedBox(height: AppSpacing.md),
              FederatedResultsSection(
                term: term,
                results: state.results,
                statuses: state.sites,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MinimalDashboard extends StatelessWidget {
  const _MinimalDashboard({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onQuery,
    required this.onSubmitted,
    required this.onCleared,
    required this.onSelectRecent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;
  final ValueChanged<String> onSelectRecent;

  @override
  Widget build(BuildContext context) {
    final showRecents = focused &&
        controller.text.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroSearchHeader(
            controller: controller,
            focusNode: focusNode,
            onChanged: onQuery,
            onSubmitted: onSubmitted,
            onCleared: onCleared,
          ),
          if (showRecents) ...[
            RecentSearchesPanel(onSelect: onSelectRecent),
            const SizedBox(height: AppSpacing.md),
          ],
          // The saved supported-sites directory: one bookmark-style list of
          // rows that open each site's search screen.
          const SourceListSection(),
        ],
      ),
    );
  }
}
