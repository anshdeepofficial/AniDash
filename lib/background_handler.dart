import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/services/update_scheduler.dart';
import 'package:ani_dash/core/models/settings/update_settings_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/tasks/news_task.dart';
import 'package:ani_dash/core/tasks/episode_release_task.dart';
import 'package:ani_dash/core/tasks/sync_tracking_task.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == updateCheckTask || task == '${updateCheckTask}_immediate') {
      return await _checkForAppUpdate(inputData);
    }
    if (task == "sync_tracking_task") {
      return await SyncTrackingTask.performSync(inputData);
    }
    if (task == NotificationService.notificationCheckTask) {
      await EpisodeReleaseTask.performCheck();
      return await NewsBackgroundTask.performUpdate();
    }
    await EpisodeReleaseTask.performCheck();
    return await NewsBackgroundTask.performUpdate();
  });
}

Future<bool> _checkForAppUpdate(Map<String, dynamic>? inputData) async {
  try {
    final now = DateTime.now();
    final preferences = await SharedPreferences.getInstance();

    // Check user settings from SharedPreferences
    final jsonString = preferences.getString('update_settings_data');
    final settings = jsonString != null
        ? UpdateSettingsModel.fromJson(jsonString)
        : UpdateSettingsModel(
            fullDay: inputData?['fullDay'] as bool? ?? true,
            startHour: inputData?['startHour'] as int? ?? 20,
            endHour: inputData?['endHour'] as int? ?? 6,
          );

    if (!settings.autoCheckEnabled) return true;

    // Strict window check: only check if 24h mode is ON or current time is inside custom window
    if (!UpdateScheduler.isInsideWindow(settings, now)) {
      return true;
    }

    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/anshdeepofficial/AniDash/releases/latest',
      ),
      headers: const {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'AniDash',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return false;

    final release = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = (release['tag_name'] as String? ?? '').replaceFirst('v', '').trim();
    if (latest.isEmpty) return true;

    String current;
    try {
      final info = await PackageInfo.fromPlatform();
      current = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
    } catch (_) {
      current = preferences.getString('app_version') ?? '1.0.0';
    }
    if (!_newer(latest, current)) return true;

    // Check if user snoozed this specific release ("Remind in 1 hour" or "Skip for today")
    final remindAfter = preferences.getInt('remind_update_after') ?? 0;
    final remindVersion = preferences.getString('remind_update_version');
    if (remindVersion == latest && now.millisecondsSinceEpoch < remindAfter) {
      return true;
    }
    final isExplicitReminderDue =
        remindVersion == latest &&
        remindAfter > 0 &&
        now.millisecondsSinceEpoch >= remindAfter;
    final lastNotifiedVersion = preferences.getString('last_notified_update');
    final lastNotifiedAt = preferences.getInt('last_notified_update_time') ?? 0;
    if (!isExplicitReminderDue &&
        lastNotifiedVersion == latest &&
        now.millisecondsSinceEpoch - lastNotifiedAt <
            const Duration(hours: 24).inMilliseconds) {
      return true;
    }

    final notifications = NotificationService();
    await notifications.initialize(isBackground: true);
    await notifications.showUpdateAvailableNotification(latest);
    await preferences.setString('last_notified_update', latest);
    await preferences.setInt('last_notified_update_time', now.millisecondsSinceEpoch);
    if (remindAfter != 0 && now.millisecondsSinceEpoch >= remindAfter) {
      await preferences.remove('remind_update_after');
      await preferences.remove('remind_update_version');
    }
    return true;
  } catch (e, st) {
    AppLogger.e('Background update check failed: $e', e, st);
    return false;
  }
}

bool _newer(String latest, String current) {
  final cleanLatest =
      latest
          .replaceAll(RegExp(r'^v'), '')
          .split('+')
          .first
          .split('-')
          .first
          .trim();
  final cleanCurrent =
      current
          .replaceAll(RegExp(r'^v'), '')
          .split('+')
          .first
          .split('-')
          .first
          .trim();

  final left =
      cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final right =
      cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (left.length < 3) {
    left.add(0);
  }
  while (right.length < 3) {
    right.add(0);
  }

  for (var i = 0; i < 3; i++) {
    if (left[i] > right[i]) return true;
    if (left[i] < right[i]) return false;
  }

  int getBuild(String s) {
    if (s.contains('+')) return int.tryParse(s.split('+').last) ?? 0;
    if (s.contains('-')) return int.tryParse(s.split('-').last) ?? 0;
    return 0;
  }

  final lBuild = getBuild(latest);
  final cBuild = getBuild(current);
  if (lBuild > 0 && cBuild > 0) {
    return lBuild > cBuild;
  }
  return false;
}
