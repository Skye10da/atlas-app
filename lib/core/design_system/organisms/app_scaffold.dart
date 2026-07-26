import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(navigationShell: navigationShell),
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
    return Scaffold(
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

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: navigationShell.currentIndex,
      onTap: (index) => navigationShell.goBranch(index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books),
          label: 'Library',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
      ],
    );
  }
}
