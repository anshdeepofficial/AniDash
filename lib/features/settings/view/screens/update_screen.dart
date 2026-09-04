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

    // Parse release notes into bullet points
    final lines = updateInfo.releaseNotes
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) {
          if (l.startsWith('- ') || l.startsWith('* ')) {
            return l.substring(2).trim();
          }
          return l;
        })
        .where((l) => l.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isDownloading = false;
        double progress = 0.0;
        int receivedBytes = 0;
        int totalBytes = 0;
        String? downloadError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Iconsax.refresh_circle,
                            color: colorScheme.onPrimaryContainer,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Available',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'AniDash v${updateInfo.version}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      'What\'s New:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: lines.isNotEmpty ? lines.length : 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (lines.isEmpty) {
                              return Text(
                                updateInfo.releaseNotes,
                                style: theme.textTheme.bodySmall,
                              );
                            }
                            final item = lines[index];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4, right: 10),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isDownloading) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Downloading AniDash v${updateInfo.version}...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : null,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (totalBytes > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (downloadError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          downloadError!,
                          style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isDownloading
                                ? null
                                : () {
                                    ref.read(updateSettingsProvider.notifier).updateSettings(
                                          (state) => state.copyWith(
                                            skippedVersion: updateInfo.version,
                                          ),
                                        );
                                    Navigator.pop(context);
                                  },
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: isDownloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 20),
                            label: Text(
                              isDownloading ? 'Downloading...' : 'Download & Install',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: isDownloading
                                ? null
                                : () async {
                                    setModalState(() {
                                      isDownloading = true;
                                      downloadError = null;
                                      progress = 0.0;
                                    });

                                    try {
                                      await _updateService.downloadAndInstallUpdate(
                                        updateInfo.downloadUrl,
                                        onProgress: (received, total) {
                                          if (total > 0) {
                                            setModalState(() {
                                              receivedBytes = received;
                                              totalBytes = total;
                                              progress = (received / total).clamp(0.0, 1.0);
                                            });
                                          }
                                        },
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        isDownloading = false;
                                        downloadError = 'Download failed: $e';
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
