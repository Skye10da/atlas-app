import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/account/presentation/widgets/profile_edit_sheet.dart';
import 'package:atlas_app/core/design_system/nav_chrome_providers.dart';
import 'package:atlas_app/core/design_system/organisms/atlas_glass_nav_bar.dart';
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
          return _buildDesktopLayout(
            context,
            ref,
            isBigDesktop,
            sidebarCollapsed,
            constraints,
            onAdd,
          );
        }
        if (isTablet) {
          return _buildTabletLayout(context, ref, constraints, onAdd);
        }
        return _buildMobileLayout(context, ref, constraints, onAdd);
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    bool isBigDesktop,
    ValueNotifier<bool> sidebarCollapsed,
    BoxConstraints constraints,
    VoidCallback onAdd,
  ) {
    final cs = Theme.of(context).colorScheme;
    final glass =
        ref.watch(navChromeProvider) == NavChromeStyle.glass;
    final sidebarWidth = isBigDesktop && !sidebarCollapsed.value ? 260.0 : 72.0;

    Widget shellContent(double leftInset) => Positioned.fill(
          left: leftInset,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.shellContentMaxWidth,
              ),
              child: glass
                  ? _PageGlanceReveal(
                      index: navigationShell.currentIndex,
                      child: navigationShell,
                    )
                  : navigationShell,
            ),
          ),
        );

    Widget miniPlayer(double left) => Positioned(
          left: left,
          right: AppSpacing.md,
          bottom: AppSpacing.sm,
          child: const NarrationMiniPlayer(),
        );

    if (glass) {
      // The sidebar becomes a floating frosted capsule docked at the left
      // edge, with the shell content scrolling UNDERNEATH it (the overlay is
      // what makes the backdrop blur actually show through).
      const sideMargin = 12.0;
      final contentInset = sidebarWidth + sideMargin + 8;
      return Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          children: [
            shellContent(contentInset),
            miniPlayer(contentInset + 12),
            Positioned(
              left: sideMargin,
              top: sideMargin,
              bottom: sideMargin,
              width: sidebarWidth,
              child: GlassCapsule(
                borderRadius: 24,
                blur: 24,
                strong: true,
                child: _DesktopSidebar(
                  glass: true,
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
              ),
            ),
          ],
        ),
      );
    }

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
                        maxWidth: AppBreakpoints.shellContentMaxWidth,
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

  Widget _buildTabletLayout(
    BuildContext context,
    WidgetRef ref,
    BoxConstraints constraints,
    VoidCallback onAdd,
  ) {
    final cs = Theme.of(context).colorScheme;
    final glass =
        ref.watch(navChromeProvider) == NavChromeStyle.glass;
    const items = [
      AtlasNavItem(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
        label: 'Library',
      ),
      AtlasNavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Find new',
      ),
      AtlasNavItem(
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks_rounded,
        label: 'Saved',
      ),
      AtlasNavItem(
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune_rounded,
        label: 'Settings',
      ),
    ];

    Widget content(EdgeInsets padding) => Positioned.fill(
          left: padding.left,
          top: 0,
          right: padding.right,
          bottom: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.shellContentMaxWidth,
              ),
              child: glass
                  ? _PageGlanceReveal(
                      index: navigationShell.currentIndex,
                      child: navigationShell,
                    )
                  : navigationShell,
            ),
          ),
        );

    if (glass) {
      // Floating vertical capsule: rail (76 + 12 margins) sits OVER the shell
      // which is inset on the left to stay clear of it.
      const railInset = 96.0; // 12 margin + 76 capsule + 8 breathing room
      return Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          children: [
            content(const EdgeInsets.only(left: railInset)),
            const Positioned(
              left: railInset + 12,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
              child: NarrationMiniPlayer(),
            ),
            Positioned(
              left: 8,
              top: 8,
              bottom: 8,
              child: AtlasGlassRail(
                items: items,
                currentIndex: navigationShell.currentIndex,
                onChanged: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
                action:
                    AtlasNavAction(icon: Icons.add_rounded, onTap: onAdd),
              ),
            ),
          ],
        ),
      );
    }

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
          Flexible(
            fit: FlexFit.loose,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.shellContentMaxWidth,
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

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    BoxConstraints constraints,
    VoidCallback onAdd,
  ) {
    final cs = Theme.of(context).colorScheme;
    final glass =
        ref.watch(navChromeProvider) == NavChromeStyle.glass;
    const items = [
      AtlasNavItem(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
        label: 'Library',
      ),
      AtlasNavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Find new',
      ),
      AtlasNavItem(
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks_rounded,
        label: 'Saved',
      ),
      AtlasNavItem(
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune_rounded,
        label: 'Settings',
      ),
    ];

    // Glass mode floats the capsule over the content (extendBody), so the
    // docked mini player must sit ABOVE it: bar = 12 top pad + 68 + 12 bottom.
    final miniPlayerBottom = glass ? 96.0 : AppSpacing.sm;

    Widget miniPlayer(double bottom) => Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: bottom,
          child: const NarrationMiniPlayer(),
        );

    return Scaffold(
      backgroundColor: cs.surface,
      extendBody: glass,
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.formContentMaxWidth,
                ),
                child: glass
                    ? _PageGlanceReveal(
                        index: navigationShell.currentIndex,
                        child: navigationShell,
                      )
                    : navigationShell,
              ),
            ),
          ),
          miniPlayer(miniPlayerBottom),
        ],
      ),
      bottomNavigationBar: glass
          ? AtlasGlassNavBar(
              items: items,
              currentIndex: navigationShell.currentIndex,
              onChanged: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              action: AtlasNavAction(icon: Icons.add_rounded, onTap: onAdd),
            )
          : _AtlasBottomBar(
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
              Expanded(child: Center(child: _BarAddButton(onTap: onAdd))),
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
                child: Icon(selected ? selectedIcon : icon, size: 24, color: color),
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

/// Page-content reveal that echoes the glass nav lens: a quick slide-up with
/// a spring-like overshoot plus a fade, replayed on every branch switch.
///
/// The child subtree is NOT remounted — [index] only triggers the animation,
/// so nested Navigator/scroll state (the go_router shell) is preserved.
class _PageGlanceReveal extends StatefulWidget {
  const _PageGlanceReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_PageGlanceReveal> createState() => _PageGlanceRevealState();
}

class _PageGlanceRevealState extends State<_PageGlanceReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Start settled: never flash on first mount.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _PageGlanceReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        // easeOutBack slides the content UP with a small liquid overshoot
        // (it goes slightly past the resting point, then settles) — the
        // page-level twin of the lens' spring metrology.
        final slide = 1 - Curves.easeOutBack.transform(t);
        final fade = Curves.easeOut.transform(t);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, slide * 16),
            child: child,
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
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
    this.glass = false,
  });

  final double width;
  final bool collapsed;
  final bool isBigDesktop;
  final int currentIndex;
  final void Function(int) onDestinationSelected;
  final VoidCallback onAdd;
  final VoidCallback? onToggleCollapse;

  final bool glass;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final column = Column(
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
          ...(glass
              ? [
                  _SidebarNavList(
                    currentIndex: currentIndex,
                    collapsed: collapsed,
                    onDestinationSelected: onDestinationSelected,
                    onAdd: onAdd,
                    accent: cs.primary,
                  ),
                ]
              : _buildNavItems(context)),
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
      );

    if (glass) {
      // The frosted background comes from the hosting GlassCapsule — render
      // only the interior column with breathing room for the capsule rim.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox.expand(child: column),
      );
    }

    return Container(
      width: width,
      color: cs.surfaceContainerLow,
      child: column,
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

/// Desktop glass sidebar nav: the same spring "liquid glass" droplet used by
/// the mobile bar and tablet rail, generalized to variable-slot metrics
/// (positions are measured per-slot because the "+" button row is taller).
@visibleForTesting
class AtlasSidebarGlassNavList extends StatelessWidget {
  const AtlasSidebarGlassNavList({
    super.key,
    required this.currentIndex,
    required this.collapsed,
    required this.onDestinationSelected,
    required this.onAdd,
    required this.accent,
  });

  final int currentIndex;
  final bool collapsed;
  final void Function(int) onDestinationSelected;
  final VoidCallback onAdd;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _SidebarNavList(
      currentIndex: currentIndex,
      collapsed: collapsed,
      onDestinationSelected: onDestinationSelected,
      onAdd: onAdd,
      accent: accent,
    );
  }
}

class _SidebarNavList extends StatefulWidget {
  const _SidebarNavList({
    required this.currentIndex,
    required this.collapsed,
    required this.onDestinationSelected,
    required this.onAdd,
    required this.accent,
  });

  final int currentIndex;
  final bool collapsed;
  final void Function(int) onDestinationSelected;
  final VoidCallback onAdd;
  final Color accent;

  @override
  State<_SidebarNavList> createState() => _SidebarNavListState();
}

class _SidebarNavListState extends State<_SidebarNavList>
    with SingleTickerProviderStateMixin {
  // Same metrology as _GlassNavCoreState's spring.
  static const _spring = SpringDescription(mass: 1, stiffness: 220, damping: 18);
  static const _actionSlot = 2;
  static const _sidePad = 8.0;

  late final AnimationController _ctrl =
      AnimationController.unbounded(vsync: this);

  final _stackKey = GlobalKey();
  final List<GlobalKey> _slotKeys = List.generate(5, (_) => GlobalKey());

  double _targetTop = 0;
  double _targetH = 44;
  bool _measured = false;

  int get _slotOf => widget.currentIndex < _actionSlot
      ? widget.currentIndex
      : widget.currentIndex + 1;

  int _slotFor(int dest) => dest < _actionSlot ? dest : dest + 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _snap());
  }

  @override
  void didUpdateWidget(covariant _SidebarNavList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _measureTarget();
        if (!_measured) return;
        _glide();
      });
    } else if (oldWidget.collapsed != widget.collapsed) {
      // Collapse toggles item metrics: snap to the new geometry without a
      // half-finished spring.
      WidgetsBinding.instance.addPostFrameCallback((_) => _snap());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snap() {
    if (!mounted) return;
    _measureTarget();
    if (!_measured) return;
    _ctrl.value = _targetTop;
    setState(() {});
  }

  void _glide() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = _targetTop;
      return;
    }
    _ctrl.animateWith(
      SpringSimulation(_spring, _ctrl.value, _targetTop, _ctrl.velocity),
    );
  }

  void _measureTarget() {
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final slotBox = _slotKeys[_slotOf].currentContext?.findRenderObject()
        as RenderBox?;
    if (stackBox == null || slotBox == null) return;
    final pos = slotBox.localToGlobal(Offset.zero, ancestor: stackBox);
    setState(() {
      _targetTop = pos.dy;
      _targetH = slotBox.size.height;
      _measured = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const items = [
      (Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'Library'),
      (Icons.explore_outlined, Icons.explore_rounded, 'Find new'),
      (Icons.bookmarks_outlined, Icons.bookmarks_rounded, 'Saved'),
      (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
    ];

    final slots = List<Widget>.filled(5, const SizedBox.shrink());
    for (var dest = 0; dest < items.length; dest++) {
      final slot = _slotFor(dest);
      final isSelected = dest == widget.currentIndex;
      slots[slot] = Padding(
        key: _slotKeys[slot],
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: _SidebarNavItem(
          icon: isSelected ? items[dest].$2 : items[dest].$1,
          label: items[dest].$3,
          isSelected: isSelected,
          collapsed: widget.collapsed,
          glass: true,
          onTap: () => widget.onDestinationSelected(dest),
        ),
      );
    }
    // "+" between "Find new" and "Saved" — an action, never a destination.
    slots[_actionSlot] = Padding(
      key: _slotKeys[_actionSlot],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: _SidebarAddButton(
        collapsed: widget.collapsed,
        onTap: widget.onAdd, // Actions never move the lens.
      ),
    );

    return Stack(
      key: _stackKey,
      children: [
        if (_measured)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              // Velocity stretch along the motion axis, squash across it:
              // px-velocity, so the factor is per-pixel.
              final stretch =
                  (_ctrl.velocity.abs() * 0.0012).clamp(0.0, 0.3);
              return Positioned(
                left: _sidePad,
                right: _sidePad,
                top: _ctrl.value,
                child: SizedBox(
                  height: _targetH,
                  child: Transform.scale(
                    alignment: Alignment.center,
                    scaleX: 1 - stretch * 0.45,
                    scaleY: 1 + stretch,
                    child: GlassLens(
                      accent: widget.accent,
                      isDark: isDark,
                      radius: _targetH / 2,
                    ),
                  ),
                ),
              );
            },
          ),
        // Slots in a real column (the Stack is only the lens canvas) —
        // putting them directly in the Stack made every row overlap at the
        // top edge, hiding all but the last item and misfiring taps.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: slots,
        ),
      ],
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
    this.glass = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  /// Glass chrome: the frosted droplet indicator lives in the hosting
  /// [_SidebarNavList] instead of a per-item Material pill.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final isHovered = useState(false);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = glass
        ? Colors.transparent
        : isSelected
        ? cs.secondaryContainer
        : isHovered.value
        ? cs.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;

    final content = Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (!glass && isSelected && !collapsed)
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
                color: glass
                    ? (isSelected ? cs.primary : cs.onSurfaceVariant)
                    : isSelected
                    ? cs.onSecondaryContainer
                    : cs.onSurfaceVariant,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : null,
                    color: glass
                        ? (isSelected ? cs.primary : cs.onSurfaceVariant)
                        : isSelected
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: SystemMouseCursors.click,
      child: content,
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
