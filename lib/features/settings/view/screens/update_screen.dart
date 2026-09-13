import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:ani_dash/shared/providers/settings/update_settings_notifier.dart';
import 'package:ani_dash/core/models/settings/update_settings_model.dart';
import 'package:ani_dash/core/services/update_service.dart';
import 'package:ani_dash/core/utils/updater.dart';

class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  final UpdateService _updateService = UpdateService();
  bool _isChecking = false;

  Future<void> _checkForUpdate() async {
    setState(() {
      _isChecking = true;
    });

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final updateInfo = await _updateService.checkForUpdate();

    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });

    if (updateInfo != null) {
      showUpdateBottomSheet(
        context,
        updateInfo.version,
        currentVersion,
        UpdateType.stable,
        releaseNotes: updateInfo.releaseNotes,
        apkDownloadUrl: updateInfo.downloadUrl,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are on the latest version!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(updateSettingsProvider);
    final notifier = ref.read(updateSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Check for Updates'),
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          SettingsSection(
            title: 'Version & Updates',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  return NormalSettingsItem(
                    icon: Icon(Iconsax.info_circle, color: colorScheme.primary),
                    accent: colorScheme.primary,
                    title: 'Current Version',
                    description: 'v$version',
                    trailingWidgets: [
                      if (_isChecking)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: _checkForUpdate,
                          child: const Text('Check Now'),
                        ),
                    ],
                    onTap: _isChecking ? null : _checkForUpdate,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SettingsSection(
            title: 'Auto-Check Schedule',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              ToggleableSettingsItem(
                icon: Icon(Iconsax.refresh, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Auto-Check for Updates',
                description: 'Periodically check GitHub releases for updates',
                value: settings.autoCheckEnabled,
                onChanged: (value) {
                  notifier.updateSettings(
                    (state) => state.copyWith(autoCheckEnabled: value),
                  );
                },
              ),
              if (settings.autoCheckEnabled) ...[
                ToggleableSettingsItem(
                  icon: Icon(Iconsax.clock, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Run 24 Hours',
                  description: settings.fullDay
                      ? 'Continuously checking round the clock (Custom window disabled)'
                      : 'Continuously check for updates round the clock',
                  value: settings.fullDay,
                  onChanged: (value) {
                    notifier.updateSettings(
                      (state) => state.copyWith(
                        fullDay: value,
                        startHour: state.startHour == state.endHour ? 20 : state.startHour,
                        endHour: state.startHour == state.endHour ? 6 : state.endHour,
                      ),
                    );
                  },
                ),
                SliderSettingsItem(
                  icon: Icon(Iconsax.timer, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Check Interval',
                  description:
                      'Check every ${settings.checkIntervalMinutes} minutes',
                  value: settings.checkIntervalMinutes.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  onChanged: (value) {
                    notifier.updateSettings(
                      (state) =>
                          state.copyWith(checkIntervalMinutes: value.toInt()),
                    );
                  },
                ),
                _buildCustomTimeItem(
                  context: context,
                  colorScheme: colorScheme,
                  title: 'Custom Window: Start Hour',
                  hour: settings.startHour,
                  is24HourMode: settings.fullDay,
                  onTap: () => _pickStartHour(context, settings, notifier),
                ),
                _buildCustomTimeItem(
                  context: context,
                  colorScheme: colorScheme,
                  title: 'Custom Window: End Hour',
                  hour: settings.endHour,
                  is24HourMode: settings.fullDay,
                  onTap: () => _pickEndHour(context, settings, notifier),
                ),
              ],
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:00 $period (${hour.toString().padLeft(2, '0')}:00)';
  }

  Widget _buildCustomTimeItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String title,
    required int hour,
    required bool is24HourMode,
    required VoidCallback? onTap,
  }) {
    final timeStr = _formatHour(hour);
    final desc = is24HourMode ? '$timeStr • Disabled in 24-Hour mode' : timeStr;

    return Opacity(
      opacity: is24HourMode ? 0.45 : 1.0,
      child: IgnorePointer(
        ignoring: is24HourMode,
        child: NormalSettingsItem(
          icon: Icon(
            Iconsax.clock,
            color: is24HourMode ? Colors.grey : colorScheme.primary,
          ),
          accent: is24HourMode ? Colors.grey : colorScheme.primary,
          title: title,
          description: desc,
          onTap: is24HourMode ? null : onTap,
        ),
      ),
    );
  }

  Future<void> _pickStartHour(
    BuildContext context,
    UpdateSettingsModel settings,
    UpdateSettingsNotifier notifier,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.startHour, minute: 0),
      helpText: 'SELECT AUTO-CHECK START HOUR',
    );
    if (time == null || !context.mounted) return;

    if (time.hour == settings.endHour) {
      // User selected 24-hour window: automatically switch to 24-hour mode and keep 8 PM - 6 AM
      notifier.updateSettings(
        (state) => state.copyWith(
          fullDay: true,
          startHour: 20,
          endHour: 6,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '24-Hour schedule selected. Switched to 24-Hour Checking mode.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      notifier.updateSettings(
        (state) => state.copyWith(startHour: time.hour, fullDay: false),
      );
    }
  }

  Future<void> _pickEndHour(
    BuildContext context,
    UpdateSettingsModel settings,
    UpdateSettingsNotifier notifier,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.endHour, minute: 0),
      helpText: 'SELECT AUTO-CHECK END HOUR',
    );
    if (time == null || !context.mounted) return;

    if (time.hour == settings.startHour) {
      // User selected 24-hour window: automatically switch to 24-hour mode and keep 8 PM - 6 AM
      notifier.updateSettings(
        (state) => state.copyWith(
          fullDay: true,
          startHour: 20,
          endHour: 6,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '24-Hour schedule selected. Switched to 24-Hour Checking mode.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      notifier.updateSettings(
        (state) => state.copyWith(endHour: time.hour, fullDay: false),
      );
    }
  }
}
