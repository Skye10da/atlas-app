import 'package:flutter/material.dart';

/// The AppBar contents built identically by both ContinuousReaderLayout and
/// PagedReaderLayout: chapter title, an optional desktop panel-toggle icon,
/// and the settings icon. Wrap in `ReaderBarSurface` at the call site, same
/// as before — this widget only replaces the `AppBar(...)` itself.
class ReaderChromeBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderChromeBar({
    super.key,
    required this.title,
    required this.textColor,
    required this.onSettingsTap,
    this.onSearchTap,
    this.onRedownload,
    this.isRedownloading = false,
    this.leading,
    this.actions,
  });

  final String title;
  final Color textColor;
  final VoidCallback onSettingsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onRedownload;
  final bool isRedownloading;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
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
        IconButton(
          icon: Icon(Icons.text_fields, size: 18, color: textColor),
          tooltip: 'Reader settings',
          onPressed: onSettingsTap,
        ),
      ],
    );
  }
}
