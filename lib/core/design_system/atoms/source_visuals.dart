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

/// Canonical home pages for the shipped plugin catalog sites, mirroring each
/// plugin's `baseUrl`. The manifest base is authoritative because it can
/// carry a real path — Novel Hub's site home is
/// `https://live.mangabooth.com/novelreader`, so deriving the home from a
/// novel page's scheme+host origin opens a broken bare-domain page instead.
/// Keep in sync with `atlas-plugins/*/plugin.json`.
const Map<String, String> pluginSiteHomeUrls = {
  'AllNovel': 'https://novelfull.com',
  'AllNovelFull': 'https://novgo.net',
  'Anslid': 'https://anslid.com',
  'ArNovel': 'https://ar-no.com',
  'Araz Novel': 'https://araznovel.com',
  'Belle Repository': 'https://bellerepository.com',
  'BoxNovel': 'https://novelnice.com',
  'Citrus Aurora': 'https://citrusaurora.com',
  'Dragon Tea': 'https://dragontea.ink',
  'Dusk Blossoms': 'https://duskblossoms.com',
  'Eternalune': 'https://eternalune.com',
  'Etude Translations': 'https://etudetranslations.com',
  'Fans Translations': 'https://fanstranslations.com',
  'FirstKissNovel': 'https://1stkissnovel.org',
  'Fortune Eternal': 'https://www.fortuneeternal.com',
  'FreeWebNovel': 'https://freewebnovel.com',
  'Hiraeth Translation': 'https://hiraethtranslation.com',
  'HizoManga': 'https://hizomanga.net',
  'kakikata': 'https://kakikata.com.tr',
  'LightNovelHeaven': 'https://lightnovelheaven.com',
  'LulloBox': 'https://lullobox.com',
  'LunarLetters': 'https://lunarletters.com',
  'MassNovel': 'https://massnovel.fr',
  'MysticalSeries': 'https://mysticalmerries.com',
  'MVLEMPYR': 'https://www.mvlempyr.io',
  'NeoSekai Translations': 'https://www.neosekaitranslations.com',
  'Nitro Manga': 'https://nitromanga.com',
  'Noice Translations': 'https://noicetranslations.com',
  'Novel BookID': 'https://www.novelbook.id',
  'Novel Drama': 'https://noveldrama.org',
  'Novel Full': 'https://novelfull.net',
  'Novel Hub': 'https://live.mangabooth.com/novelreader',
  'Novel Lucky': 'https://novel-lucky.com',
  'Novel Multiverse': 'https://www.novelmultiverse.com',
  'Novel Ninja': 'https://novelninja.xyz',
  'Novel PDF': 'https://novelpdf.xyz',
  'Novel Short': 'https://novel-short.com',
  'Pancho Translations': 'https://panchotranslations.com',
  'Pastel Tales': 'https://pasteltales.com',
  'Ragnar Scans': 'https://ragnarscans.com',
  'Read Fanfic': 'https://readfanfic.com',
  'ReadNovelFull': 'https://readnovelfull.com',
  'Salmon Latte': 'https://salmonlatte.com',
  'SleepyTranslations': 'https://sleepytranslations.com',
  'SonicMTL': 'https://www.sonicmtl.com',
  'Tangerine Archive': 'https://tangerinearchive.com',
  'Traducciones Amistosas': 'https://traduccionesamistosas.topmanhuas.org',
  'TranslatinOtaku': 'https://translatinotaku.net',
  'TurkceLightNovels': 'https://turkcelightnovels.com',
  'Vanovel': 'https://vanovel.com',
  'WBNovel': 'https://wbnovel.com',
  'WebNovelOku': 'https://www.webnoveloku.com',
  "Wook's Teahouse": 'https://wooksteahouse.com',
  'WordExcerpt': 'https://wordexcerpt.com',
  'WTR-LAB': 'https://wtr-lab.com',
  'WuxiaWorld.Site': 'https://wuxiaworld.site',
};

/// The home page a supported source should open in the immersive browser.
///
/// Resolution order:
/// 1. an explicitly declared home URL ([declaredHomeUrl]) — the live plugin
///    manifest's base when one is at hand;
/// 2. the plugin catalog's declared base URL ([pluginSiteHomeUrls]) —
///    authoritative, path-bearing bases survive intact;
/// 3. the curated registry of built-in sources ([knownSourceHomeUrls]);
/// 4. the scheme+host origin of [sitePageUrl], when it is an http(s) address
///    from that same site (mirror domains keep working).
///
/// Returns null when the source has no known web home.
String? sourceHomeUrl(
  String sourceName, {
  String? sitePageUrl,
  String? declaredHomeUrl,
}) {
  final declared = declaredHomeUrl ??
      pluginSiteHomeUrls[sourceName] ??
      knownSourceHomeUrls[sourceName];
  if (declared != null && Uri.tryParse(declared)?.hasScheme == true) {
    return declared;
  }
  final origin = homeOriginUrl(sitePageUrl);
  if (origin != null) return origin;
  // Learned-origin sources are keyed by bare origin host (e.g.
  // "novelfiction.net"), so treat dotted, single-token names as hosts too.
  if (sourceName.trim() == sourceName && sourceName.contains('.')) {
    return 'https://$sourceName';
  }
  return null;
}

/// Reduces a page URL to its site origin (`scheme://host`) — the address that
/// opens the site's home page. Returns null for non-http(s) URLs.
String? homeOriginUrl(String? pageUrl) {
  if (pageUrl == null) return null;
  final uri = Uri.tryParse(pageUrl);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return '${uri.scheme}://${uri.host}';
}

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

