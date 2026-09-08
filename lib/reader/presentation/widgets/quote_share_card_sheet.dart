import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

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

  IconData get icon => switch (this) {
    ShareCardRatio.square => Icons.crop_square,
    ShareCardRatio.story => Icons.crop_portrait,
    ShareCardRatio.banner => Icons.crop_landscape,
  };
}

enum ShareCardFontSize {
  small,
  medium,
  large;

  String get label => switch (this) {
    ShareCardFontSize.small => 'Small',
    ShareCardFontSize.medium => 'Medium',
    ShareCardFontSize.large => 'Large',
  };

  double get scale => switch (this) {
    ShareCardFontSize.small => 0.85,
    ShareCardFontSize.medium => 1.0,
    ShareCardFontSize.large => 1.3,
  };
}

/// A complete color scheme for the card. Picking a non-[auto] scheme
/// overrides the theme's background, accent, and (derived) text colors
/// together so contrast is always maintained.
enum ShareCardScheme {
  auto,
  cream(Color(0xFFFAF7F2), Color(0xFFC49A45)),
  night(Color(0xFF12141A), Color(0xFF7085FF)),
  slate(Color(0xFF1F2E35), Color(0xFF10B981)),
  blush(Color(0xFFFFE3E8), Color(0xFFE0407B)),
  lavender(Color(0xFFEDE4FF), Color(0xFF8B5CF6)),
  mist(Color(0xFFF0F4F5), Color(0xFF0D9488)),
  charcoal(Color(0xFF2A2A2E), Color(0xFFE87A6A)),
  forest(Color(0xFF10261B), Color(0xFF34D399)),
  ocean(Color(0xFF082F49), Color(0xFF38BDF8)),
  sunset(Color(0xFF7C2D12), Color(0xFFFB923C));

  const ShareCardScheme([
    this.bg = Colors.transparent,
    this.accent = Colors.transparent,
  ]);

  final Color bg;
  final Color accent;

  Color get text => bg.computeLuminance() > 0.5
      ? const Color(0xFF1F2933)
      : const Color(0xFFF2F5F7);

  Color get subtext => text.withValues(alpha: 0.72);

  String get label => switch (this) {
    ShareCardScheme.auto => 'Auto',
    ShareCardScheme.cream => 'Cream',
    ShareCardScheme.night => 'Night',
    ShareCardScheme.slate => 'Slate',
    ShareCardScheme.blush => 'Blush',
    ShareCardScheme.lavender => 'Lavender',
    ShareCardScheme.mist => 'Mist',
    ShareCardScheme.charcoal => 'Charcoal',
    ShareCardScheme.forest => 'Forest',
    ShareCardScheme.ocean => 'Ocean',
    ShareCardScheme.sunset => 'Sunset',
  };
}

class QuoteShareCardSheet extends HookConsumerWidget {
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

  Future<void> _shareText(BuildContext context) async {
    final title = bookTitle ?? 'Unknown Book';
    final authorStr = author != null ? ' by $author' : '';
    final formatted = '“${quoteText.trim()}”\n\n— $title$authorStr';
    await SharePlus.instance.share(ShareParams(text: formatted));
  }

  Future<void> _shareImage(
    BuildContext context,
    GlobalKey cardBoundaryKey,
  ) async {
    final pngBytes = await _renderCard(cardBoundaryKey);
    if (pngBytes == null) {
      if (context.mounted) {
        _showError(context, 'Failed to render image for sharing.');
      }
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/atlas_quote_share.png');
      await file.writeAsBytes(pngBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _shareTextFallback(),
        ),
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to share image: $e');
    }
  }

  String _shareTextFallback() {
    final title = bookTitle ?? 'Unknown Book';
    final authorStr = author != null ? ' by $author' : '';
    return '“${quoteText.trim()}”\n\n— $title$authorStr';
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showShareMenu(
    BuildContext context,
    GlobalKey cardBoundaryKey,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields_rounded),
              title: const Text('Share Text'),
              subtitle: const Text('Share the quote as plain text'),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _shareText(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('Share Image'),
              subtitle: const Text('Share the quote card as an image'),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _shareImage(context, cardBoundaryKey);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _renderCard(GlobalKey cardBoundaryKey) async {
    final boundary =
        cardBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableFonts =
        ref.watch(availableFontFamiliesProvider).valueOrNull ??
        const <String>[];
    final readerFont = ref
        .watch(readingSettingsProvider)
        .valueOrNull
        ?.fontFamily;

    final cardBoundaryKey = useMemoized(() => GlobalKey());
    final theme = useState(ShareCardTheme.editorial);
    final ratio = useState(ShareCardRatio.square);
    final showCover = useState(true);
    final showAuthor = useState(true);
    final showQuotes = useState(true);
    final isExporting = useState(false);
    final fontSize = useState(ShareCardFontSize.medium);
    final fontFamily = useState<String?>(readerFont);
    final bold = useState(false);
    final italic = useState(false);
    final underline = useState(false);
    final scheme = useState(ShareCardScheme.auto);
    final roundedCorners = useState(true);
    final showShadow = useState(true);
    final expandQuote = useState(false);

    final fontChoices = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(readerFont ?? 'System', overflow: TextOverflow.ellipsis),
      ),
      for (final family in availableFonts)
        if (family != readerFont)
          DropdownMenuItem<String?>(
            value: family,
            child: Text(family, overflow: TextOverflow.ellipsis),
          ),
    ];

    final selectedFont = fontFamily.value;
    if (selectedFont != null &&
        !fontChoices.any((item) => item.value == selectedFont)) {
      fontChoices.add(
        DropdownMenuItem<String?>(
          value: selectedFont,
          child: Text(selectedFont, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    Future<void> exportImage() async {
      if (isExporting.value) return;
      isExporting.value = true;

      try {
        final pngBytes = await _renderCard(cardBoundaryKey);
        if (pngBytes == null) return;

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to export image: $e')));
        }
      } finally {
        if (context.mounted) isExporting.value = false;
      }
    }

    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 760),
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
              Flexible(
                flex: 3,
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
                        fontSize: fontSize.value,
                        fontFamily: fontFamily.value,
                        bold: bold.value,
                        italic: italic.value,
                        underline: underline.value,
                        scheme: scheme.value,
                        roundedCorners: roundedCorners.value,
                        showShadow: showShadow.value,
                        expandQuote: expandQuote.value,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Customization Controls (tabbed)
              Flexible(
                flex: 5,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelPadding: EdgeInsets.symmetric(horizontal: 14),
                        tabs: [
                          Tab(text: 'Design'),
                          Tab(text: 'Typography'),
                          Tab(text: 'Layout'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // ---------------- Design tab ----------------
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _groupLabel(context, 'Theme'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final t in ShareCardTheme.values)
                                        ChoiceChip(
                                          label: Text(
                                            t.label,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          selected: theme.value == t,
                                          onSelected: (sel) {
                                            if (sel) theme.value = t;
                                          },
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _groupLabel(context, 'Color scheme'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ChoiceChip(
                                        avatar: const Icon(
                                          Icons.auto_awesome,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Theme',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected:
                                            scheme.value ==
                                            ShareCardScheme.auto,
                                        onSelected: (sel) {
                                          if (sel) {
                                            scheme.value = ShareCardScheme.auto;
                                          }
                                        },
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      for (final s in ShareCardScheme.values)
                                        if (s != ShareCardScheme.auto)
                                          _ColorDot(
                                            color: s.bg,
                                            selected: scheme.value == s,
                                            onTap: () => scheme.value = s,
                                            semanticsLabel: s.label,
                                          ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _groupLabel(context, 'Card shape'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _IconChip(
                                        icon: roundedCorners.value
                                            ? Icons.rounded_corner
                                            : Icons.straighten,
                                        label: roundedCorners.value
                                            ? 'Rounded'
                                            : 'Sharp',
                                        selected: roundedCorners.value,
                                        onTap: () => roundedCorners.value =
                                            !roundedCorners.value,
                                      ),
                                      _IconChip(
                                        icon: showShadow.value
                                            ? Icons.layers_rounded
                                            : Icons.layers_clear,
                                        label: showShadow.value
                                            ? 'Shadow'
                                            : 'No shadow',
                                        selected: showShadow.value,
                                        onTap: () => showShadow.value =
                                            !showShadow.value,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ---------------- Typography tab ----------------
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _groupLabel(context, 'Font'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String?>(
                                    initialValue: fontFamily.value,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: fontChoices,
                                    onChanged: (value) =>
                                        fontFamily.value = value,
                                  ),
                                  const SizedBox(height: 10),
                                  _groupLabel(context, 'Text size'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final f in ShareCardFontSize.values)
                                        _IconChip(
                                          icon: switch (f) {
                                            ShareCardFontSize.small =>
                                              Icons.text_decrease,
                                            ShareCardFontSize.medium =>
                                              Icons.text_fields,
                                            ShareCardFontSize.large =>
                                              Icons.text_increase,
                                          },
                                          label: f.label,
                                          selected: fontSize.value == f,
                                          onTap: () => fontSize.value = f,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _groupLabel(context, 'Format'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      FilterChip(
                                        avatar: const Icon(
                                          Icons.format_bold,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Bold',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected: bold.value,
                                        onSelected: (sel) => bold.value = sel,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      FilterChip(
                                        avatar: const Icon(
                                          Icons.format_italic,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Italic',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected: italic.value,
                                        onSelected: (sel) => italic.value = sel,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      FilterChip(
                                        avatar: const Icon(
                                          Icons.format_underline,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Underline',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected: underline.value,
                                        onSelected: (sel) =>
                                            underline.value = sel,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ---------------- Layout tab ----------------
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _groupLabel(context, 'Aspect ratio'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final r in ShareCardRatio.values)
                                        _IconChip(
                                          icon: r.icon,
                                          label: r.label,
                                          selected: ratio.value == r,
                                          onTap: () => ratio.value = r,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _groupLabel(context, 'Show'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      FilterChip(
                                        avatar: const Icon(
                                          Icons.menu_book,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Cover',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected: showCover.value,
                                        onSelected: (sel) =>
                                            showCover.value = sel,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      FilterChip(
                                        avatar: const Icon(
                                          Icons.person_outline,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Author',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected: showAuthor.value,
                                        onSelected: (sel) =>
                                            showAuthor.value = sel,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      FilterChip(
                                        avatar: const Icon(
                                          Icons.format_quote,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Quotes',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        selected: showQuotes.value,
                                        onSelected: (sel) =>
                                            showQuotes.value = sel,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _groupLabel(context, 'Quote length'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _IconChip(
                                        icon: Icons.unfold_more,
                                        label: expandQuote.value
                                            ? 'Expanded'
                                            : 'Collapsed',
                                        selected: expandQuote.value,
                                        onTap: () => expandQuote.value =
                                            !expandQuote.value,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showShareMenu(context, cardBoundaryKey),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _groupLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildShareCard({
    required ShareCardTheme theme,
    required ShareCardRatio ratio,
    required bool showQuotes,
    required bool showCover,
    required bool showAuthor,
    required ShareCardFontSize fontSize,
    required String? fontFamily,
    required bool bold,
    required bool italic,
    required bool underline,
    required ShareCardScheme scheme,
    required bool roundedCorners,
    required bool showShadow,
    required bool expandQuote,
  }) {
    final (
      bgDecoration,
      textColor,
      subtextColor,
      accentColor,
    ) = switch (theme) {
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
      ),
    };

    final useScheme = scheme != ShareCardScheme.auto;
    final effectiveBgColor = useScheme ? scheme.bg : null;
    final effectiveTextColor = useScheme ? scheme.text : textColor;
    final effectiveSubtextColor = useScheme ? scheme.subtext : subtextColor;
    final effectiveAccent = useScheme ? scheme.accent : accentColor;

    BoxDecoration effectiveBg() {
      final radius = roundedCorners
          ? BorderRadius.circular(16)
          : BorderRadius.zero;
      final shadow = showShadow ? bgDecoration.boxShadow : null;

      if (effectiveBgColor != null) {
        return BoxDecoration(
          color: effectiveBgColor,
          borderRadius: radius,
          border: bgDecoration.border,
          boxShadow: shadow,
        );
      }
      return bgDecoration.copyWith(borderRadius: radius, boxShadow: shadow);
    }

    final text = quoteText.trim();
    final effectiveText = showQuotes ? '“$text”' : text;

    final quoteBaseFontSize = text.length > 200 ? 16.0 : 22.0;
    final quoteFontSize = (quoteBaseFontSize * fontSize.scale)
        .clamp(12.0, 40.0)
        .toDouble();

    return Container(
      width: 320,
      constraints: BoxConstraints(
        minHeight: switch (ratio) {
          ShareCardRatio.square => 320,
          ShareCardRatio.story => 480,
          ShareCardRatio.banner => 180,
        },
      ),
      decoration: effectiveBg(),
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
                color: effectiveAccent.withValues(alpha: 0.75),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: effectiveAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ATLAS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: effectiveAccent,
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
            maxLines: (expandQuote || text.length <= 200) ? null : 6,
            overflow: (expandQuote || text.length <= 200)
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: quoteFontSize,
              height: 1.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontFamily: fontFamily,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
              color: effectiveTextColor,
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
                  child: BookCover(coverPath: coverPath, width: 34, height: 46),
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
                          color: effectiveTextColor,
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
                          color: effectiveSubtextColor,
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
                          color: effectiveSubtextColor.withValues(alpha: 0.8),
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

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.semanticsLabel,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black.withValues(alpha: 0.12),
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: _dotCheckColor(color),
                )
              : null,
        ),
      ),
    );
  }

  Color _dotCheckColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
