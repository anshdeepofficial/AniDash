import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
        const SnackBar(content: Text('No updates available')),
      );
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Available: ${updateInfo.version}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(updateInfo.releaseNotes),
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
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading update...')),
              );
              _updateService.downloadAndInstallUpdate(updateInfo.downloadUrl);
            },
            child: const Text('Download & Install'),
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
        title: const Text('Updates'),
      ),
      body: ListView(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? 'Loading...';
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Iconsax.info_circle, color: colorScheme.primary),
                ),
                title: const Text('Current Version'),
                subtitle: Text(version),
                trailing: _isChecking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonal(
                        onPressed: _checkForUpdate,
                        child: const Text('Check for Updates'),
                      ),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Auto-Check for Updates'),
            value: settings.autoCheckEnabled,
            onChanged: (value) {
              notifier.updateSettings((state) => state.copyWith(autoCheckEnabled: value));
            },
            secondary: const Icon(Iconsax.refresh),
          ),
          if (settings.autoCheckEnabled) ...[
            ListTile(
              leading: const Icon(Iconsax.timer),
              title: const Text('Check Interval'),
              subtitle: Slider(
                value: settings.checkIntervalMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                label: '${settings.checkIntervalMinutes} min',
                onChanged: (value) {
                  notifier.updateSettings(
                    (state) => state.copyWith(checkIntervalMinutes: value.toInt()),
                  );
                },
              ),
              trailing: Text('${settings.checkIntervalMinutes}m'),
            ),
            ListTile(
              leading: const Icon(Iconsax.clock),
              title: const Text('Auto-Check Start Hour'),
              subtitle: Text('${settings.startHour}:00'),
              trailing: const Icon(Iconsax.edit),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: settings.startHour, minute: 0),
                );
                if (time != null) {
                  notifier.updateSettings((state) => state.copyWith(startHour: time.hour));
                }
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.clock),
              title: const Text('Auto-Check End Hour'),
              subtitle: Text('${settings.endHour}:00'),
              trailing: const Icon(Iconsax.edit),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: settings.endHour, minute: 0),
                );
                if (time != null) {
                  notifier.updateSettings((state) => state.copyWith(endHour: time.hour));
                }
              },
            ),
          ]
        ],
      ),
    );
  }
}
