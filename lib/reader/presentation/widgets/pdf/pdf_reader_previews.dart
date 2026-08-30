import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_outline_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

@Preview(name: 'PDF Bottom Nav - Light Mode', group: 'PDF Reader')
Widget previewPdfBottomNavLight() {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: ReaderBarSurface(
          style: ReaderChromeStyle.translucent,
          color: const Color(0xFFF5F5F5),
          child: PdfBottomNav(
            textColor: Colors.black87,
            currentPage: 14,
            totalPages: 120,
            onPageSelected: (_) {},
            onSettingsTap: () {},
            onOutlineTap: () {},
            onBookmarkTap: () {},
            isBookmarked: true,
            layoutMode: PdfReaderLayoutMode.single,
            onToggleLayoutMode: () {},
            onListenTap: () {},
            progressColor: const Color(0xFF5C6BC0),
          ),
        ),
      ),
    ),
  );
}

@Preview(name: 'PDF Bottom Nav - Dark Mode', group: 'PDF Reader')
Widget previewPdfBottomNavDark() {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF121212),
        bottomNavigationBar: ReaderBarSurface(
          style: ReaderChromeStyle.translucent,
          color: const Color(0xFF1E1E1E),
          child: PdfBottomNav(
            textColor: Colors.white,
            currentPage: 42,
            totalPages: 300,
            onPageSelected: (_) {},
            onSettingsTap: () {},
            onOutlineTap: () {},
            onBookmarkTap: () {},
            isBookmarked: false,
            layoutMode: PdfReaderLayoutMode.facing,
            onToggleLayoutMode: () {},
            onListenTap: () {},
            progressColor: const Color(0xFF90CAF9),
          ),
        ),
      ),
    ),
  );
}

@Preview(name: 'PDF Chrome Top Bar', group: 'PDF Reader')
Widget previewPdfChromeBar() {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: ReaderBarSurface(
        style: ReaderChromeStyle.translucent,
        color: const Color(0xFF1E1E1E),
        child: ReaderChromeBar(
          title: 'Design Patterns in Practice (Page 42 of 300)',
          textColor: Colors.white,
          onSettingsTap: () {},
        ),
      ),
    ),
  );
}

@Preview(name: 'PDF Outline Panel Empty', group: 'PDF Reader')
Widget previewPdfOutlinePanelEmpty() {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: PdfOutlinePanel(
          outline: const [],
          onSelected: (_) {},
        ),
      ),
    ),
  );
}

