import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/account/presentation/widgets/profile_edit_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/presentation/widgets/library_filter_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

class AppShell extends HookWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final sidebarCollapsed = useState(false);
    // Responsive by available window constraints, not physical device.
    // Fixes "always expanding even when content does not cover everything":
    // short content now wraps naturally and stays centered via ConstrainedBox,
    // long content still scrolls lazily via inner ListView.builder.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Use width only (skill: MediaQuery.sizeOf for window, LayoutBuilder for parent)
        // to support resizable Windows, multi-window, foldables.
        final isDesktop = width >= AppBreakpoints.desktop;
        final isBigDesktop = width >= AppBreakpoints.largeDesktop;
        final isTablet = width >= AppBreakpoints.mobile && width < AppBreakpoints.desktop;

        if (isDesktop) {
          return _buildDesktopLayout(context, isBigDesktop, sidebarCollapsed, constraints);
        }
        if (isTablet) {
          return _buildTabletLayout(context, constraints);
        }
        return _buildMobileLayout(context, constraints);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isBigDesktop, ValueNotifier<bool> sidebarCollapsed, BoxConstraints constraints) {
    final cs = Theme.of(context).colorScheme;
    final sidebarWidth = isBigDesktop && !sidebarCollapsed.value ? 260.0 : 72.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          _DesktopSidebar(
            width: sidebarWidth,
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
          // Content-driven: not always Expanded — short content wraps naturally,
          // long content scrolls lazily. Align topCenter + ConstrainedBox caps width
          // on large screens without stretching height.
          Flexible(
            fit: FlexFit.loose,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.readerContentMaxWidth,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, BoxConstraints constraints) {
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
          Flexible(
            fit: FlexFit.loose,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.readerContentMaxWidth,
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
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, BoxConstraints constraints) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.secondaryContainer,
        shadowColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Find new',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
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
    this.onToggleCollapse,
  });

  final double width;
  final bool collapsed;
  final bool isBigDesktop;
  final int currentIndex;
  final void Function(int) onDestinationSelected;
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

    return List.generate(items.length, (i) {
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
