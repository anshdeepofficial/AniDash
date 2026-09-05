import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/services/update_scheduler.dart';
import 'package:ani_dash/core/tasks/news_task.dart';
import 'package:ani_dash/core/tasks/episode_release_task.dart';
import 'package:ani_dash/core/tasks/sync_tracking_task.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == updateCheckTask) {
      return _checkForAppUpdate(inputData);
    }
    if (task == "sync_tracking_task") {
      return await SyncTrackingTask.performSync(inputData);
    }
    await EpisodeReleaseTask.performCheck();
    return await NewsBackgroundTask.performUpdate();
  });
}

Future<bool> _checkForAppUpdate(Map<String, dynamic>? inputData) async {
  try {
    final now = DateTime.now();
    final start = inputData?['startHour'] as int? ?? 20;
    final end = inputData?['endHour'] as int? ?? 6;
    final insideWindow =
        start <= end
            ? now.hour >= start && now.hour < end
            : now.hour >= start || now.hour < end;
    if (!insideWindow) return true;

    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/anshdeepofficial/AniDash/releases/latest',
      ),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'AniDash',
      },
    );
    if (response.statusCode != 200) return false;
    final release = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = (release['tag_name'] as String? ?? '').replaceFirst('v', '');
    final current = (await PackageInfo.fromPlatform()).version;
    if (!_newer(latest, current)) return true;

    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString('last_notified_update') == latest) return true;

    final notifications = NotificationService();
    await notifications.initialize();
    await notifications.showUpdateAvailableNotification(latest);
    await preferences.setString('last_notified_update', latest);
    return true;
  } catch (_) {
    return false;
  }
}

bool _newer(String latest, String current) {
  final left =
      latest
          .split('-')
          .first
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
  final right =
      current
          .split('-')
          .first
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
  for (var i = 0; i < 3; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l > r;
  }
  return false;
}
