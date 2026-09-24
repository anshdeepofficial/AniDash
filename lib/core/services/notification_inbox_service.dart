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
    this.notificationType,
    this.mediaId,
    this.episodeNumber,
    this.language,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? route;
  final bool isRead;
  final String? notificationType;
  final String? mediaId;
  final int? episodeNumber;
  final String? language;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'route': route,
    'isRead': isRead,
    'notificationType': notificationType,
    'mediaId': mediaId,
    'episodeNumber': episodeNumber,
    'language': language,
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
      notificationType: json['notificationType']?.toString(),
      mediaId: json['mediaId']?.toString(),
      episodeNumber: (json['episodeNumber'] as num?)?.toInt(),
      language: json['language']?.toString(),
    );
  }
  InboxNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    String? route,
    bool? isRead,
    String? notificationType,
    String? mediaId,
    int? episodeNumber,
    String? language,
  }) {
    return InboxNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      route: route ?? this.route,
      isRead: isRead ?? this.isRead,
      notificationType: notificationType ?? this.notificationType,
      mediaId: mediaId ?? this.mediaId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      language: language ?? this.language,
    );
  }
}

class NotificationInboxService {
  static const _key = 'notification_inbox_v1';
  static const _maxItems = 100;

  Future<List<InboxNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
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
      return [];
    }
  }

  Future<int> unreadCount() async =>
      (await load()).where((item) => !item.isRead).length;

  Future<void> add({
    required String title,
    required String body,
    String? route,
    String? dedupeKey,
    String? notificationType,
    String? mediaId,
    int? episodeNumber,
    String? language,
  }) async {
    final items = (await load()).toList();
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
        notificationType: notificationType,
        mediaId: mediaId,
        episodeNumber: episodeNumber,
        language: language,
      ),
    );
    await _save(items.take(_maxItems).toList());
  }

  Future<void> markRead(String id) async {
    final items = (await load()).toList();
    await _save([
      for (final item in items)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ]);
  }

  Future<void> delete(String id) async {
    final items = (await load()).toList();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> markAllRead() async {
    final items = (await load()).toList();
    await _save([
      for (final item in items) item.copyWith(isRead: true),
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
