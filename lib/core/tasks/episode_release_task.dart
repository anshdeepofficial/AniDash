import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/services/anilist/queries.dart';
import 'package:ani_dash/core/registery/sources/anime/aniwatch/aniwatch.dart';
import 'package:ani_dash/core/registery/sources/anime/aniwatch/hianime.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';

class NotificationCheckResult {
  final bool success;
  final int schedulesReturned;
  final int relevantCount;
  final int sentCount;
  final int duplicateSuppressed;
  final String message;

  const NotificationCheckResult({
    required this.success,
    this.schedulesReturned = 0,
    this.relevantCount = 0,
    this.sentCount = 0,
    this.duplicateSuppressed = 0,
    required this.message,
  });

  @override
  String toString() =>
      'NotificationCheckResult(success: $success, schedules: $schedulesReturned, relevant: $relevantCount, sent: $sentCount, suppressed: $duplicateSuppressed, message: $message)';
}

class EpisodeReleaseTask {
  static const String keyLastCheck =
      'lastSuccessfulEpisodeNotificationCheckAt';

  Future<NotificationCheckResult> run() => performCheck(isManual: true);

  static Future<NotificationCheckResult> performCheck({
    bool isManual = false,
  }) async {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    AppLogger.i('[NotificationWorker] started');

    int schedulesReturned = 0;
    int relevantCount = 0;
    int sentCount = 0;
    int duplicateSuppressed = 0;

    try {
      final pref = await SharedPreferences.getInstance();
      final notifJson = pref.getString('notification_settings_data');

      bool enableSubReleases = true;
      bool enableDubReleases = true;
      bool enableContinueWatching = true;

      if (notifJson != null) {
        try {
          final decoded = jsonDecode(notifJson) as Map<String, dynamic>;
          enableSubReleases = decoded['enableSubReleases'] as bool? ?? true;
          enableDubReleases = decoded['enableDubReleases'] as bool? ?? true;
          enableContinueWatching =
              decoded['enableContinueWatching'] as bool? ?? true;
        } catch (_) {}
      }

      await NotificationService().initialize(isBackground: !isManual);

      // Open Hive box for local watch progress
      try {
        final appDir = await getApplicationSupportDirectory();
        Hive.init(p.join(appDir.path, 'AniDash', 'appdata'));
        if (!Hive.isBoxOpen('anime_watch_progress')) {
          await Hive.openBox<AnimeWatchProgressEntry>('anime_watch_progress');
        }
      } catch (e) {
        AppLogger.w('Hive init in notification task warning: $e');
      }

      Box<AnimeWatchProgressEntry>? box;
      if (Hive.isBoxOpen('anime_watch_progress')) {
        box = Hive.box<AnimeWatchProgressEntry>('anime_watch_progress');
      }

      final allProgress = box?.values.toList() ?? [];
      final relevantEntries = allProgress.where((e) {
        return e.status == 'watching' || e.currentEpisode > 0;
      }).toList();

      final relevantMediaIds = <int>{};
      final mediaTitlesById = <int, String>{};
      for (final e in relevantEntries) {
        final id = int.tryParse(e.animeId);
        if (id != null) {
          relevantMediaIds.add(id);
          mediaTitlesById[id] = e.animeTitle;
        }
      }

      // Check last successful check time
      final lastCheckEpoch = pref.getInt(keyLastCheck);
      final int startWindow;
      if (lastCheckEpoch == null) {
        // Initial / first-run sync: reasonable 24-hour window
        startWindow = nowEpoch - (24 * 3600);
      } else {
        // Reconcile between last successful check and now, bounded up to 7 days
        startWindow = (lastCheckEpoch).clamp(nowEpoch - (7 * 86400), nowEpoch - 60);
      }

      AppLogger.i(
        '[NotificationWorker] last check = ${DateTime.fromMillisecondsSinceEpoch(startWindow * 1000).toIso8601String()}',
      );

      // -------------------------------------------------------------
      // 1. SUB Releases (Past releases within window)
      // -------------------------------------------------------------
      if (enableSubReleases) {
        try {
          final pastSchedules = await _fetchAniListAiringSchedules(
            startWindow: startWindow,
            endWindow: nowEpoch,
            mediaIds: relevantMediaIds.isNotEmpty ? relevantMediaIds.toList() : null,
          );
          schedulesReturned += pastSchedules.length;
          AppLogger.i(
            '[NotificationWorker] AniList past schedules returned = ${pastSchedules.length}',
          );

          // Filter for user's relevant anime if user has watch progress entries
          final List<Map<String, dynamic>> targetPastSchedules;
          if (relevantMediaIds.isNotEmpty) {
            targetPastSchedules = pastSchedules.where((s) {
              final mId = s['mediaId'] as int?;
              return mId != null && relevantMediaIds.contains(mId);
            }).toList();
          } else {
            // If user has no watch progress yet, only evaluate first 5 most recent
            targetPastSchedules = pastSchedules.take(5).toList();
          }

          relevantCount += targetPastSchedules.length;
          AppLogger.i(
            '[NotificationWorker] relevant past releases = ${targetPastSchedules.length}',
          );

          for (final s in targetPastSchedules) {
            final mediaId = s['mediaId'] as int;
            final epNum = s['episode'] as int;
            final mediaObj = s['media'] as Map<String, dynamic>? ?? {};
            final titleObj = mediaObj['title'] as Map<String, dynamic>? ?? {};
            final animeTitle = titleObj['english'] as String? ??
                titleObj['romaji'] as String? ??
                titleObj['userPreferred'] as String? ??
                mediaTitlesById[mediaId] ??
                'Anime';

            final dedupeKey = 'sub_release_${mediaId}_$epNum';
            final alreadyNotified = pref.getBool(dedupeKey) ?? false;

            if (alreadyNotified) {
              duplicateSuppressed++;
              AppLogger.d(
                '[NotificationWorker] duplicate suppressed = $dedupeKey',
              );
            } else {
              sentCount++;
              AppLogger.i(
                '[NotificationWorker] sent = $animeTitle Ep $epNum',
              );

              await NotificationService().showEpisodeReleaseNotification(
                animeTitle: animeTitle,
                episodeNumber: epNum,
                isDub: false,
                mediaId: mediaId.toString(),
                customTitle: '$animeTitle • Ep $epNum Released',
                customBody:
                    'Episode $epNum is now officially available to watch on AniDash.',
                audioType: 'sub',
                dedupeKey: dedupeKey,
              );
              await pref.setBool(dedupeKey, true);
            }
          }
        } catch (e) {
          AppLogger.w('AniList past airingSchedules check failed: $e');
        }

        // -------------------------------------------------------------
        // 1B. Upcoming Episodes (Exact Alarms & Countdown Notifications)
        // -------------------------------------------------------------
        try {
          final upcomingSchedules = await _fetchAniListAiringSchedules(
            startWindow: nowEpoch,
            endWindow: nowEpoch + (7 * 86400),
            mediaIds: relevantMediaIds.isNotEmpty ? relevantMediaIds.toList() : null,
            sort: ['TIME_ASC'],
          );
          schedulesReturned += upcomingSchedules.length;
          AppLogger.i(
            '[NotificationWorker] AniList upcoming schedules returned = ${upcomingSchedules.length}',
          );

          final List<Map<String, dynamic>> targetUpcomingSchedules;
          if (relevantMediaIds.isNotEmpty) {
            targetUpcomingSchedules = upcomingSchedules.where((s) {
              final mId = s['mediaId'] as int?;
              return mId != null && relevantMediaIds.contains(mId);
            }).toList();
          } else {
            targetUpcomingSchedules = upcomingSchedules.take(5).toList();
          }

          relevantCount += targetUpcomingSchedules.length;

          for (final s in targetUpcomingSchedules) {
            final mediaId = s['mediaId'] as int;
            final epNum = s['episode'] as int;
            final airingAt = s['airingAt'] as int? ?? 0;
            if (airingAt <= 0) continue;

            final mediaObj = s['media'] as Map<String, dynamic>? ?? {};
            final titleObj = mediaObj['title'] as Map<String, dynamic>? ?? {};
            final animeTitle = titleObj['english'] as String? ??
                titleObj['romaji'] as String? ??
                titleObj['userPreferred'] as String? ??
                mediaTitlesById[mediaId] ??
                'Anime';

            // 1. Register Exact Alarms with Android AlarmManager
            await NotificationService().scheduleUpcomingEpisodeAlerts(
              mediaId: mediaId,
              animeTitle: animeTitle,
              episodeNumber: epNum,
              airingAtEpoch: airingAt,
            );

            // 2. Real-time / Polling countdown checks
            final secondsUntilAiring = airingAt - nowEpoch;

            // 1-Hour window (<= 3600 seconds)
            if (secondsUntilAiring <= 3600 && secondsUntilAiring > 0) {
              final key1h = 'notif_1h_${mediaId}_$epNum';
              if (!(pref.getBool(key1h) ?? false)) {
                sentCount++;
                await NotificationService().showEpisodeReleaseNotification(
                  animeTitle: animeTitle,
                  episodeNumber: epNum,
                  isDub: false,
                  mediaId: mediaId.toString(),
                  customTitle: 'Upcoming: $animeTitle • Ep $epNum',
                  customBody:
                      'Episode $epNum releases in 1 hour!',
                  audioType: 'upcoming_1h',
                  dedupeKey: key1h,
                );
                await pref.setBool(key1h, true);
              } else {
                duplicateSuppressed++;
              }
            }
            // 2-Hour window (<= 7200 seconds and > 3600 seconds)
            else if (secondsUntilAiring <= 7200 && secondsUntilAiring > 3600) {
              final key2h = 'notif_2h_${mediaId}_$epNum';
              if (!(pref.getBool(key2h) ?? false)) {
                sentCount++;
                await NotificationService().showEpisodeReleaseNotification(
                  animeTitle: animeTitle,
                  episodeNumber: epNum,
                  isDub: false,
                  mediaId: mediaId.toString(),
                  customTitle: 'Upcoming: $animeTitle • Ep $epNum',
                  customBody:
                      'Episode $epNum releases in 2 hours!',
                  audioType: 'upcoming_2h',
                  dedupeKey: key2h,
                );
                await pref.setBool(key2h, true);
              } else {
                duplicateSuppressed++;
              }
            }
            // 24-Hour window (<= 86400 seconds and > 7200 seconds)
            else if (secondsUntilAiring <= 86400 && secondsUntilAiring > 7200) {
              final key24h = 'notif_24h_${mediaId}_$epNum';
              if (!(pref.getBool(key24h) ?? false)) {
                sentCount++;
                await NotificationService().showEpisodeReleaseNotification(
                  animeTitle: animeTitle,
                  episodeNumber: epNum,
                  isDub: false,
                  mediaId: mediaId.toString(),
                  customTitle: 'Upcoming: $animeTitle • Ep $epNum',
                  customBody:
                      'Episode $epNum releases tomorrow (in 24 hours)!',
                  audioType: 'upcoming_24h',
                  dedupeKey: key24h,
                );
                await pref.setBool(key24h, true);
              } else {
                duplicateSuppressed++;
              }
            }
          }
        } catch (e) {
          AppLogger.w('AniList upcoming airingSchedules check failed: $e');
        }
      }

      // -------------------------------------------------------------
      // 2. English DUB Releases (via extension sources)
      // -------------------------------------------------------------
      if (enableDubReleases) {
        for (final entry in relevantEntries.where((e) => e.status == 'watching')) {
          try {
            final latestEnglishDubEp =
                await _fetchEnglishDubCount(entry.animeTitle);
            if (latestEnglishDubEp != null && latestEnglishDubEp > 0) {
              final lastDubKey =
                  'last_known_english_dub_ep_${entry.animeId}';
              final previousEnglishDub = pref.getInt(lastDubKey);

              if (previousEnglishDub != null &&
                  latestEnglishDubEp > previousEnglishDub) {
                sentCount++;
                AppLogger.i(
                  '[NotificationWorker] sent = English DUB ${entry.animeTitle} Ep $latestEnglishDubEp',
                );
                await NotificationService().showEpisodeReleaseNotification(
                  animeTitle: entry.animeTitle,
                  episodeNumber: latestEnglishDubEp,
                  isDub: true,
                  mediaId: entry.animeId,
                  customTitle: 'New English Dub Episode',
                  customBody:
                      '${entry.animeTitle} Episode $latestEnglishDubEp is now available in English Dub!',
                  audioType: 'english_dub',
                );
              } else if (previousEnglishDub != null) {
                duplicateSuppressed++;
              }
              await pref.setInt(lastDubKey, latestEnglishDubEp);
            }
          } catch (_) {}
        }
      }

      // -------------------------------------------------------------
      // 4. Continue Watching Reminders (cooldown of 7 days)
      // -------------------------------------------------------------
      if (enableContinueWatching) {
        for (final entry in relevantEntries.where((e) => e.status == 'watching')) {
          final lastWatched = entry.lastUpdated;
          if (lastWatched != null &&
              DateTime.now().difference(lastWatched).inDays >= 2) {
            final reminderKey =
                'continue_reminder_${entry.animeId}_${entry.currentEpisode}';
            final lastReminder = pref.getInt(reminderKey) ?? 0;
            final isCooldownActive =
                DateTime.now().millisecondsSinceEpoch - lastReminder <
                const Duration(days: 7).inMilliseconds;

            if (!isCooldownActive) {
              sentCount++;
              await NotificationService().showContinueWatchingNotification(
                animeTitle: entry.animeTitle,
                episodeNumber: entry.currentEpisode,
                mediaId: entry.animeId,
              );
              await pref.setInt(
                reminderKey,
                DateTime.now().millisecondsSinceEpoch,
              );
            } else {
              duplicateSuppressed++;
            }
          }
        }
      }

      // Record successful check time
      await pref.setInt(keyLastCheck, nowEpoch);

      AppLogger.i(
        '[NotificationWorker] completed (sent: $sentCount, duplicate suppressed: $duplicateSuppressed)',
      );

      return NotificationCheckResult(
        success: true,
        schedulesReturned: schedulesReturned,
        relevantCount: relevantCount,
        sentCount: sentCount,
        duplicateSuppressed: duplicateSuppressed,
        message:
            'Check completed. Found $schedulesReturned schedules, $relevantCount relevant. Sent $sentCount notifications ($duplicateSuppressed suppressed).',
      );
    } catch (e, st) {
      AppLogger.e('[NotificationWorker] failed', e, st);
      return NotificationCheckResult(
        success: false,
        schedulesReturned: schedulesReturned,
        relevantCount: relevantCount,
        sentCount: sentCount,
        duplicateSuppressed: duplicateSuppressed,
        message: 'Notification check failed: $e',
      );
    }
  }

  /// Queries AniList GraphQL for real airingSchedules in the given epoch second window
  static Future<List<Map<String, dynamic>>> _fetchAniListAiringSchedules({
    required int startWindow,
    required int endWindow,
    List<int>? mediaIds,
    List<String>? sort,
  }) async {
    final response = await http
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'AniDash',
          },
          body: jsonEncode({
            'query': AnilistQueries.airingSchedulesQuery,
            'variables': {
              'greater': startWindow,
              'lesser': endWindow,
              'mediaIds': mediaIds,
              'page': 1,
              'perPage': 50,
              if (sort != null) 'sort': sort,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw HttpException('AniList AiringSchedule status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final page = data['data']?['Page'] as Map<String, dynamic>?;
    final list = page?['airingSchedules'] as List<dynamic>? ?? [];
    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  /// Resolves English Dub episode availability via standard anime providers
  static Future<int?> _fetchEnglishDubCount(String title) async {
    try {
      final hianime = HiAnimeProvider();
      final search = await hianime
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 10));
      if (search.results.isNotEmpty) {
        final exactMatch = search.results.firstWhere(
          (r) => (r.name?.toLowerCase().trim() == title.toLowerCase().trim()),
          orElse: () => search.results.first,
        );
        if (exactMatch.episodes?.dub != null && exactMatch.episodes!.dub! > 0) {
          return exactMatch.episodes!.dub;
        }
      }
    } catch (_) {}

    try {
      final aniwatch = AniwatchProvider();
      final search = await aniwatch
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 10));
      if (search.results.isNotEmpty) {
        final exactMatch = search.results.firstWhere(
          (r) => (r.name?.toLowerCase().trim() == title.toLowerCase().trim()),
          orElse: () => search.results.first,
        );
        if (exactMatch.episodes?.dub != null && exactMatch.episodes!.dub! > 0) {
          return exactMatch.episodes!.dub;
        }
      }
    } catch (_) {}

    return null;
  }}
