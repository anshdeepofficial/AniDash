import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ani_dash/core/services/notification_inbox_service.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final _service = NotificationInboxService();

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            onPressed: () async {
              await _service.markAllRead();
            },
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Clear inbox',
            onPressed: () async {
              await _service.clear();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<InboxNotification>>(
        valueListenable: _service.itemsNotifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        item.isRead
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_active_rounded,
                        color:
                            item.isRead
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.primary,
                      ),
                      if (!item.isRead)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight:
                          item.isRead ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(item.body),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete notification',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () async {
                      await _service.delete(item.id);
                    },
                  ),
                  onTap: () async {
                    await _service.markRead(item.id);
                    if (!context.mounted) return;
                    if (item.route?.isNotEmpty == true) {
                      await context.push(item.route!);
                      if (context.mounted) {
                        _service.load();
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
