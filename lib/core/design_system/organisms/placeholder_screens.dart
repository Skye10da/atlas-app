import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/app_text.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Library',
      child: AppEmptyState(
        title: 'Your library is empty',
        message: 'Import books to start reading.',
        icon: Icons.library_books,
      ),
    );
  }
}

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      showBack: true,
      title: 'Reader',
      child: Center(
        child: AppText.bodyLarge('Reading view coming soon'),
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Search',
      child: AppEmptyState(
        title: 'Search your library',
        message: 'Find books and passages across your collection.',
        icon: Icons.search,
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Settings',
      child: Center(
        child: AppText.bodyMedium('Settings coming soon'),
      ),
    );
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Sign In',
      child: Center(
        child: AppText.bodyMedium('Authentication coming soon'),
      ),
    );
  }
}
