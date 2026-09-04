import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/models/settings/update_settings_model.dart';
import 'package:ani_dash/main.dart'; 

final updateSettingsProvider =
    NotifierProvider<UpdateSettingsNotifier, UpdateSettingsModel>(
      UpdateSettingsNotifier.new,
    );

class UpdateSettingsNotifier extends Notifier<UpdateSettingsModel> {
  static const _prefsKey = 'update_settings_data';

  @override
  UpdateSettingsModel build() {
    final jsonString = sharedPrefs.getString(_prefsKey);
    if (jsonString != null) {
      return UpdateSettingsModel.fromJson(jsonString);
    }
    return const UpdateSettingsModel();
  }

  void updateSettings(UpdateSettingsModel Function(UpdateSettingsModel) updater) {
    state = updater(state);
    sharedPrefs.setString(_prefsKey, state.toJson());
  }
}
