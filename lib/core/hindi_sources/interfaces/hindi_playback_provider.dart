import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';

abstract class HindiPlaybackProvider {
  String get id;
  String get name;
  String get baseUrl;
  List<String> get mirrors => const [];
  bool get supportsStreaming => true;
  bool get supportsDownloads => false;
  bool get supportsMultiAudio => true;

  void configure(HindiSourceModel model) {}

  Future<bool> healthCheck();

  /// Searches for matching anime on the provider by title / metadata.
  /// Returns the provider's anime identifier or detail URL, or null if not found.
  Future<String?> findAnime({
    required String title,
    String? romajiTitle,
    int? anilistId,
    int? malId,
    int? year,
  });

  /// Resolves the stream for the specified episode.
  /// Returns BaseSourcesModel containing playable Sources and Subtitles.
  Future<BaseSourcesModel?> resolveEpisode({
    required String providerAnimeId,
    required int episodeNumber,
    String? animeTitle,
  });

  /// Resolves total number of available episodes for this anime on provider.
  Future<int?> getEpisodeCount(String providerAnimeId) async => null;

  /// Resolves direct download link for an episode (if supported).
  Future<String?> resolveDownload({
    required String providerAnimeId,
    required int episodeNumber,
    String? quality,
  }) async => null;
}
