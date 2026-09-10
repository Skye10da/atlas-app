import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/presentation/providers/notification_provider.dart';

class NotificationScreen extends HookConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notificationsAsync = ref.watch(notificationHistoryProvider);

    final tabController = useTabController(initialLength: 3);
    final isSearching = useState(false);
    final searchQuery = useState('');
    final searchController = useTextEditingController();

    final selectedIds = useState<Set<int>>({});
    final isSelecting = selectedIds.value.isNotEmpty;

    return notificationsAsync.when(
      loading: () => Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(title: const Text('Notifications')),
        body: const AppLoading(),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (allNotifications) {
        // Filter by search query if active
        final filteredNotifications = searchQuery.value.trim().isEmpty
            ? allNotifications
            : allNotifications.where((n) {
                final q = searchQuery.value.toLowerCase();
                return n.title.toLowerCase().contains(q) ||
                    n.body.toLowerCase().contains(q);
              }).toList();

        final unreadNotifications = filteredNotifications
            .where((n) => !n.isRead)
            .toList();

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            leading: isSelecting
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => selectedIds.value = {},
                  )
                : (isSearching.value
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            isSearching.value = false;
                            searchQuery.value = '';
                            searchController.clear();
                          },
                        )
                      : null),
            title: isSelecting
                ? Text('${selectedIds.value.length} selected')
                : (isSearching.value
                      ? TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search updates...',
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => searchQuery.value = val,
                        )
                      : const Text(
                          'Notifications',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )),
            bottom: isSelecting
                ? null
                : TabBar(
                    controller: tabController,
                    tabs: [
                      Tab(text: 'All (${filteredNotifications.length})'),
                      Tab(text: 'Unread (${unreadNotifications.length})'),
                      const Tab(text: 'By Novel'),
                    ],
                  ),
            actions: isSelecting
                ? [
                    IconButton(
                      icon: const Icon(Icons.select_all_rounded),
                      tooltip: 'Select All',
                      onPressed: () {
                        selectedIds.value = filteredNotifications
                            .map((n) => n.id)
                            .toSet();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.mark_email_read_outlined),
                      tooltip: 'Mark Selected Read',
                      onPressed: () async {
                        await UpdateNotificationService.instance
                            .markMultipleAsRead(selectedIds.value);
                        selectedIds.value = {};
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Delete Selected',
                      onPressed: () async {
                        await UpdateNotificationService.instance.deleteMultiple(
                          selectedIds.value,
                        );
                        selectedIds.value = {};
                      },
                    ),
                  ]
                : [
                    if (!isSearching.value)
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'Search',
                        onPressed: () => isSearching.value = true,
                      ),
                    if (allNotifications.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (value) async {
                          if (value == 'mark_all_read') {
                            await UpdateNotificationService.instance
                                .markAllAsRead();
                          } else if (value == 'clear_all') {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Clear all notifications?'),
                                content: const Text(
                                  'This will remove all notification history.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await UpdateNotificationService.instance
                                  .clearAll();
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'mark_all_read',
                            child: Row(
                              children: [
                                Icon(Icons.done_all_rounded, size: 20),
                                SizedBox(width: 12),
                                Text('Mark all as read'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'clear_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Clear all history'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
          ),
          body: TabBarView(
            controller: tabController,
            children: [
              // Tab 1: All Notifications
              _buildNotificationList(
                context,
                filteredNotifications,
                selectedIds,
                isSelecting,
                colorScheme,
                theme,
                'No notifications found',
              ),

              // Tab 2: Unread Notifications
              _buildNotificationList(
                context,
                unreadNotifications,
                selectedIds,
                isSelecting,
                colorScheme,
                theme,
                'No unread notifications',
              ),

              // Tab 3: Grouped by Novel
              _buildGroupedByNovelList(
                context,
                filteredNotifications,
                selectedIds,
                isSelecting,
                colorScheme,
                theme,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    List<NotificationEntry> notifications,
    ValueNotifier<Set<int>> selectedIds,
    bool isSelecting,
    ColorScheme colorScheme,
    ThemeData theme,
    String emptyMessage,
  ) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              emptyMessage,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'New chapter alerts will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = notifications[index];
        return _NotificationTile(
          item: item,
          isSelecting: isSelecting,
          isSelected: selectedIds.value.contains(item.id),
          onSelect: () {
            final next = Set<int>.from(selectedIds.value);
            if (next.contains(item.id)) {
              next.remove(item.id);
            } else {
              next.add(item.id);
            }
            selectedIds.value = next;
          },
          onLongPress: () {
            if (!isSelecting) {
              selectedIds.value = {item.id};
            }
          },
        );
      },
    );
  }

  Widget _buildGroupedByNovelList(
    BuildContext context,
    List<NotificationEntry> notifications,
    ValueNotifier<Set<int>> selectedIds,
    bool isSelecting,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    if (notifications.isEmpty) {
      return Center(
        child: Text(
          'No notifications yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final groups = <String, List<NotificationEntry>>{};
    for (final n in notifications) {
      final key = n.bookId ?? 'System & Diagnostics';
      groups.putIfAbsent(key, () => []).add(n);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: groups.keys.length,
      itemBuilder: (context, index) {
        final bookId = groups.keys.elementAt(index);
        final items = groups[bookId]!;
        final novelTitle = items.first.title.split(' has new chapters').first;
        final unreadCount = items.where((n) => !n.isRead).length;

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: CircleAvatar(
              backgroundColor: unreadCount > 0
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.auto_stories_rounded,
                color: unreadCount > 0
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            title: Text(
              novelTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${items.length} update${items.length == 1 ? '' : 's'}${unreadCount > 0 ? ' • $unreadCount unread' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: unreadCount > 0
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
            ),
            trailing: unreadCount > 0
                ? TextButton(
                    onPressed: () async {
                      if (bookId != 'System & Diagnostics') {
                        await UpdateNotificationService.instance
                            .markNovelAsRead(bookId);
                      }
                    },
                    child: const Text('Mark read'),
                  )
                : null,
            children: items.map((item) {
              return _NotificationTile(
                item: item,
                isSelecting: isSelecting,
                isSelected: selectedIds.value.contains(item.id),
                onSelect: () {
                  final next = Set<int>.from(selectedIds.value);
                  if (next.contains(item.id)) {
                    next.remove(item.id);
                  } else {
                    next.add(item.id);
                  }
                  selectedIds.value = next;
                },
                onLongPress: () {
                  if (!isSelecting) {
                    selectedIds.value = {item.id};
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isSelecting,
    required this.isSelected,
    required this.onSelect,
    required this.onLongPress,
  });

  final NotificationEntry item;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeAgo = _formatTimeAgo(item.createdAt);

    return Dismissible(
      key: ValueKey(item.id),
      direction: isSelecting
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await UpdateNotificationService.instance.delete(item.id);
      },
      child: ListTile(
        onLongPress: onLongPress,
        onTap: () async {
          if (isSelecting) {
            onSelect();
            return;
          }
          if (!item.isRead) {
            await UpdateNotificationService.instance.markAsRead(item.id);
          }
          final payload = item.payload;
          if (payload != null && context.mounted) {
            await context.push(payload);
          }
        },
        leading: isSelecting
            ? Checkbox(value: isSelected, onChanged: (_) => onSelect())
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.isRead
                      ? colorScheme.surfaceContainerLow
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.bookId != null
                      ? Icons.auto_stories_rounded
                      : Icons.notifications_rounded,
                  size: 22,
                  color: item.isRead
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
              ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.normal : FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              item.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: item.isRead
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
            ),
            if (item.bookId != null && !isSelecting) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      if (!item.isRead) {
                        await UpdateNotificationService.instance.markAsRead(
                          item.id,
                        );
                      }
                      if (context.mounted) {
                        await context.push('/reader/${item.bookId}');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chrome_reader_mode_outlined,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Read Now',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeAgo,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }
}
