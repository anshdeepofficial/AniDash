import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? route;
  final bool isRead;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'route': route,
    'isRead': isRead,
  };

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    return InboxNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'AniDash',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      route: json['route']?.toString(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class NotificationInboxService {
  static const _key = 'notification_inbox_v1';
  static const _maxItems = 100;

  Future<List<InboxNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map(
            (item) =>
                InboxNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  Future<int> unreadCount() async =>
      (await load()).where((item) => !item.isRead).length;

  Future<void> add({
    required String title,
    required String body,
    String? route,
    String? dedupeKey,
  }) async {
    final items = await load();
    final id = dedupeKey ?? '${DateTime.now().microsecondsSinceEpoch}';
    items.removeWhere((item) => item.id == id);
    items.insert(
      0,
      InboxNotification(
        id: id,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        route: route,
      ),
    );
    await _save(items.take(_maxItems).toList());
  }

  Future<void> markRead(String id) async {
    final items = await load();
    await _save([
      for (final item in items)
        if (item.id == id)
          InboxNotification(
            id: item.id,
            title: item.title,
            body: item.body,
            createdAt: item.createdAt,
            route: item.route,
            isRead: true,
          )
        else
          item,
    ]);
  }

  Future<void> delete(String id) async {
    final items = await load();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> markAllRead() async {
    final items = await load();
    await _save([
      for (final item in items)
        InboxNotification(
          id: item.id,
          title: item.title,
          body: item.body,
          createdAt: item.createdAt,
          route: item.route,
          isRead: true,
        ),
    ]);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<InboxNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
