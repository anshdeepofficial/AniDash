import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';

abstract class WatchProgressRepositoryInterface {
  Future<void> saveProgress(AnimeWatchProgressEntry entry);
  AnimeWatchProgressEntry? getProgress(String animeId);
  List<AnimeWatchProgressEntry> getAllProgress();
  Future<void> updateEpisodeProgress(
    String animeId,
    EpisodeProgress episodeProgress,
  );
  Future<void> markPreviousEpisodesWatched({
    required String animeId,
    required String animeTitle,
    required String animeCover,
    required String animeFormat,
    required int upToEpisodeNumber,
  });
  Future<void> deleteProgress(String animeId);
  Future<void> deleteEpisodeProgress(String animeId, int episodeNumber);
  Future<void> deleteMultipleProgress(List<String> animeIds);
  EpisodeProgress? getEpisodeProgress(String animeId, int episodeNumber);
  Stream<List<AnimeWatchProgressEntry>> watchAllProgress();
  Stream<AnimeWatchProgressEntry?> watchProgress(String animeId);
  Future<void> migrateFromHive();
}
