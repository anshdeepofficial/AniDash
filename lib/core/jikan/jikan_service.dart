import 'dart:convert';
import 'package:ani_dash/core/jikan/models/jikan_media.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
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

  Future<List<UniversalMedia>> searchUniversal(String title) =>
      _getUniversalList('/anime?q=${Uri.encodeQueryComponent(title)}&limit=20');

  Future<List<UniversalMedia>> getTopUniversal() =>
      _getUniversalList('/top/anime?limit=20');

  Future<List<UniversalMedia>> getPopularUniversal() =>
      _getUniversalList('/top/anime?filter=bypopularity&limit=20');

  Future<List<UniversalMedia>> getUpcomingUniversal() =>
      _getUniversalList('/seasons/upcoming?limit=20');

  Future<List<UniversalMedia>> _getUniversalList(String path) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await UniversalHttpClient.instance
            .get(Uri.parse('$_baseUrl$path'), cacheConfig: CacheConfig.long)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          return (body['data'] as List<dynamic>? ?? const [])
              .map((raw) => Map<String, dynamic>.from(raw as Map))
              .map(_toUniversalMedia)
              .toList();
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      }
    }
    AppLogger.e('Jikan browse fallback error: $lastError');
    return const [];
  }

  UniversalMedia _toUniversalMedia(Map<String, dynamic> data) {
    final images = Map<String, dynamic>.from(data['images'] as Map? ?? {});
    final jpg = Map<String, dynamic>.from(images['jpg'] as Map? ?? {});
    final titles =
        (data['titles'] as List<dynamic>? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    String? titleOf(String type) {
      for (final title in titles) {
        if (title['type'] == type) return title['title']?.toString();
      }
      return null;
    }

    final malId = data['mal_id']?.toString() ?? '';
    return UniversalMedia(
      id: 'mal:$malId',
      idMal: malId,
      title: UniversalTitle(
        romaji: titleOf('Default') ?? data['title']?.toString(),
        english: titleOf('English') ?? data['title_english']?.toString(),
        native: titleOf('Japanese') ?? data['title_japanese']?.toString(),
      ),
      coverImage: UniversalCoverImage(
        extraLarge: jpg['large_image_url']?.toString(),
        large: jpg['large_image_url']?.toString(),
        medium: jpg['image_url']?.toString(),
      ),
      format: data['type']?.toString(),
      status: data['status']?.toString(),
      description: data['synopsis']?.toString(),
      episodes: (data['episodes'] as num?)?.toInt(),
      duration:
          (data['duration']?.toString().isNotEmpty ?? false)
              ? int.tryParse(
                RegExp(
                      r'\d+',
                    ).firstMatch(data['duration'].toString())?.group(0) ??
                    '',
              )
              : null,
      averageScore: (data['score'] as num?)?.toDouble(),
      popularity: (data['popularity'] as num?)?.toInt(),
      isAdult: data['rating']?.toString().startsWith('Rx') == true,
      genres:
          (data['genres'] as List<dynamic>? ?? const [])
              .map((e) => (e as Map)['name']?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList(),
      siteUrl: data['url']?.toString(),
    );
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
