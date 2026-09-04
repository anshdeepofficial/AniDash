import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EpisodeReleaseTask {
  static Future<bool> performCheck() async {
    try {
      final pref = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      final notifJson = pref.getString('notification_settings_data');
      if (notifJson != null && notifJson.contains('"enableEpisodeReleases":false')) {
        return true;
      }

      final appDir = await getApplicationSupportDirectory();
      Hive.init(p.join(appDir.path, 'AniDash', 'appdata'));

      if (!Hive.isBoxOpen('watch_progress')) {
        await Hive.openBox<AnimeWatchProgressEntry>('watch_progress');
      }
      final box = Hive.box<AnimeWatchProgressEntry>('watch_progress');

      for (final entry in box.values) {
        if (entry.status == 'watching') {
          // Check for episode reminder
          if (notifJson == null || !notifJson.contains('"enableContinueWatching":false')) {
            final lastWatched = entry.lastUpdated;
            if (lastWatched != null &&
                DateTime.now().difference(lastWatched).inDays >= 2) {
              await NotificationService().showContinueWatchingNotification(
                animeTitle: entry.animeTitle,
                episodeNumber: entry.currentEpisode,
              );
            }
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
