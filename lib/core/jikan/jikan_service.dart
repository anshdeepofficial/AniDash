import 'dart:convert';
import 'package:ani_dash/core/jikan/models/jikan_media.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class JikanEpisode {
  final int malId;
  final String title;
  final String? aired;
  final bool filler;
  final bool recap;

  JikanEpisode({
    required this.malId,
    required this.title,
    this.aired,
    this.filler = false,
    this.recap = false,
  });

  factory JikanEpisode.fromJson(Map<String, dynamic> json) {
    return JikanEpisode(
      malId: json['mal_id'] ?? 0,
      title: json['title'] ?? 'Episode ${json['mal_id']}',
      aired: json['aired']?.toString(),
      filler: json['filler'] == true || json['filler'] == 1,
      recap: json['recap'] == true || json['recap'] == 1,
    );
  }
}

class JikanService {
  static const _baseUrl = 'https://api.jikan.moe/v4';

  Future<List<JikanMedia>> getSearch({
    required String title,
    int limit = 5,
  }) async {
    try {
      final url = '$_baseUrl/anime?q=$title&limit=$limit';
      final response = await UniversalHttpClient.instance.get(
        Uri.parse(url),
        cacheConfig: CacheConfig.long,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['data'];
        return results.map((e) => JikanMedia.fromMap(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Jikan Search Error: $e');
      return [];
    }
  }

  Future<List<JikanEpisode>> getEpisodes(int malId, int page) async {
    try {
      final url = '$_baseUrl/anime/$malId/episodes?page=$page';
      final response = await UniversalHttpClient.instance.get(
        Uri.parse(url),
        cacheConfig: CacheConfig.long,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> episodes = data['data'];
        return episodes.map((e) => JikanEpisode.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Jikan Episodes Error: $e');
      return [];
    }
  }

  Future<({Map<String, dynamic> details, List<dynamic> staff})?> getFullDetails(
    int malId,
  ) async {
    try {
      final responses = await Future.wait([
        UniversalHttpClient.instance.get(
          Uri.parse('$_baseUrl/anime/$malId/full'),
          cacheConfig: CacheConfig.long,
        ),
        UniversalHttpClient.instance.get(
          Uri.parse('$_baseUrl/anime/$malId/staff'),
          cacheConfig: CacheConfig.long,
        ),
      ]).timeout(const Duration(seconds: 20));
      if (responses.first.statusCode != 200) return null;
      final detailsJson = json.decode(responses.first.body);
      final staffJson =
          responses.last.statusCode == 200
              ? json.decode(responses.last.body)
              : const <String, dynamic>{};
      return (
        details: Map<String, dynamic>.from(detailsJson['data'] ?? {}),
        staff: List<dynamic>.from(staffJson['data'] ?? const []),
      );
    } catch (e) {
      AppLogger.e('Jikan Full Details Error: $e');
      return null;
    }
  }
}
