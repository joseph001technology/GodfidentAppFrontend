import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/notification.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Mark all read', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () => ref.read(notificationsProvider.notifier).load(),
        child: notifsAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(notificationsProvider.notifier).load(),
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const EmptyView(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications',
                subtitle: 'You\'re all caught up!',
              );
            }
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.navyOutline),
              itemBuilder: (_, i) => _NotificationTile(notification: notifications[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification.notificationType) {
      case 'devotional': return Icons.book_outlined;
      case 'reading_reminder': return Icons.menu_book_outlined;
      case 'prayer_reminder': return Icons.volunteer_activism_outlined;
      case 'streak': return Icons.local_fire_department;
      case 'plan_complete': return Icons.check_circle_outline;
      default: return Icons.notifications_outlined;
    }
  }

  Color get _color {
    switch (notification.notificationType) {
      case 'devotional': return Colors.amber;
      case 'reading_reminder': return AppTheme.gold;
      case 'prayer_reminder': return Colors.pink;
      case 'streak': return Colors.orange;
      case 'plan_complete': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _timeAgo(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationsProvider.notifier).markRead(notification.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: notification.isRead ? Colors.transparent : _color,
              width: 3,
            ),
          ),
          color: notification.isRead ? Colors.transparent : _color.withOpacity(0.05),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 18),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(_timeAgo(notification.createdAt),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
