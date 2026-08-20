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
    required this.showPanelToggle,
    required this.rightPanelVisible,
    required this.onTogglePanel,
    required this.onSettingsTap,
  });

  final String title;
  final Color textColor;
  final bool showPanelToggle;
  final bool rightPanelVisible;
  final VoidCallback onTogglePanel;
  final VoidCallback onSettingsTap;

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
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      actions: [
        if (showPanelToggle) ...[
          IconButton(
            icon: Icon(
              rightPanelVisible
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 18,
              color: textColor,
            ),
            tooltip: 'Toggle panel',
            onPressed: onTogglePanel,
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          icon: Icon(Icons.text_fields, size: 18, color: textColor),
          onPressed: onSettingsTap,
        ),
      ],
    );
  }
}
