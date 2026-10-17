import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

/// Novels / Books switch, "check for updates" and library search.
///
/// Three arrangements, chosen by the caller from the available width:
///  * compact: toggle fills the row, update + search icons trail it
///  * medium: fixed-width toggle, icons pushed to the end
///  * [inlineSearch]: toggle, then a full search field, then the update icon
class LibraryControlsRow extends ConsumerWidget {
  const LibraryControlsRow({
    super.key,
    required this.wide,
    required this.inlineSearch,
    required this.searchActive,
    required this.onToggleSearch,
    required this.onCheckUpdates,
    required this.searchController,
    required this.searchFocusNode,
  });

  /// True when there is room for a fixed-width toggle (>= 600dp).
  final bool wide;

  /// True on desktop widths: the search field is always visible in this row.
  final bool inlineSearch;

  /// Whether the compact search row is currently open (icon state only).
  final bool searchActive;

  final VoidCallback onToggleSearch;
  final VoidCallback onCheckUpdates;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  static const double _toggleWidth = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(libraryCategoryProvider);
    final checking =
        ref.watch(libraryViewModelProvider).valueOrNull?.isCheckingUpdates ??
        false;

    final toggle = _CategoryToggle(
      category: category,
      onChanged: (c) =>
          ref.read(libraryViewModelProvider.notifier).setCategory(c),
    );

    final syncButton = IconButton.outlined(
      onPressed: checking ? null : onCheckUpdates,
      tooltip: 'Check ongoing novels for updates',
      icon: checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded),
    );

    if (inlineSearch) {
      return Row(
        children: [
          SizedBox(width: _toggleWidth, child: toggle),
          const SizedBox(width: AppSpacing.smMd),
          Expanded(
            child: LibrarySearchField(
              controller: searchController,
              focusNode: searchFocusNode,
              showShortcutHint: true,
              onChanged: (q) =>
                  ref.read(libraryViewModelProvider.notifier).setSearchQuery(q),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          syncButton,
        ],
      );
    }

    final searchButton = IconButton.outlined(
      onPressed: onToggleSearch,
      tooltip: searchActive ? 'Close search' : 'Search library',
      icon: Icon(
        searchActive ? Icons.search_off_rounded : Icons.search_rounded,
      ),
    );

    return Row(
      children: [
        if (wide) ...[
          SizedBox(width: _toggleWidth, child: toggle),
          const Spacer(),
        ] else
          Expanded(child: toggle),
        const SizedBox(width: AppSpacing.sm),
        syncButton,
        const SizedBox(width: AppSpacing.sm),
        searchButton,
      ],
    );
  }
}

class _CategoryToggle extends StatelessWidget {
  const _CategoryToggle({required this.category, required this.onChanged});

  final LibraryCategory category;
  final ValueChanged<LibraryCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<LibraryCategory>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: LibraryCategory.novels, label: Text('Novels')),
        ButtonSegment(value: LibraryCategory.books, label: Text('Books')),
      ],
      selected: {category},
      onSelectionChanged: (selected) => onChanged(selected.first),
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
      ),
    );
  }
}

/// Debounced pill search field for the library. Used inline on desktop and
/// in its own row on compact/medium layouts.
class LibrarySearchField extends HookWidget {
  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.showShortcutHint = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Show the Ctrl K / Cmd K hint while the field is empty.
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final debounce = useRef<Timer?>(null);
    final hasText = useState(controller.text.isNotEmpty);

    useEffect(() {
      void listener() {
        final notEmpty = controller.text.isNotEmpty;
        if (notEmpty != hasText.value) hasText.value = notEmpty;
      }

      controller.addListener(listener);
      return () {
        debounce.value?.cancel();
        controller.removeListener(listener);
      };
    }, [controller]);

    void changed(String value) {
      debounce.value?.cancel();
      debounce.value = Timer(
        const Duration(milliseconds: 250),
        () => onChanged(value),
      );
    }

    final hint = defaultTargetPlatform == TargetPlatform.macOS
        ? '\u2318K'
        : 'Ctrl K';

    Widget? suffix;
    if (hasText.value) {
      suffix = IconButton(
        icon: const Icon(Icons.clear, size: 20),
        tooltip: 'Clear search',
        onPressed: () {
          controller.clear();
          debounce.value?.cancel();
          onChanged('');
        },
      );
    } else if (showShortcutHint) {
      suffix = Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hint,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Semantics(
      textField: true,
      label: 'Search library',
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: changed,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search library',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: suffix,
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
