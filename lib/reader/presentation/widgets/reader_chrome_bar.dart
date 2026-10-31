import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

/// The AppBar contents built identically by ContinuousReaderLayout,
/// PagedReaderLayout and RealFlipReaderLayout.
///
/// Slim mode (used with the reader dock) renders itself as three floating
/// pills — back, title, bookmark — each on the same shell as the dock capsule
/// ([ReaderPillSurface]) — and must be mounted
/// directly under a full-width `Positioned` (no `ReaderBarSurface` wrapper).
/// The default (non-slim) mode still replaces an `AppBar(...)` and expects a
/// `ReaderBarSurface` at the call site, which the PDF reader uses.
class ReaderChromeBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderChromeBar({
    super.key,
    required this.title,
    required this.textColor,
    required this.onSettingsTap,
    this.onIntelligenceTap,
    this.onSearchTap,
    this.onRedownload,
    this.isRedownloading = false,
    this.leading,
    this.actions,
    this.slim = false,
    this.onBack,
    this.onTitleTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
    this.chromeStyle = ReaderChromeStyle.translucent,
  });

  final String title;
  final Color textColor;
  final VoidCallback onSettingsTap;
  final VoidCallback? onIntelligenceTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onRedownload;
  final bool isRedownloading;
  final Widget? leading;
  final List<Widget>? actions;

  /// Slim mode (used with the reader dock): three floating pills — back at the
  /// top-left, the tappable chapter title centered, the bookmark toggle at the
  /// top-right. Search, Story Intelligence and redownload live in the dock's
  /// "More" menu. The default (false) keeps the full set of icons, which the
  /// PDF reader still uses.
  final bool slim;
  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;

  /// Reader chrome style, threaded from the mounting layout's settings. In
  /// slim mode [ReaderChromeStyle.glass] switches the three floating pills
  /// onto the liquid-glass [ReaderPillSurface]; every other value keeps the
  /// classic translucent shell. Ignored in non-slim mode (plain AppBar).
  final ReaderChromeStyle chromeStyle;

  @override
  Size get preferredSize => Size.fromHeight(slim ? 52 : 40);

  @override
  Widget build(BuildContext context) {
    if (slim) {
      // Three floating pills sharing the dock's [ReaderPillSurface] shell:
      // back hugs the top-left, the chapter title floats top-center, and the
      // bookmark toggle hugs the top-right. Each hugs its own content.
      final colorScheme = Theme.of(context).colorScheme;
      final glass = chromeStyle == ReaderChromeStyle.glass;
      Widget pill(Widget child) => ReaderPillSurface(
        colorScheme: colorScheme,
        glass: glass,
        child: Padding(padding: const EdgeInsets.all(4), child: child),
      );

      Widget iconPill(IconData icon, String tooltip, VoidCallback? onTap) =>
          pill(
            Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, size: 22, color: textColor),
                ),
              ),
            ),
          );

      final titlePill = pill(
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTitleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onTitleTap != null)
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: textColor,
                  ),
              ],
            ),
          ),
        ),
      );

      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 12,
          16,
          0,
        ),
        child: Row(
          children: [
            if (leading != null)
              pill(leading!)
            else if (onBack != null)
              iconPill(Icons.arrow_back_rounded, 'Back to Library', onBack),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: titlePill,
                ),
              ),
            ),
            if (onBookmarkTap != null)
              iconPill(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                onBookmarkTap,
              ),
          ],
        ),
      );
    }
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 40,
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      actions: actions ?? [
        if (onRedownload != null)
          IconButton(
            icon: isRedownloading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                : Icon(Icons.refresh_rounded, size: 18, color: textColor),
            tooltip: 'Redownload chapter',
            onPressed: isRedownloading ? null : onRedownload,
          ),
        if (onSearchTap != null)
          IconButton(
            icon: Icon(Icons.search_rounded, size: 18, color: textColor),
            tooltip: 'Search in book',
            onPressed: onSearchTap,
          ),
        if (onIntelligenceTap != null)
          IconButton(
            icon: Icon(Icons.psychology_outlined, size: 20, color: textColor),
            tooltip: 'Story Intelligence & Codex',
            onPressed: onIntelligenceTap,
          ),
        IconButton(
          icon: Icon(Icons.text_fields, size: 18, color: textColor),
          tooltip: 'Reader settings',
          onPressed: onSettingsTap,
        ),
      ],
    );
  }
}
