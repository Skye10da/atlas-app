import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

enum ShareCardTheme {
  editorial,
  midnight,
  modern,
  sunset,
  nordic;

  String get label => switch (this) {
    ShareCardTheme.editorial => 'Editorial',
    ShareCardTheme.midnight => 'Midnight',
    ShareCardTheme.modern => 'Modern',
    ShareCardTheme.sunset => 'Sunset',
    ShareCardTheme.nordic => 'Nordic',
  };
}

enum ShareCardRatio {
  square,
  story,
  banner;

  String get label => switch (this) {
    ShareCardRatio.square => 'Square 1:1',
    ShareCardRatio.story => 'Story 9:16',
    ShareCardRatio.banner => 'Banner 16:9',
  };

  double get aspectRatio => switch (this) {
    ShareCardRatio.square => 1.0,
    ShareCardRatio.story => 9 / 16,
    ShareCardRatio.banner => 16 / 9,
  };
}

class QuoteShareCardSheet extends HookWidget {
  const QuoteShareCardSheet({
    super.key,
    required this.quoteText,
    this.bookTitle,
    this.author,
    this.chapterTitle,
    this.coverPath,
  });

  final String quoteText;
  final String? bookTitle;
  final String? author;
  final String? chapterTitle;
  final String? coverPath;

  static Future<void> show(
    BuildContext context, {
    required String quoteText,
    String? bookTitle,
    String? author,
    String? chapterTitle,
    String? coverPath,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuoteShareCardSheet(
        quoteText: quoteText,
        bookTitle: bookTitle,
        author: author,
        chapterTitle: chapterTitle,
        coverPath: coverPath,
      ),
    );
  }

  void _copyText(BuildContext context) {
    final title = bookTitle ?? 'Unknown Book';
    final authorStr = author != null ? ' by $author' : '';
    final formatted = '“${quoteText.trim()}”\n\n— $title$authorStr';
    Clipboard.setData(ClipboardData(text: formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBoundaryKey = useMemoized(() => GlobalKey());
    final theme = useState(ShareCardTheme.editorial);
    final ratio = useState(ShareCardRatio.square);
    final showCover = useState(true);
    final showAuthor = useState(true);
    final showQuotes = useState(true);
    final isExporting = useState(false);

    Future<void> exportImage() async {
      if (isExporting.value) return;
      isExporting.value = true;

      try {
        final boundary = cardBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) return;

        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final pngBytes = byteData.buffer.asUint8List();

        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final file = File('${dir.path}/atlas_quote_$timestamp.png');
          await file.writeAsBytes(pngBytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Quote card saved to: ${file.path}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image rendered successfully!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to export image: $e')),
          );
        }
      } finally {
        if (context.mounted) isExporting.value = false;
      }
    }

    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 700),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Title bar
              Row(
                children: [
                  Icon(Icons.style_rounded, size: 22, color: colors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Quote Share Card',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Card Preview Area
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: cardBoundaryKey,
                      child: _buildShareCard(
                        theme: theme.value,
                        ratio: ratio.value,
                        showQuotes: showQuotes.value,
                        showCover: showCover.value,
                        showAuthor: showAuthor.value,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Theme Selector
              Row(
                children: [
                  const Text(
                    'Theme:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final t in ShareCardTheme.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(t.label,
                                    style: const TextStyle(fontSize: 11)),
                                selected: theme.value == t,
                                onSelected: (sel) {
                                  if (sel) theme.value = t;
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Aspect Ratio Selector & Toggles
              Row(
                children: [
                  const Text(
                    'Ratio:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final r in ShareCardRatio.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(r.label,
                                    style: const TextStyle(fontSize: 11)),
                                selected: ratio.value == r,
                                onSelected: (sel) {
                                  if (sel) ratio.value = r;
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Element Toggles
              Row(
                children: [
                  const Text(
                    'Show:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Cover', style: TextStyle(fontSize: 11)),
                            selected: showCover.value,
                            onSelected: (sel) => showCover.value = sel,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Author', style: TextStyle(fontSize: 11)),
                            selected: showAuthor.value,
                            onSelected: (sel) => showAuthor.value = sel,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Quotes', style: TextStyle(fontSize: 11)),
                            selected: showQuotes.value,
                            onSelected: (sel) => showQuotes.value = sel,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyText(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Text'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isExporting.value ? null : exportImage,
                      icon: isExporting.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(isExporting.value ? 'Saving…' : 'Save Image'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareCard({
    required ShareCardTheme theme,
    required ShareCardRatio ratio,
    required bool showQuotes,
    required bool showCover,
    required bool showAuthor,
  }) {
    final (bgDecoration, textColor, subtextColor, accentColor, fontSerif) =
        switch (theme) {
      ShareCardTheme.editorial => (
          BoxDecoration(
            color: const Color(0xFFF9F6F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2DAC8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          const Color(0xFF2C2523),
          const Color(0xFF7A6F68),
          const Color(0xFFC49A45),
          true,
        ),
      ShareCardTheme.midnight => (
          BoxDecoration(
            color: const Color(0xFF12141A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2E3342), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          const Color(0xFFE6EAF2),
          const Color(0xFF8F9BB3),
          const Color(0xFF7085FF),
          false,
        ),
      ShareCardTheme.modern => (
          BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          const Color(0xFF101828),
          const Color(0xFF667085),
          const Color(0xFF0BA5EC),
          false,
        ),
      ShareCardTheme.sunset => (
          BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF0EB), Color(0xFFFFE3E8), Color(0xFFEDE4FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF80AB).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          const Color(0xFF3B1E2B),
          const Color(0xFF8C5D72),
          const Color(0xFFE0407B),
          true,
        ),
      ShareCardTheme.nordic => (
          BoxDecoration(
            color: const Color(0xFFF0F4F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD3E0E2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          const Color(0xFF1F2E35),
          const Color(0xFF607780),
          const Color(0xFF10B981),
          false,
        ),
    };

    final text = quoteText.trim();
    final effectiveText = showQuotes ? '“$text”' : text;

    return Container(
      width: 320,
      constraints: BoxConstraints(
        minHeight: switch (ratio) {
          ShareCardRatio.square => 320,
          ShareCardRatio.story => 480,
          ShareCardRatio.banner => 180,
        },
      ),
      decoration: bgDecoration,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top accent & quotation icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 32,
                color: accentColor.withValues(alpha: 0.75),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ATLAS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Quote Text
          Text(
            effectiveText,
            style: TextStyle(
              fontSize: text.length > 200 ? 14 : 16.5,
              height: 1.5,
              fontWeight: fontSerif ? FontWeight.w500 : FontWeight.w600,
              fontFamily: fontSerif ? 'Playfair Display' : null,
              fontStyle: fontSerif ? FontStyle.italic : FontStyle.normal,
              color: textColor,
            ),
          ),
          const SizedBox(height: 18),

          // Book Metadata & Cover Footer
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showCover && coverPath != null) ...[
                Container(
                  width: 34,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: BookCover(
                    coverPath: coverPath,
                    width: 34,
                    height: 46,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bookTitle != null)
                      Text(
                        bookTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    if (showAuthor && author != null)
                      Text(
                        author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: subtextColor,
                        ),
                      ),
                    if (chapterTitle != null)
                      Text(
                        chapterTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: subtextColor.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
