import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/services/anilist/anilist_service.dart';
import 'package:ani_dash/core/hindi_sources/hindi_source_manager.dart';
import 'package:ani_dash/core/registery/sources/anime/aniwatch/aniwatch.dart';
import 'package:ani_dash/core/registery/sources/anime/aniwatch/hianime.dart';
import 'package:ani_dash/core/registery/sources/anime/animekai.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';

class EpisodeReleaseTask {
  static Future<bool> performCheck() async {
    AppLogger.i('[Worker] anidash_notification_check started');
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

      AppLogger.d(
        '[Worker] Enabled categories: SUB=$enableSubReleases, EnglishDub=$enableDubReleases, HindiDub=$enableDubReleases, ContinueWatching=$enableContinueWatching',
      );

      await NotificationService().initialize(isBackground: true);

      final appDir = await getApplicationSupportDirectory();
      Hive.init(p.join(appDir.path, 'AniDash', 'appdata'));

      if (!Hive.isBoxOpen('anime_watch_progress')) {
        await Hive.openBox<AnimeWatchProgressEntry>('anime_watch_progress');
      }
      final box = Hive.box<AnimeWatchProgressEntry>('anime_watch_progress');

      final watchingEntries =
          box.values.where((e) => e.status == 'watching').toList();
      AppLogger.d(
        '[Worker] Checking ${watchingEntries.length} relevant watching anime entries',
      );

      final anilistService = AnilistService(
        getAuthContext: () => null,
        getAdultParam: () => false,
      );

      final hindiManager = HindiSourceManagerNotifier();
      var hindiInitialized = false;

      for (final entry in watchingEntries) {
        // -------------------------------------------------------------
        // 1. Continue Watching reminder
        // -------------------------------------------------------------
        if (enableContinueWatching) {
          final lastWatched = entry.lastUpdated;
          if (lastWatched != null &&
              DateTime.now().difference(lastWatched).inDays >= 2) {
            final reminderKey =
                'continue_reminder_${entry.animeId}_${entry.currentEpisode}';
            final lastReminder = pref.getInt(reminderKey) ?? 0;
            final isCooldownActive =
                DateTime.now().millisecondsSinceEpoch - lastReminder <
                const Duration(days: 7).inMilliseconds;

            if (isCooldownActive) {
              AppLogger.d(
                '[Worker] Continue watching duplicate suppressed for ${entry.animeTitle} (cooldown active)',
              );
            } else {
              AppLogger.i(
                '[Worker] Sending Continue Watching reminder for ${entry.animeTitle} Ep ${entry.currentEpisode}',
              );
              await NotificationService().showContinueWatchingNotification(
                animeTitle: entry.animeTitle,
                episodeNumber: entry.currentEpisode,
                mediaId: entry.animeId,
              );
              await pref.setInt(
                reminderKey,
                DateTime.now().millisecondsSinceEpoch,
              );
            }
          }
        }

        // -------------------------------------------------------------
        // 2. SUB Releases & Upcoming Airing Alerts (via AniList)
        // -------------------------------------------------------------
        final anilistId = int.tryParse(entry.animeId);
        if (anilistId != null) {
          try {
            final media = await anilistService.getAnimeDetails(anilistId);
            if (media != null) {
              final nextAir = media.nextAiringEpisode;

              // Upcoming Alerts with persistent dedupe
              if (nextAir != null &&
                  nextAir.episode != null &&
                  nextAir.timeUntilAiring != null) {
                final secondsUntil = nextAir.timeUntilAiring!;
                final nextEp = nextAir.episode!;

                // 2-hour window alert
                if (secondsUntil > 0 && secondsUntil <= 2 * 3600) {
                  final alertKey =
                      'upcoming:${entry.animeId}:$nextEp:2h';
                  final alreadyAlerted = pref.getBool(alertKey) ?? false;
                  if (alreadyAlerted) {
                    AppLogger.d(
                      '[Worker] Duplicate upcoming 2h alert suppressed: ${entry.animeTitle} Ep $nextEp',
                    );
                  } else {
                    AppLogger.i(
                      '[Worker] Upcoming 2h alert: ${entry.animeTitle} Ep $nextEp',
                    );
                    await NotificationService().showEpisodeReleaseNotification(
                      animeTitle: entry.animeTitle,
                      episodeNumber: nextEp,
                      mediaId: entry.animeId,
                      customTitle: '${entry.animeTitle} Airs Soon!',
                      customBody:
                          'Episode $nextEp airs in less than 2 hours. Get ready!',
                      audioType: 'upcoming',
                      dedupeKey: alertKey,
                    );
                    await pref.setBool(alertKey, true);
                  }
                }
                // Tomorrow alert (between 20h and 28h)
                else if (secondsUntil > 20 * 3600 &&
                    secondsUntil <= 28 * 3600) {
                  final alertKey =
                      'upcoming:${entry.animeId}:$nextEp:tomorrow';
                  final alreadyAlerted = pref.getBool(alertKey) ?? false;
                  if (alreadyAlerted) {
                    AppLogger.d(
                      '[Worker] Duplicate upcoming tomorrow alert suppressed: ${entry.animeTitle} Ep $nextEp',
                    );
                  } else {
                    AppLogger.i(
                      '[Worker] Upcoming tomorrow alert: ${entry.animeTitle} Ep $nextEp',
                    );
                    await NotificationService().showEpisodeReleaseNotification(
                      animeTitle: entry.animeTitle,
                      episodeNumber: nextEp,
                      mediaId: entry.animeId,
                      customTitle: '${entry.animeTitle} Airs Tomorrow!',
                      customBody:
                          'Episode $nextEp airs tomorrow. Don\'t miss it!',
                      audioType: 'upcoming',
                      dedupeKey: alertKey,
                    );
                    await pref.setBool(alertKey, true);
                  }
                }
              }

              // SUB Release check (previous vs current availability)
              if (enableSubReleases) {
                int? latestReleasedSub;
                if (nextAir != null &&
                    nextAir.episode != null &&
                    nextAir.episode! > 1) {
                  latestReleasedSub = nextAir.episode! - 1;
                } else if (media.status?.toUpperCase() == 'FINISHED' &&
                    media.episodes != null &&
                    media.episodes! > 0) {
                  latestReleasedSub = media.episodes!;
                } else {
                  // Airing anime with no nextAiringEpisode or unconfirmed status:
                  // Query actual playable source sub count instead of planned total episode count!
                  latestReleasedSub =
                      await _fetchSubEpisodeCount(entry.animeTitle);
                }

                if (latestReleasedSub != null && latestReleasedSub > 0) {
                  final lastSubKey = 'last_known_sub_ep_${entry.animeId}';
                  final previousSub = pref.getInt(lastSubKey);

                  if (previousSub != null && latestReleasedSub > previousSub) {
                    AppLogger.i(
                      '[Worker] Release detected (SUB): ${entry.animeTitle} Ep $latestReleasedSub (was $previousSub)',
                    );
                    final String body;
                    if (entry.currentEpisode >= latestReleasedSub - 1) {
                      body =
                          'Episode $latestReleasedSub just released! Watch the newest episode on AniDash.';
                    } else {
                      body =
                          'Episode $latestReleasedSub is now available! You\'re currently on Episode ${entry.currentEpisode}.';
                    }

                    await NotificationService().showEpisodeReleaseNotification(
                      animeTitle: entry.animeTitle,
                      episodeNumber: latestReleasedSub,
                      isDub: false,
                      mediaId: entry.animeId,
                      customTitle: 'New SUB Episode Available',
                      customBody: body,
                      audioType: 'sub',
                    );
                  } else if (previousSub != null) {
                    AppLogger.d(
                      '[Worker] SUB release duplicate suppressed: ${entry.animeTitle} Ep $latestReleasedSub (current <= previous $previousSub)',
                    );
                  }
                  await pref.setInt(lastSubKey, latestReleasedSub);
                }
              }
            }
          } catch (e) {
            AppLogger.w('Anilist detail check failed for ${entry.animeId}: $e');
          }
        }

        // -------------------------------------------------------------
        // 3. English DUB Releases (via normal anime extensions/sources)
        // -------------------------------------------------------------
        if (enableDubReleases) {
          try {
            final latestEnglishDubEp =
                await _fetchEnglishDubCount(entry.animeTitle);
            if (latestEnglishDubEp != null && latestEnglishDubEp > 0) {
              final lastDubKey =
                  'last_known_english_dub_ep_${entry.animeId}';
              final previousEnglishDub = pref.getInt(lastDubKey);

              if (previousEnglishDub != null &&
                  latestEnglishDubEp > previousEnglishDub) {
                AppLogger.i(
                  '[Worker] Release detected (English DUB): ${entry.animeTitle} Ep $latestEnglishDubEp (was $previousEnglishDub)',
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
                AppLogger.d(
                  '[Worker] English Dub duplicate suppressed: ${entry.animeTitle} Ep $latestEnglishDubEp (current <= previous $previousEnglishDub)',
                );
              }
              await pref.setInt(lastDubKey, latestEnglishDubEp);
            }
          } catch (e) {
            AppLogger.w('English dub release check failed for ${entry.animeTitle}: $e');
          }

          // -------------------------------------------------------------
          // 4. Hindi DUB Releases (strictly via HindiSourceManager)
          // -------------------------------------------------------------
          try {
            if (!hindiInitialized) {
              await hindiManager.init();
              hindiInitialized = true;
            }
            final maxHindiEp = await _fetchHindiDubCount(
              hindiManager,
              entry.animeTitle,
              anilistId,
            );

            if (maxHindiEp != null && maxHindiEp > 0) {
              final lastHindiKey = 'last_known_hindi_ep_${entry.animeId}';
              final previousHindi = pref.getInt(lastHindiKey);

              if (previousHindi != null && maxHindiEp > previousHindi) {
                AppLogger.i(
                  '[Worker] Release detected (Hindi DUB): ${entry.animeTitle} Ep $maxHindiEp (was $previousHindi)',
                );
                await NotificationService().showEpisodeReleaseNotification(
                  animeTitle: entry.animeTitle,
                  episodeNumber: maxHindiEp,
                  isDub: true,
                  mediaId: entry.animeId,
                  customTitle: 'New Hindi Dub Available',
                  customBody:
                      '${entry.animeTitle} Episode $maxHindiEp is now available in Hindi Dub!',
                  audioType: 'hindi_dub',
                );
              } else if (previousHindi != null) {
                AppLogger.d(
                  '[Worker] Hindi Dub duplicate suppressed: ${entry.animeTitle} Ep $maxHindiEp (current <= previous $previousHindi)',
                );
              }
              await pref.setInt(lastHindiKey, maxHindiEp);
            }
          } catch (e) {
            AppLogger.w('Hindi dub release check failed for ${entry.animeTitle}: $e');
          }
        }
      }
      AppLogger.i('[Worker] anidash_notification_check completed successfully');
      return true;
    } catch (e, st) {
      AppLogger.e('[Worker] anidash_notification_check failed', e, st);
      return false;
    }
  }

  /// Resolves SUB episode availability via standard anime providers when AniList airing metadata is absent
  static Future<int?> _fetchSubEpisodeCount(String title) async {
    try {
      final hianime = HiAnimeProvider();
      final search = await hianime
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 12));
      if (search.results.isNotEmpty) {
        final exactMatch = search.results.firstWhere(
          (r) => (r.name?.toLowerCase().trim() == title.toLowerCase().trim()),
          orElse: () => search.results.first,
        );
        if (exactMatch.episodes?.sub != null && exactMatch.episodes!.sub! > 0) {
          return exactMatch.episodes!.sub;
        }
      }
    } catch (_) {}

    try {
      final aniwatch = AniwatchProvider();
      final search = await aniwatch
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 12));
      if (search.results.isNotEmpty) {
        final exactMatch = search.results.firstWhere(
          (r) => (r.name?.toLowerCase().trim() == title.toLowerCase().trim()),
          orElse: () => search.results.first,
        );
        if (exactMatch.episodes?.sub != null && exactMatch.episodes!.sub! > 0) {
          return exactMatch.episodes!.sub;
        }
      }
    } catch (_) {}

    try {
      final animeKai = AnimekaiProvider();
      final search = await animeKai
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 12));
      if (search.results.isNotEmpty) {
        final exactMatch = search.results.firstWhere(
          (r) => (r.name?.toLowerCase().trim() == title.toLowerCase().trim()),
          orElse: () => search.results.first,
        );
        if (exactMatch.episodes?.sub != null && exactMatch.episodes!.sub! > 0) {
          return exactMatch.episodes!.sub;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Resolves English Dub episode availability via standard anime providers
  static Future<int?> _fetchEnglishDubCount(String title) async {
    try {
      final hianime = HiAnimeProvider();
      final search = await hianime
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 12));
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
          .timeout(const Duration(seconds: 12));
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
      final animeKai = AnimekaiProvider();
      final search = await animeKai
          .getSearch(title, null, 1)
          .timeout(const Duration(seconds: 12));
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
  }

  /// Resolves Hindi Dub episode availability strictly via Hindi providers
  static Future<int?> _fetchHindiDubCount(
    HindiSourceManagerNotifier hindiManager,
    String title,
    int? anilistId,
  ) async {
    final enabledSources = hindiManager.getSources().where((s) => s.enabled);
    int? maxHindi;
    for (final src in enabledSources) {
      final prov = hindiManager.getProvider(src.id);
      if (prov != null) {
        final provAnimeId = await prov.findAnime(
          title: title,
          anilistId: anilistId,
        );
        if (provAnimeId != null) {
          final count = await prov.getEpisodeCount(provAnimeId);
          if (count != null && (maxHindi == null || count > maxHindi)) {
            maxHindi = count;
          }
        }
      }
    }
    return maxHindi;
  }
}
