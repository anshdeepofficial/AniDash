import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/services/notification_service.dart';

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
    this.systemNotificationId,
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
  final int? systemNotificationId;

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
    'systemNotificationId': systemNotificationId,
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
      systemNotificationId: (json['systemNotificationId'] as num?)?.toInt(),
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
    int? systemNotificationId,
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
      systemNotificationId: systemNotificationId ?? this.systemNotificationId,
    );
  }
}

class NotificationInboxService {
  NotificationInboxService._internal() {
    unreadCount();
  }
  static final NotificationInboxService _instance =
      NotificationInboxService._internal();
  factory NotificationInboxService() => _instance;

  static const _key = 'notification_inbox_v1';
  static const _maxItems = 100;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<InboxNotification>> itemsNotifier =
      ValueNotifier<List<InboxNotification>>([]);

  Future<List<InboxNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      itemsNotifier.value = [];
      unreadCountNotifier.value = 0;
      return [];
    }
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map(
            (item) =>
                InboxNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      itemsNotifier.value = list;
      unreadCountNotifier.value = list.where((item) => !item.isRead).length;
      return list;
    } catch (_) {
      itemsNotifier.value = [];
      unreadCountNotifier.value = 0;
      return [];
    }
  }

  Future<int> unreadCount() async {
    final count = (await load()).where((item) => !item.isRead).length;
    unreadCountNotifier.value = count;
    return count;
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> add({
    required String title,
    required String body,
    String? route,
    String? dedupeKey,
    String? notificationType,
    String? mediaId,
    int? episodeNumber,
    String? language,
    int? systemNotificationId,
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
        systemNotificationId: systemNotificationId,
      ),
    );
    await _save(items.take(_maxItems).toList());
    await unreadCount();
  }

  Future<void> markRead(String id) async {
    final items = (await load()).toList();
    for (final item in items) {
      if (item.id == id && item.systemNotificationId != null) {
        try {
          await NotificationService().cancelNotification(item.systemNotificationId!);
        } catch (_) {}
      }
    }
    await _save([
      for (final item in items)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ]);
    await unreadCount();
  }

  Future<void> markReadByRouteOrMedia(String route, String? mediaId) async {
    final items = (await load()).toList();
    var changed = false;
    final updated = items.map((item) {
      final matchesRoute = item.route != null &&
          (item.route == route ||
              route.contains(item.route!) ||
              item.route!.contains(route));
      final matchesMedia = mediaId != null && item.mediaId == mediaId;
      if (!item.isRead && (matchesRoute || matchesMedia)) {
        changed = true;
        if (item.systemNotificationId != null) {
          try {
            NotificationService().cancelNotification(item.systemNotificationId!);
          } catch (_) {}
        }
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();

    if (changed) {
      await _save(updated);
      await unreadCount();
    }
  }

  Future<void> delete(String id) async {
    final items = (await load()).toList();
    for (final item in items) {
      if (item.id == id && item.systemNotificationId != null) {
        try {
          await NotificationService().cancelNotification(item.systemNotificationId!);
        } catch (_) {}
      }
    }
    items.removeWhere((item) => item.id == id);
    await _save(items);
    await unreadCount();
  }

  Future<void> markAllRead() async {
    try {
      await NotificationService().cancelAllNotifications();
    } catch (_) {}
    final items = (await load()).toList();
    await _save([
      for (final item in items) item.copyWith(isRead: true),
    ]);
    await unreadCount();
  }

  Future<void> clear() async {
    try {
      await NotificationService().cancelAllNotifications();
    } catch (_) {}
    itemsNotifier.value = [];
    unreadCountNotifier.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<InboxNotification> items) async {
    itemsNotifier.value = items;
    unreadCountNotifier.value = items.where((item) => !item.isRead).length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

final unreadNotificationCountProvider =
    NotifierProvider<UnreadNotificationCountNotifier, int>(
      UnreadNotificationCountNotifier.new,
    );

class UnreadNotificationCountNotifier extends Notifier<int> {
  VoidCallback? _listener;

  @override
  int build() {
    final service = NotificationInboxService();
    _listener = () {
      final val = service.unreadCountNotifier.value;
      if (state != val) {
        state = val;
      }
    };
    service.unreadCountNotifier.addListener(_listener!);
    ref.onDispose(() {
      if (_listener != null) {
        service.unreadCountNotifier.removeListener(_listener!);
      }
    });
    Future.microtask(() async {
      await service.load();
    });
    return service.unreadCountNotifier.value;
  }

  Future<void> refresh() async {
    final count = await NotificationInboxService().unreadCount();
    if (state != count) {
      state = count;
    }
  }
}
