import 'dart:io';

import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/utils/env_loader.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class RemotePushService {
  RemotePushService._();

  static bool _initialized = false;

  static bool get isConfigured => ONESIGNAL_APP_ID.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid || !isConfigured) return;
    try {
      OneSignal.initialize(ONESIGNAL_APP_ID.trim());
      OneSignal.Notifications.addClickListener((event) {
        final route = event.notification.additionalData?['route']?.toString();
        if (route != null) NotificationService().openRoute(route);
      });
      final package = await PackageInfo.fromPlatform();
      await OneSignal.User.addTags({
        'platform': 'android',
        'app_version': package.version,
        'build_number': package.buildNumber,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      });
      _initialized = true;
      AppLogger.success('OneSignal remote push initialized');
    } catch (error, stackTrace) {
      AppLogger.e('OneSignal initialization failed', error, stackTrace);
    }
  }

  static Future<bool> requestPermission() async {
    if (!isConfigured || !Platform.isAndroid) return false;
    await initialize();
    return OneSignal.Notifications.requestPermission(true);
  }

  static Future<void> identifyAniListUser(String? userId) async {
    if (!isConfigured || !Platform.isAndroid) return;
    await initialize();
    if (userId == null || userId.trim().isEmpty) {
      await OneSignal.logout();
      return;
    }
    await OneSignal.login('anilist:${userId.trim()}');
    await OneSignal.User.addTagWithKey('anilist_id', userId.trim());
  }
}
