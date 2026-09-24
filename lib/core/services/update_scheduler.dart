import 'dart:io';

import 'package:workmanager/workmanager.dart';
import 'package:ani_dash/core/models/settings/update_settings_model.dart';

const updateCheckTask = 'anidash_update_check';

class UpdateScheduler {
  static bool isInsideWindow(
    UpdateSettingsModel settings, [
    DateTime? dateTime,
  ]) {
    if (settings.fullDay) return true;
    final now = dateTime ?? DateTime.now();
    return settings.startHour <= settings.endHour
        ? now.hour >= settings.startHour && now.hour < settings.endHour
        : now.hour >= settings.startHour || now.hour < settings.endHour;
  }

  static Future<void> apply(
    UpdateSettingsModel settings, {
    bool forceReplace = false,
  }) async {
    if (!Platform.isAndroid) return;
    if (!settings.autoCheckEnabled) {
      await Workmanager().cancelByUniqueName(updateCheckTask);
      await Workmanager().cancelByUniqueName('${updateCheckTask}_immediate');
      return;
    }

    final now = DateTime.now();
    final insideWindow = isInsideWindow(settings, now);
    Duration initialDelay = Duration.zero;

    if (!insideWindow) {
      DateTime nextRun = DateTime(now.year, now.month, now.day, settings.startHour);
      if (nextRun.isBefore(now)) {
        nextRun = nextRun.add(const Duration(days: 1));
      }
      initialDelay = nextRun.difference(now);
    }

    await Workmanager().registerPeriodicTask(
      updateCheckTask,
      updateCheckTask,
      frequency: Duration(minutes: settings.checkIntervalMinutes.clamp(15, 60)),
      initialDelay: initialDelay,
      existingWorkPolicy:
          forceReplace ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {
        'startHour': settings.startHour,
        'endHour': settings.endHour,
        'fullDay': settings.fullDay,
      },
    );

    // Immediate one-off check so the user does not wait for first periodic execution
    if (insideWindow) {
      await Workmanager().registerOneOffTask(
        '${updateCheckTask}_immediate',
        updateCheckTask,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: {
          'startHour': settings.startHour,
          'endHour': settings.endHour,
          'fullDay': settings.fullDay,
        },
      );
    }
  }
}
