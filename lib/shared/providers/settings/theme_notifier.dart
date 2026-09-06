import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:ani_dash/core/models/settings/theme_model.dart';
import 'package:ani_dash/main.dart';

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeModel>(
      ThemeSettingsNotifier.new,
    );

class ThemeSettingsNotifier extends Notifier<ThemeModel> {
  static const _launcherIconChannel = MethodChannel('anidash/launcher_icon');
  static const _boxName = 'theme_settings';
  static const _hiveKey = 'settings';
  static const _prefsKey = 'theme_settings_data';

  @override
  ThemeModel build() {
    final jsonString = sharedPrefs.getString(_prefsKey);
    if (jsonString != null) {
      final settings = ThemeModel.fromJson(jsonString);
      _syncLauncherIcon(settings.logoMode);
      return settings;
    }

    if (Hive.isBoxOpen(_boxName)) {
      try {
        final box = Hive.box<ThemeModel>(_boxName);
        final oldSettings = box.get(_hiveKey);
        if (oldSettings != null) {
          sharedPrefs.setString(_prefsKey, oldSettings.toJson());
          _syncLauncherIcon(oldSettings.logoMode);
          return oldSettings;
        }
      } catch (_) {}
    }

    final settings = ThemeModel();
    _syncLauncherIcon(settings.logoMode);
    return settings;
  }

  void updateSettings(ThemeModel Function(ThemeModel) updater) {
    state = updater(state);
    sharedPrefs.setString(_prefsKey, state.toJson());
    _syncLauncherIcon(state.logoMode);
  }

  void _syncLauncherIcon(String mode) {
    if (!Platform.isAndroid) return;
    unawaited(
      _launcherIconChannel.invokeMethod<void>('setMode', {'mode': mode}),
    );
  }
}
