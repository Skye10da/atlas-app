import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/account/presentation/widgets/profile_edit_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/presentation/providers/library_actions.dart';
import 'package:atlas_app/library/presentation/widgets/library_filter_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

class AppShell extends HookConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarCollapsed = useState(false);
    // The centre "+" / rail button / sidebar button all open the same
    // "Add to library" flow as the Library screen.
    void onAdd() => unawaited(addToLibrary(context, ref));
    // Responsive by available window width. MediaQuery (not LayoutBuilder):
    // rebuilding the whole shell — including newly-pushed routes and their
    // tooltips/overlays — inside a LayoutBuilder layout pass triggers the
    // "RenderObject mutated while layout" framework assertion on every page
    // transition. Window width == the shell's incoming constraints, so
    // MediaQuery.sizeOf gives the identical value safely in build.
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isBigDesktop = width >= AppBreakpoints.largeDesktop;
    final isTablet =
        width >= AppBreakpoints.mobile && width < AppBreakpoints.desktop;

    if (isDesktop) {
      return _buildDesktopLayout(
        context,
        isBigDesktop,
        sidebarCollapsed,
        onAdd,
      );
    }
    if (isTablet) {
      return _buildTabletLayout(context, onAdd);
    }
    return _buildMobileLayout(context, onAdd);
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    bool isBigDesktop,
    ValueNotifier<bool> sidebarCollapsed,
    VoidCallback onAdd,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sidebarWidth = isBigDesktop && !sidebarCollapsed.value ? 260.0 : 72.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          _DesktopSidebar(
            width: sidebarWidth,
            onAdd: onAdd,
            collapsed: !isBigDesktop || sidebarCollapsed.value,
            isBigDesktop: isBigDesktop,
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            onToggleCollapse: isBigDesktop
                ? () => sidebarCollapsed.value = !sidebarCollapsed.value
                : null,
          ),
          VerticalDivider(
            width: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          // Full remaining width: every main-nav screen decides its own
          // inner max width, so the Library and wide screens use all the
          // room the window gives them instead of centering.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: navigationShell),
                const Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                  child: NarrationMiniPlayer(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, VoidCallback onAdd) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            backgroundColor: cs.surfaceContainerLow,
            indicatorColor: cs.secondaryContainer,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: onAdd,
                tooltip: 'Add book',
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                child: const Icon(Icons.add_rounded),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories_rounded),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: Text('Find new'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bookmarks_outlined),
                selectedIcon: Icon(Icons.bookmarks_rounded),
                label: Text('Saved'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: Text('Settings'),
              ),
            ],
          ),
          VerticalDivider(
            width: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: navigationShell),
                const Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                  child: NarrationMiniPlayer(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, VoidCallback onAdd) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.formContentMaxWidth,
                ),
                child: navigationShell,
              ),
            ),
          ),
          const Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.sm,
            child: NarrationMiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: _AtlasBottomBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        onAdd: onAdd,
      ),
    );
  }
}

/// Bottom navigation for compact windows: Library, Find new, a centred
/// primary "+" (add book), Saved, Settings.
///
/// "+" is an action, not a destination, so the four shell branches map to
/// bar slots 0, 1, 3 and 4 while [selectedIndex] stays the branch index.
class _AtlasBottomBar extends StatelessWidget {
  const _AtlasBottomBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _BarItem(
                icon: Icons.auto_stories_outlined,
                selectedIcon: Icons.auto_stories_rounded,
                label: 'Library',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _BarItem(
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
                label: 'Find new',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              Expanded(
                child: Center(child: _BarAddButton(onTap: onAdd)),
              ),
              _BarItem(
                icon: Icons.bookmarks_outlined,
                selectedIcon: Icons.bookmarks_rounded,
                label: 'Saved',
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              _BarItem(
                icon: Icons.tune_outlined,
                selectedIcon: Icons.tune_rounded,
                label: 'Settings',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? cs.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAddButton extends StatelessWidget {
  const _BarAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Add book',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Add book',
        child: Material(
          color: cs.primary,
          elevation: 2,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.add_rounded, size: 28, color: cs.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.width,
    required this.collapsed,
    required this.isBigDesktop,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onAdd,
    this.onToggleCollapse,
  });

  final double width;
  final bool collapsed;
  final bool isBigDesktop;
  final int currentIndex;
  final void Function(int) onDestinationSelected;
  final VoidCallback onAdd;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: width,
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          if (isBigDesktop && !collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Image.asset('assets/icon.png'),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Atlas',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (onToggleCollapse != null)
                    IconButton(
                      icon: const Icon(Icons.menu_open, size: 18),
                      onPressed: onToggleCollapse,
                      tooltip: 'Collapse sidebar',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            )
          else if (onToggleCollapse != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: GestureDetector(
                onTap: onToggleCollapse,
                child: Image.asset('assets/icon.png', width: 32, height: 32),
              ),
            ),
          const SizedBox(height: 8),
          ..._buildNavItems(context),
          if (currentIndex == 0 && !collapsed) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: LibraryFilterPanel(),
              ),
            ),
          ] else ...[
            const Spacer(),
            if (currentIndex == 0 && onToggleCollapse != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  onPressed: onToggleCollapse,
                  tooltip: 'Show filters',
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _SidebarAccountTile(collapsed: collapsed),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context) {
    final items = <(IconData, IconData, String)>[
      (Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'Library'),
      (Icons.explore_outlined, Icons.explore_rounded, 'Find new'),
      (Icons.bookmarks_outlined, Icons.bookmarks_rounded, 'Saved'),
      (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
    ];

    final navItems = List.generate(items.length, (i) {
      final isSelected = i == currentIndex;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: _SidebarNavItem(
          icon: isSelected ? items[i].$2 : items[i].$1,
          label: items[i].$3,
          isSelected: isSelected,
          collapsed: collapsed,
          onTap: () => onDestinationSelected(i),
        ),
      );
    });
    // Primary action sits between "Find new" and "Saved", mirroring the
    // compact bottom bar's centre "+".
    navItems.insert(
      2,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: _SidebarAddButton(collapsed: collapsed, onTap: onAdd),
      ),
    );
    return navItems;
  }
}

class _SidebarAccountTile extends ConsumerWidget {
  const _SidebarAccountTile({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(localAccountSummaryProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = Color(kAvatarColors[account.avatarColorIndex]);

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(
        account.avatarInitial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );

    final content = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showProfileEditSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            avatar,
            if (!collapsed) ...[
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.greetingName,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Local account',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Tooltip(
      message: collapsed ? account.displayName : 'Edit profile',
      child: content,
    );
  }
}

class _SidebarAddButton extends StatelessWidget {
  const _SidebarAddButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Center(
        child: IconButton.filled(
          onPressed: onTap,
          tooltip: 'Add book',
          icon: const Icon(Icons.add_rounded),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add book'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _SidebarNavItem extends HookWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isHovered = useState(false);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = isSelected
        ? cs.secondaryContainer
        : isHovered.value
        ? cs.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: SystemMouseCursors.click,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (isSelected && !collapsed)
                  Container(
                    width: 3,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                      color: isSelected
                          ? cs.onSecondaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showBack = false,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: title != null || showBack || actions != null
          ? AppBar(
              title: title != null ? Text(title!) : null,
              leading: showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => popOrGoToLibrary(context),
                    )
                  : null,
              actions: actions,
            )
          : null,
      body: child,
    );
  }
}
