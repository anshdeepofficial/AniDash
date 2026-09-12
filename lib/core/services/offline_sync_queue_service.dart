import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/models/tracker/tracker_type.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/core/repositories/local_media_repository.dart';
import 'package:ani_dash/core/repositories/watch_progress_repository.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/shared/providers/settings/sync_settings_notifier.dart';
import 'package:ani_dash/shared/providers/tracker/media_tracker_notifier.dart';

class QueuedSyncEntry {
  final String mediaId;
  final int episodeNum;
  final String status;
  final int timestamp;

  QueuedSyncEntry({
    required this.mediaId,
    required this.episodeNum,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'episodeNum': episodeNum,
        'status': status,
        'timestamp': timestamp,
      };

  factory QueuedSyncEntry.fromJson(Map<String, dynamic> map) => QueuedSyncEntry(
        mediaId: map['mediaId'] as String,
        episodeNum: (map['episodeNum'] as num).toInt(),
        status: map['status'] as String? ?? 'CURRENT',
        timestamp: (map['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}

class OfflineSyncQueueService {
  static const String _prefsKey = 'offline_sync_queue_items';
  static bool _isSyncing = false;

  static Future<List<QueuedSyncEntry>> getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];
      return raw
          .map((item) =>
              QueuedSyncEntry.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.w('Failed to read offline sync queue: $e');
      return [];
    }
  }

  static Future<void> enqueue({
    required String mediaId,
    required int episodeNum,
    required String status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = await getQueue();

      // Deduplicate: replace any existing entry for this mediaId with higher/latest episode
      currentQueue.removeWhere((e) => e.mediaId == mediaId);
      currentQueue.add(
        QueuedSyncEntry(
          mediaId: mediaId,
          episodeNum: episodeNum,
          status: status,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final encoded =
          currentQueue.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefsKey, encoded);
      AppLogger.i('Enqueued offline sync update for mediaId: $mediaId (Ep: $episodeNum)');
    } catch (e) {
      AppLogger.w('Failed to enqueue offline sync update: $e');
    }
  }

  static Future<void> flushQueue(WidgetRef ref) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((c) => c == ConnectivityResult.none)) {
        _isSyncing = false;
        return;
      }

      final currentQueue = await getQueue();
      if (currentQueue.isEmpty) {
        _isSyncing = false;
        return;
      }

      AppLogger.i('Flushing offline sync queue (${currentQueue.length} pending items)...');
      final repo = ref.read(localMediaRepoProvider);
      final syncNotifier = ref.read(syncSettingsProvider.notifier);
      final watchProgressRepo = ref.read(watchProgressRepositoryProvider);

      final List<QueuedSyncEntry> remaining = [];

      for (final item in currentQueue) {
        try {
          final bindings = await repo.getBindings(item.mediaId);
          final activeBindings = bindings
              .where(
                (b) =>
                    (b.type == TrackerType.anilist &&
                        syncNotifier.shouldSyncAnilist) ||
                    (b.type == TrackerType.mal && syncNotifier.shouldSyncMal),
              )
              .toList();

          final trackerNotifier =
              ref.read(mediaTrackerProvider(item.mediaId).notifier);

          if (activeBindings.isNotEmpty) {
            await trackerNotifier.syncTrackers(
              bindings: activeBindings,
              status: item.status,
              progress: item.episodeNum,
            );
          }

          if (syncNotifier.shouldSyncLocal) {
            final entry = watchProgressRepo.getProgress(item.mediaId);
            final localEntry = await trackerNotifier.getLocalEntry();

            await trackerNotifier.saveLocalEntry(
              UniversalMedia(
                id: item.mediaId,
                title: UniversalTitle(
                    english: entry?.animeTitle ?? 'Unknown'),
                coverImage: UniversalCoverImage(large: entry?.animeCover),
                status: 'UNKNOWN',
                format: entry?.animeFormat,
                episodes: entry?.totalEpisodes,
              ),
              status: item.status,
              progress: item.episodeNum,
              score: localEntry?.score ?? 0.0,
              repeat: localEntry?.repeat ?? 0,
              notes: localEntry?.notes ?? '',
              isPrivate: localEntry?.isPrivate ?? false,
              startedAt: DateTime.now(),
            );
          }
          AppLogger.i('Successfully flushed offline sync for ${item.mediaId}');
        } catch (err) {
          AppLogger.w('Failed to sync queued item ${item.mediaId}: $err');
          remaining.add(item);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final encoded =
          remaining.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefsKey, encoded);
    } catch (e) {
      AppLogger.w('Error flushing offline sync queue: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
