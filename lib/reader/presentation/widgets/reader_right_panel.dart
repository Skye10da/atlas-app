import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ReaderRightPanel extends ConsumerStatefulWidget {
  const ReaderRightPanel({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookmarkedChapterIds,
    required this.onChapterSelected,
    required this.onBookmarkToggle,
    required this.isBookmarked,
    required this.onClose,
    this.settings,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final Set<String> bookmarkedChapterIds;
  final void Function(int) onChapterSelected;
  final VoidCallback onBookmarkToggle;
  final bool isBookmarked;
  final VoidCallback onClose;
  final ReadingSettingsEntity? settings;

  @override
  ConsumerState<ReaderRightPanel> createState() => _ReaderRightPanelState();
}

class _ReaderRightPanelState extends ConsumerState<ReaderRightPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 4,
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'Reader',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                  tooltip: 'Close panel',
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
            indicatorColor: colors.primary,
            labelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.list, size: 18), text: 'Chapters'),
              Tab(icon: Icon(Icons.bookmark, size: 18), text: 'Bookmarks'),
              Tab(icon: Icon(Icons.settings, size: 18), text: 'Settings'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChaptersTab(
                  chapters: widget.chapters,
                  currentChapterIndex: widget.currentChapterIndex,
                  onChapterSelected: widget.onChapterSelected,
                ),
                _BookmarksTab(
                  chapters: widget.chapters,
                  bookmarkedChapterIds: widget.bookmarkedChapterIds,
                  onChapterSelected: widget.onChapterSelected,
                  onBookmarkToggle: widget.onBookmarkToggle,
                  isBookmarked: widget.isBookmarked,
                ),
                _SettingsTab(settings: widget.settings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChaptersTab extends StatelessWidget {
  const _ChaptersTab({
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int) onChapterSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (chapters.isEmpty) {
      return Center(
        child: Text(
          'No chapters',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final ch = chapters[index];
        final isCurrent = index == currentChapterIndex;
        return Material(
          color: isCurrent
              ? colors.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          child: InkWell(
            onTap: () => onChapterSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      ch.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w600 : null,
                        color: isCurrent
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab({
    required this.chapters,
    required this.bookmarkedChapterIds,
    required this.onChapterSelected,
    required this.onBookmarkToggle,
    required this.isBookmarked,
  });

  final List<ChapterEntity> chapters;
  final Set<String> bookmarkedChapterIds;
  final void Function(int) onChapterSelected;
  final VoidCallback onBookmarkToggle;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final bookmarkedChapters = chapters
        .where((ch) => bookmarkedChapterIds.contains(ch.id))
        .toList();

    if (bookmarkedChapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 32,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No bookmarks yet',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onBookmarkToggle,
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
              ),
              label: const Text('Bookmark current chapter'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: bookmarkedChapters.length,
      itemBuilder: (context, index) {
        final ch = bookmarkedChapters[index];
        final chIndex = chapters.indexOf(ch);
        return Material(
          child: InkWell(
            onTap: () {
              if (chIndex >= 0) onChapterSelected(chIndex);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.bookmark, size: 18, color: colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      ch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({this.settings});

  final ReadingSettingsEntity? settings;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Settings unavailable')),
      data: (settings) {
        final notifier = ref.read(readingSettingsProvider.notifier);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Font Size', style: textTheme.labelSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.text_decrease, size: 16),
                  Expanded(
                    child: Slider(
                      value: settings.fontSize,
                      min: 12,
                      max: 28,
                      divisions: 16,
                      label: '${settings.fontSize.round()}',
                      onChanged: (v) => notifier.setFontSize(v),
                    ),
                  ),
                  const Icon(Icons.text_increase, size: 16),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Line Height', style: textTheme.labelSmall),
              Slider(
                value: settings.lineHeight,
                min: 1.0,
                max: 2.0,
                divisions: 10,
                label: settings.lineHeight.toStringAsFixed(1),
                onChanged: (v) => notifier.setLineHeight(v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Theme', style: textTheme.labelSmall),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ReadingViewTheme.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = ReadingViewTheme.values[i];
                    final isSelected = settings.theme == t;
                    return GestureDetector(
                      onTap: () => notifier.setTheme(t),
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          color: t.resolve(colorScheme).background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : t
                                      .resolve(colorScheme)
                                      .text
                                      .withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Ab',
                            style: TextStyle(
                              color: t.resolve(colorScheme).text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Brightness', style: textTheme.labelSmall),
              Row(
                children: [
                  const Icon(Icons.brightness_low, size: 16),
                  Expanded(
                    child: Slider(
                      value: settings.brightness,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: settings.brightness.toStringAsFixed(2),
                      onChanged: (v) => notifier.setBrightness(v),
                    ),
                  ),
                  const Icon(Icons.brightness_high, size: 16),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Keep awake', style: TextStyle(fontSize: 13)),
                value: settings.keepScreenAwake,
                onChanged: (v) => notifier.setKeepScreenAwake(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Auto brightness',
                  style: TextStyle(fontSize: 13),
                ),
                value: settings.autoOptimizeBrightness,
                onChanged: (v) => notifier.setAutoOptimizeBrightness(v),
              ),
            ],
          ),
        );
      },
    );
  }
}
