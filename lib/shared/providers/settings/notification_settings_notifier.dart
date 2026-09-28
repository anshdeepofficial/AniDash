import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/models/settings/notification_settings_model.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/main.dart';

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsModel>(
      NotificationSettingsNotifier.new,
    );

class NotificationSettingsNotifier extends Notifier<NotificationSettingsModel> {
  static const _prefsKey = 'notification_settings_data';

  @override
  NotificationSettingsModel build() {
    final jsonString = sharedPrefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        return NotificationSettingsModel.fromJson(map);
      } catch (_) {}
    }
    return const NotificationSettingsModel();
  }

  Future<void> updateSettings(
    NotificationSettingsModel Function(NotificationSettingsModel) updater,
  ) async {
    state = updater(state);
    await sharedPrefs.setString(_prefsKey, jsonEncode(state.toJson()));
    await NotificationService().reconcileScheduledReleaseAlerts();
    await NotificationService().registerPeriodicNotificationWorker();
  }
}
