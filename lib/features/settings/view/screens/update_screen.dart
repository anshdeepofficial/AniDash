import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:ani_dash/shared/providers/settings/update_settings_notifier.dart';
import 'package:ani_dash/core/services/update_service.dart';

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

    final updateInfo = await _updateService.checkForUpdate();

    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });

    if (updateInfo != null) {
      _showUpdateDialog(updateInfo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are on the latest version!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Iconsax.refresh_circle, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Update: v${updateInfo.version}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Release Notes:',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  updateInfo.releaseNotes,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(updateSettingsProvider.notifier).updateSettings(
                    (state) => state.copyWith(skippedVersion: updateInfo.version),
                  );
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download & Install'),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downloading update in background...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _updateService.downloadAndInstallUpdate(updateInfo.downloadUrl);
            },
          ),
        ],
      ),
    );
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
