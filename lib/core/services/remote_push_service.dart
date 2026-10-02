import 'dart:io';

import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/utils/env_loader.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      _initialized = true;
      await _updateActivityTags();
      AppLogger.success('OneSignal remote push initialized');
    } catch (error, stackTrace) {
      AppLogger.e('OneSignal initialization failed', error, stackTrace);
    }
  }

  /// Refreshes anonymous aggregate activity after app resume or reconnect.
  static Future<void> refreshActivity() async {
    if (!Platform.isAndroid || !isConfigured) return;
    await initialize();
    if (!_initialized) return;
    try {
      await _updateActivityTags();
    } catch (error, stackTrace) {
      AppLogger.e('Unable to refresh anonymous activity', error, stackTrace);
    }
  }

  static Future<void> _updateActivityTags() async {
    final package = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final firstSeen =
        prefs.getString('anonymous_install_first_seen') ??
        now.toIso8601String();
    await prefs.setString('anonymous_install_first_seen', firstSeen);
    await OneSignal.User.addTags({
      'platform': 'android',
      'app_version': package.version,
      'build_number': package.buildNumber,
      'first_seen': firstSeen,
      'last_seen': now.toIso8601String(),
      'active_day': now.toIso8601String().substring(0, 10),
    });
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
