import 'package:flutter_test/flutter_test.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';

void main() {
  group('Continue Watching regressions', () {
    test('unknown-length series stays visible after one watched episode', () {
      final entry = AnimeWatchProgressEntry(
        animeId: 'one-piece',
        animeTitle: 'One Piece',
        animeFormat: 'TV',
        animeCover: '',
        totalEpisodes: 0,
        currentEpisode: 182,
        episodesProgress: {
          182: EpisodeProgress(
            episodeNumber: 182,
            episodeTitle: 'Episode 182',
            episodeThumbnail: null,
            isCompleted: true,
            progressInSeconds: 1440,
            durationInSeconds: 1440,
          ),
        },
      );

      expect(entry.isCompletedOrFinished, isFalse);
      expect(entry.hasAnyWatchProgress, isTrue);
    });

    test('a completed one-shot movie leaves Continue Watching', () {
      final entry = AnimeWatchProgressEntry(
        animeId: 'movie',
        animeTitle: 'Movie',
        animeFormat: 'MOVIE',
        animeCover: '',
        totalEpisodes: 1,
        currentEpisode: 1,
        episodesProgress: {
          1: EpisodeProgress(
            episodeNumber: 1,
            episodeTitle: 'Movie',
            episodeThumbnail: null,
            isCompleted: true,
            progressInSeconds: 5400,
            durationInSeconds: 5400,
          ),
        },
      );

      expect(entry.isCompletedOrFinished, isTrue);
    });
  });
}
