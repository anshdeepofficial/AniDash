import 'dart:io';

import 'package:workmanager/workmanager.dart';
import 'package:ani_dash/core/models/settings/update_settings_model.dart';

const updateCheckTask = 'anidash_update_check';

class UpdateScheduler {
  static Future<void> apply(UpdateSettingsModel settings) async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(updateCheckTask);
    if (!settings.autoCheckEnabled) return;

    final now = DateTime.now();
    final insideWindow =
        settings.startHour <= settings.endHour
            ? now.hour >= settings.startHour && now.hour < settings.endHour
            : now.hour >= settings.startHour || now.hour < settings.endHour;
    var firstRun =
        insideWindow
            ? now.add(const Duration(minutes: 1))
            : DateTime(now.year, now.month, now.day, settings.startHour);
    if (!insideWindow && !firstRun.isAfter(now)) {
      firstRun = firstRun.add(const Duration(days: 1));
    }

    await Workmanager().registerPeriodicTask(
      updateCheckTask,
      updateCheckTask,
      frequency: Duration(minutes: settings.checkIntervalMinutes.clamp(15, 60)),
      initialDelay: firstRun.difference(now),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {'startHour': settings.startHour, 'endHour': settings.endHour},
    );
  }
}
