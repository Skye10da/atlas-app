import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isBigDesktop = width >= 1200;

    if (isDesktop) {
      return _buildDesktopLayout(isBigDesktop);
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout(bool isBigDesktop) {
    final cs = Theme.of(context).colorScheme;
    final sidebarWidth =
        isBigDesktop && !_sidebarCollapsed ? 260.0 : 72.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          _DesktopSidebar(
            width: sidebarWidth,
            collapsed: !isBigDesktop || _sidebarCollapsed,
            isBigDesktop: isBigDesktop,
            currentIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (index) {
              widget.navigationShell.goBranch(
                index,
                initialLocation:
                    index == widget.navigationShell.currentIndex,
              );
            },
            onToggleCollapse: isBigDesktop
                ? () => setState(() => _sidebarCollapsed = !_sidebarCollapsed)
                : null,
          ),
          VerticalDivider(width: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
        backgroundColor: cs.surfaceContainer,
        indicatorColor: cs.secondaryContainer,
        shadowColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: width,
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          if (isBigDesktop && !collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Atlas',
                      style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: IconButton(
                icon: const Icon(Icons.menu, size: 20),
                onPressed: onToggleCollapse,
                tooltip: 'Expand sidebar',
              ),
            ),
          const SizedBox(height: 8),
          ..._buildNavItems(context),
          const Spacer(),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.library_books, 'Library'),
      (Icons.bookmark_border, 'Bookmarks'),
      (Icons.search, 'Search'),
      (Icons.menu_book, 'Dictionary'),
      (Icons.settings, 'Settings'),
    ];

    return List.generate(items.length, (i) {
      final isSelected = i == currentIndex;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: _SidebarNavItem(
          icon: items[i].$1,
          label: items[i].$2,
          isSelected: isSelected,
          collapsed: collapsed,
          onTap: () => onDestinationSelected(i),
        ),
      );
    });
  }
}

class _SidebarNavItem extends StatefulWidget {
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
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = widget.isSelected
        ? cs.secondaryContainer
        : _isHovered
            ? cs.onSurface.withValues(alpha: 0.08)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(widget.icon,
                    size: 20,
                    color: widget.isSelected
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: widget.isSelected ? FontWeight.w600 : null,
                      color: widget.isSelected
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
                      onPressed: () => context.pop(),
                    )
                  : null,
              actions: actions,
            )
          : null,
      body: child,
    );
  }
}
