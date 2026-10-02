import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/shared/providers/anilist_service_provider.dart';
import 'package:ani_dash/shared/providers/mal_service_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/shared/auth/providers/auth_notifier.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:ani_dash/shared/providers/settings/sync_settings_notifier.dart';
import 'package:ani_dash/core/models/universal/universal_media_list_entry.dart';

class TrackingSettingsScreen extends ConsumerStatefulWidget {
  const TrackingSettingsScreen({super.key});

  @override
  ConsumerState<TrackingSettingsScreen> createState() =>
      _TrackingSettingsScreenState();
}

class _TrackingSettingsScreenState
    extends ConsumerState<TrackingSettingsScreen> {
  bool _isSyncing = false;
  String? _migrationProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final syncSettings = ref.watch(syncSettingsProvider);
    final syncNotifier = ref.read(syncSettingsProvider.notifier);
    final auth = ref.watch(authProvider);

    final isAnilistLoggedIn = auth.isAniListAuthenticated;
    final isMalLoggedIn = auth.isMalAuthenticated;

    final noSyncTargets = !syncNotifier.hasAnySyncTarget;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Sync & Tracking'),
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsSection(
            title: 'Sync Services',
            titleColor: colorScheme.primary,
            children: [
              ToggleableSettingsItem(
                icon: Icon(Iconsax.archive_book, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'AniList',
                description:
                    isAnilistLoggedIn
                        ? 'Sync progress with AniList'
                        : 'Log in to enable AniList sync',
                value: syncSettings.syncAnilist && isAnilistLoggedIn,
                onChanged: (val) {
                  if (!isAnilistLoggedIn) return;
                  ref
                      .read(syncSettingsProvider.notifier)
                      .updateSettings((s) => s.copyWith(syncAnilist: val));
                },
              ),

              ToggleableSettingsItem(
                icon: Icon(Iconsax.archive_book, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'MyAnimeList',
                description:
                    isMalLoggedIn
                        ? 'Sync anime progress with MyAnimeList'
                        : 'Log in to enable MyAnimeList sync',
                value: syncSettings.syncMal && isMalLoggedIn,
                onChanged: (val) {
                  if (!isMalLoggedIn) return;
                  ref
                      .read(syncSettingsProvider.notifier)
                      .updateSettings((s) => s.copyWith(syncMal: val));
                },
              ),

              ToggleableSettingsItem(
                icon: Icon(Iconsax.mobile, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Local Sync',
                description: 'Store watchlist & progress on device',
                value: syncSettings.localSync,
                onChanged:
                    (val) => ref
                        .read(syncSettingsProvider.notifier)
                        .updateSettings((s) => s.copyWith(localSync: val)),
              ),
            ],
          ),

          if (noSyncTargets) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No sync targets enabled. Progress will not be tracked anywhere.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          SettingsSection(
            title: 'Sync Mode',
            titleColor: colorScheme.primary,
            children: [
              SegmentedToggleSettingsItem<String>(
                icon: Icon(Iconsax.timer_1, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Sync Strategy',
                description: _syncModeDescription(syncSettings.syncMode),
                selectedValue: syncSettings.syncMode,
                children: const {
                  'realtime': Text('Real-Time'),
                  'background': Text('Background'),
                },
                onValueChanged: (dynamic val) {
                  ref
                      .read(syncSettingsProvider.notifier)
                      .updateSettings((s) => s.copyWith(syncMode: val));
                },
              ),
              if (syncSettings.syncMode == 'background')
                DropdownSettingsItem(
                  icon: Icon(Iconsax.clock, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Sync Interval',
                  description: 'How often to sync in the background',
                  value: syncSettings.backgroundIntervalMinutes.toString(),
                  items: const [
                    DropdownMenuItem(value: '15', child: Text('15 minutes')),
                    DropdownMenuItem(value: '30', child: Text('30 minutes')),
                    DropdownMenuItem(value: '60', child: Text('1 hour')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(syncSettingsProvider.notifier)
                          .updateSettings(
                            (s) => s.copyWith(
                              backgroundIntervalMinutes: int.parse(val),
                            ),
                          );
                    }
                  },
                ),
            ],
          ),

          if (syncSettings.syncMode == 'realtime') ...[
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Preferences',
              titleColor: colorScheme.primary,
              children: [
                ToggleableSettingsItem(
                  icon: Icon(
                    Iconsax.message_question,
                    color: colorScheme.primary,
                  ),
                  accent: colorScheme.primary,
                  title: 'Update prompt',
                  description: 'Always ask before syncing progress',
                  value: syncSettings.askBeforeSync,
                  onChanged:
                      (val) => ref
                          .read(syncSettingsProvider.notifier)
                          .updateSettings(
                            (s) => s.copyWith(askBeforeSync: val),
                          ),
                ),
                const SizedBox(height: 16),
                SliderSettingsItem(
                  icon: Icon(Icons.percent_rounded, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Sync Threshold (${syncSettings.syncPercentage}%)',
                  description:
                      'Update tracker when you reach this percentage of the episode',
                  value: syncSettings.syncPercentage.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  onChanged: (val) {
                    ref
                        .read(syncSettingsProvider.notifier)
                        .updateSettings(
                          (s) => s.copyWith(syncPercentage: val.toInt()),
                        );
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          SettingsSection(
            title: 'Actions',
            titleColor: colorScheme.primary,
            children: [
              NormalSettingsItem(
                icon: Icon(
                  _isSyncing ? Iconsax.refresh : Icons.refresh,
                  color: colorScheme.primary,
                ),
                accent: colorScheme.primary,
                title: _isSyncing ? 'Syncing...' : 'Force Sync Now',
                description: 'Manually trigger a full sync',
                onTap: _isSyncing ? null : () => _forceSyncNow(ref),
              ),
              if (isAnilistLoggedIn && isMalLoggedIn)
                NormalSettingsItem(
                  icon: Icon(
                    Iconsax.convert_3d_cube,
                    color: colorScheme.primary,
                  ),
                  accent: colorScheme.primary,
                  title:
                      _migrationProgress == null
                          ? 'Copy AniList library to MAL'
                          : 'Copying library…',
                  description:
                      _migrationProgress ??
                      'One-time copy of your existing AniList progress, status and scores',
                  onTap:
                      _isSyncing || _migrationProgress != null
                          ? null
                          : () => _confirmAniListToMalCopy(ref),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAniListToMalCopy(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Copy AniList library?'),
            content: const Text(
              'Your existing AniList anime status, episode progress and scores '
              'will be copied to MyAnimeList. AniList will not be changed or '
              'deleted. Existing matching MAL entries will be updated.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Copy'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await _copyAniListLibraryToMal(ref);
  }

  Future<void> _copyAniListLibraryToMal(WidgetRef ref) async {
    const statuses = ['CURRENT', 'COMPLETED', 'PAUSED', 'DROPPED', 'PLANNING'];
    final aniList = ref.read(anilistServiceProvider);
    final mal = ref.read(malServiceProvider);
    final entries = <String, UniversalMediaListEntry>{};

    setState(() => _migrationProgress = 'Reading AniList library…');
    try {
      for (final status in statuses) {
        var page = 1;
        var hasNextPage = true;
        while (hasNextPage) {
          final response = await aniList.getUserAnimeList(
            type: 'ANIME',
            status: status,
            page: page,
            perPage: 50,
          );
          for (final entry in response.data) {
            final malId = entry.media.idMal;
            if (malId != null && int.tryParse(malId) != null) {
              entries[malId] = entry;
            }
          }
          hasNextPage = response.pageInfo.hasNextPage;
          page++;
        }
      }

      var copied = 0;
      var failed = 0;
      final values = entries.values.toList(growable: false);
      for (final entry in values) {
        if (!mounted) return;
        setState(
          () =>
              _migrationProgress =
                  'Copying ${copied + failed + 1}/${values.length}…',
        );
        final malId = int.parse(entry.media.idMal!);
        final result = await mal.updateUserAnimeList(
          mediaId: malId,
          status: entry.status,
          score: entry.score,
          progress: entry.progress,
          repeat: entry.repeat,
          notes: entry.notes,
          private: entry.isPrivate,
        );
        if (result == null) {
          failed++;
        } else {
          copied++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? 'Copied $copied AniList entries to MyAnimeList'
                : 'Copied $copied entries; $failed could not be matched or updated',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('AniList to MAL library copy failed', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Library copy failed: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _migrationProgress = null);
    }
  }

  String _syncModeDescription(String mode) {
    switch (mode) {
      case 'realtime':
        return 'Sync immediately on every change (Recommended)';
      case 'background':
        return 'Sync at defined intervals';
      default:
        return '';
    }
  }

  Future<void> _forceSyncNow(WidgetRef ref) async {
    setState(() => _isSyncing = true);
    try {
      final syncNotifier = ref.read(syncSettingsProvider.notifier);
      final List<Future> tasks = [];

      if (syncNotifier.shouldSyncAnilist) {
        AppLogger.i('Force syncing with AniList...');
        tasks.add(
          ref
              .read(anilistServiceProvider)
              .getUserAnimeList(
                type: 'ANIME',
                status: 'CURRENT',
                page: 1,
                perPage: 50,
              ),
        );
      }

      if (syncNotifier.shouldSyncMal) {
        AppLogger.i('Force syncing with MAL...');
        tasks.add(
          ref
              .read(malServiceProvider)
              .getUserAnimeList(
                type: 'ANIME',
                status: 'watching',
                page: 1,
                perPage: 50,
              ),
        );
      }

      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tasks.isEmpty
                  ? 'No sync services enabled'
                  : 'Sync completed successfully',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Force sync failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
