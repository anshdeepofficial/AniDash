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
    final soundId = sharedPrefs.getString('notification_sound_id') ?? 'anidash_biwa';
    return NotificationSettingsModel(soundId: soundId);
  }

  void updateSettings(
    NotificationSettingsModel Function(NotificationSettingsModel) updater,
  ) {
    state = updater(state);
    sharedPrefs.setString(_prefsKey, jsonEncode(state.toJson()));
    sharedPrefs.setString('notification_sound_id', state.soundId);
    NotificationService().ensureSoundChannelsCreated(state.soundId);
  }

  void setSound(String soundId) {
    updateSettings((s) => s.copyWith(soundId: soundId));
  }
}
