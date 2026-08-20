import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

/// A full-screen preview of a reading theme, allowing the user to see
/// how text looks on the selected background before applying it.
class ThemePreviewScreen extends StatefulWidget {
  const ThemePreviewScreen({
    super.key,
    required this.initialTheme,
    required this.onApply,
  });

  final ReadingViewTheme initialTheme;
  final ValueChanged<ReadingViewTheme> onApply;

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  late ReadingViewTheme _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initialTheme;
  }

  void _prevTheme() {
    const themes = ReadingViewTheme.values;
    final idx = themes.indexOf(_currentTheme);
    setState(() {
      _currentTheme = themes[(idx - 1 + themes.length) % themes.length];
    });
  }

  void _nextTheme() {
    const themes = ReadingViewTheme.values;
    final idx = themes.indexOf(_currentTheme);
    setState(() {
      _currentTheme = themes[(idx + 1) % themes.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _currentTheme.resolve(colorScheme);
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < 0) {
            _nextTheme();
          } else if (v > 0) {
            _prevTheme();
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, colors),
              Expanded(child: _buildPreviewContent(colors)),
              _buildBottomBar(context, colors, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ReadingColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: colors.text),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Text(
            _currentTheme.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const Spacer(),
          Text(
            '${ReadingViewTheme.values.indexOf(_currentTheme) + 1} / ${ReadingViewTheme.values.length}',
            style: TextStyle(
              fontSize: 14,
              color: colors.text.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(ReadingColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter header
          Text(
            'Chapter 1',
            style: GoogleFonts.getFont(
              'Playfair Display',
              textStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Beginning of a Journey',
            style: GoogleFonts.getFont(
              'Playfair Display',
              textStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Ornamental divider
          Center(
            child: Text(
              ' \u2766 ',
              style: TextStyle(
                fontSize: 16,
                color: colors.accent.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Drop cap paragraph
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'T',
                  style: GoogleFonts.getFont(
                    'Playfair Display',
                    textStyle: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                      height: 1.1,
                    ),
                  ),
                ),
                TextSpan(
                  text:
                      'he morning sun cast long shadows across the cobblestone street as '
                      'Elena stepped out of the small bookshop. The scent of old paper and '
                      'fresh ink lingered in the air, a familiar comfort that had accompanied '
                      'her for as long as she could remember. She adjusted the leather satchel '
                      'overher shoulder, feeling the weight of the manuscript inside.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.8,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Second paragraph
          Text(
            'The city was waking up around her. Street vendors were setting up their '
            'carts, the aroma of freshly baked bread mixing with the cool morning air. '
            'A tram rattled past, its bells chiming a familiar melody that seemed to '
            'say: hurry along, there\'s much to see today.',
            style: TextStyle(fontSize: 18, height: 1.8, color: colors.text),
          ),
          const SizedBox(height: 24),
          // Third paragraph
          Text(
            'She had spent the entire night poring over the ancient text, tracing the '
            'faded ink with her fingertips, trying to decipher meanings that had eluded '
            'scholars for centuries. Now, in the harsh light of day, the words still '
            'whispered their secrets just beyond the edge of understanding.',
            style: TextStyle(fontSize: 18, height: 1.8, color: colors.text),
          ),
          const SizedBox(height: 24),
          // Highlight sample
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'This is a highlighted passage — a note to remember.',
              style: TextStyle(fontSize: 18, height: 1.8, color: colors.text),
            ),
          ),
          const SizedBox(height: 24),
          // End of chapter
          Center(
            child: Text(
              '\u00A7',
              style: TextStyle(
                fontSize: 18,
                color: colors.text.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ReadingColors colors,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Theme swatches
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ReadingViewTheme.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final t = ReadingViewTheme.values[index];
                  final isSelected = t == _currentTheme;
                  final tc = t.resolve(Theme.of(context).colorScheme);
                  return GestureDetector(
                    onTap: () => setState(() => _currentTheme = t),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tc.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : tc.text.withValues(alpha: 0.15),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Ab',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tc.text,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Apply button
          FilledButton(
            onPressed: () {
              widget.onApply(_currentTheme);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
