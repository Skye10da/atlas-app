import 'package:flutter/material.dart';

/// Shared visuals for supported content sources (OPDS catalogs and
/// web-novel plugin sites) used by the Find new hub and the Bookmarks tab's site directory.
///
/// Extracted from the retired CuratedSourcesSection so the confirm sheet,
/// the sites section and any result cards stay visually consistent.

/// Well-known site home pages for sources that aren't plugin-backed
/// (used to deep link into the immersive web reader).
const Map<String, String> knownSourceHomeUrls = {
  'Project Gutenberg': 'https://www.gutenberg.org',
  'Open Library': 'https://openlibrary.org',
  'Standard Ebooks': 'https://standardebooks.org',
  'Feedbooks': 'https://www.feedbooks.com',
  'Public Domain Library': 'https://publicdomainlibrary.org',
  'Royal Road': 'https://www.royalroad.com',
};

/// Picks (icon, light background color, icon color) for a source.
/// `isNovel` drives the fallback for unbranded web-novel plugin sites.
(IconData, Color, Color) sourceVisuals(String sourceName, {required bool isNovel}) {
  final lower = sourceName.toLowerCase();
  if (lower.contains('gutenberg')) {
    return (
      Icons.account_balance_rounded,
      const Color(0xFFE8F5E9),
      const Color(0xFF2E7D32),
    );
  }
  if (lower.contains('open library') || lower.contains('openlib')) {
    return (
      Icons.menu_book_rounded,
      const Color(0xFFE3F2FD),
      const Color(0xFF1976D2),
    );
  }
  if (lower.contains('standard')) {
    return (
      Icons.auto_stories_rounded,
      const Color(0xFFF3E5F5),
      const Color(0xFF7B1FA2),
    );
  }
  if (lower.contains('feedbook')) {
    return (
      Icons.library_books_rounded,
      const Color(0xFFE0F2F1),
      const Color(0xFF00796B),
    );
  }
  if (lower.contains('royal')) {
    return (
      Icons.military_tech_rounded,
      const Color(0xFFFFF3E0),
      const Color(0xFFE65100),
    );
  }
  if (isNovel) {
    return (
      Icons.local_fire_department_rounded,
      const Color(0xFFFCE4EC),
      const Color(0xFFC2185B),
    );
  }
  return (
    Icons.language_rounded,
    const Color(0xFFF3EDF7),
    const Color(0xFF7C3AED),
  );
}

/// Blends the light-mode visual for the current theme brightness.
(IconData, Color, Color) themedSourceVisuals({
  required String sourceName,
  required bool isNovel,
  required Brightness brightness,
}) {
  final (icon, lightBg, iconColor) = sourceVisuals(sourceName, isNovel: isNovel);
  final boxBg = brightness == Brightness.dark
      ? iconColor.withValues(alpha: 0.2)
      : lightBg;
  return (icon, boxBg, iconColor);
}

