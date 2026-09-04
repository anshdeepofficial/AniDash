import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:ani_dash/shared/providers/settings/update_settings_notifier.dart';
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
    final currentVersion = '${packageInfo.version}-${packageInfo.buildNumber}';
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
                  final buildNumber = snapshot.data?.buildNumber ?? '';
                  return NormalSettingsItem(
                    icon: Icon(Iconsax.info_circle, color: colorScheme.primary),
                    accent: colorScheme.primary,
                    title: 'Current Version',
                    description: 'v$version ($buildNumber)',
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
                NormalSettingsItem(
                  icon: Icon(Iconsax.clock, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Auto-Check Start Hour',
                  description: '${settings.startHour.toString().padLeft(2, '0')}:00',
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay(hour: settings.startHour, minute: 0),
                    );
                    if (time != null) {
                      notifier.updateSettings(
                        (state) => state.copyWith(startHour: time.hour),
                      );
                    }
                  },
                ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.clock, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Auto-Check End Hour',
                  description: '${settings.endHour.toString().padLeft(2, '0')}:00',
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay(hour: settings.endHour, minute: 0),
                    );
                    if (time != null) {
                      notifier.updateSettings(
                        (state) => state.copyWith(endHour: time.hour),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
