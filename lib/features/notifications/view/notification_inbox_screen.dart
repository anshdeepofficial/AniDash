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
  late Future<List<InboxNotification>> _items = _service.load();

  void _reload() => setState(() => _items = _service.load());

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
              _reload();
            },
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Clear inbox',
            onPressed: () async {
              await _service.clear();
              _reload();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<InboxNotification>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
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
                  leading: Icon(
                    item.isRead
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded,
                    color:
                        item.isRead
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight:
                          item.isRead ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(item.body),
                  onTap: () async {
                    await _service.markRead(item.id);
                    if (!context.mounted) return;
                    if (item.route?.isNotEmpty == true) {
                      context.push(item.route!);
                    } else {
                      _reload();
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
