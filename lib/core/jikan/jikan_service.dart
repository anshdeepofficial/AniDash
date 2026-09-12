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
    Object? lastError;
    final url =
        '$_baseUrl/anime?q=${Uri.encodeQueryComponent(title)}&limit=$limit';
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await UniversalHttpClient.instance
            .get(Uri.parse(url), cacheConfig: CacheConfig.long)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> results = data['data'];
          return results.map((e) => JikanMedia.fromMap(e)).toList();
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      }
    }
    AppLogger.e('Jikan Search Error: $lastError');
    return [];
  }

  Future<List<UniversalMedia>> searchUniversal(String title) async {
    final result = await _getUniversalList(
      '/anime?q=${Uri.encodeQueryComponent(title)}&limit=20',
    );
    return result.isNotEmpty ? result : _getKitsuList(query: title);
  }

  Future<List<UniversalMedia>> getTopUniversal() async {
    final result = await _getUniversalList('/top/anime?limit=20');
    return result.isNotEmpty ? result : _getKitsuList(sort: '-averageRating');
  }

  Future<List<UniversalMedia>> getPopularUniversal() async {
    final result = await _getUniversalList(
      '/top/anime?filter=bypopularity&limit=20',
    );
    return result.isNotEmpty ? result : _getKitsuList(sort: 'popularityRank');
  }

  Future<List<UniversalMedia>> getUpcomingUniversal() async {
    final result = await _getUniversalList('/seasons/upcoming?limit=20');
    return result.isNotEmpty ? result : _getKitsuList(sort: '-startDate');
  }

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
      // UniversalMedia follows AniList's 0-100 score scale.
      averageScore:
          (data['score'] as num?)?.toDouble() == null
              ? null
              : (data['score'] as num).toDouble() * 10,
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

  Future<List<UniversalMedia>> _getKitsuList({
    String? query,
    String? sort,
  }) async {
    try {
      final parameters = <String, String>{'page[limit]': '20'};
      if (query?.trim().isNotEmpty == true) {
        parameters['filter[text]'] = query!.trim();
      }
      if (sort != null) parameters['sort'] = sort;
      final uri = Uri.https('kitsu.io', '/api/edge/anime', parameters);
      final response = await UniversalHttpClient.instance
          .get(uri, cacheConfig: CacheConfig.long)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];
      final body = json.decode(response.body) as Map<String, dynamic>;
      return (body['data'] as List<dynamic>? ?? const []).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final attributes = Map<String, dynamic>.from(
          item['attributes'] as Map? ?? const {},
        );
        final titles = Map<String, dynamic>.from(
          attributes['titles'] as Map? ?? const {},
        );
        final poster = Map<String, dynamic>.from(
          attributes['posterImage'] as Map? ?? const {},
        );
        final rating = double.tryParse(
          attributes['averageRating']?.toString() ?? '',
        );
        return UniversalMedia(
          id: 'kitsu:${item['id']}',
          title: UniversalTitle(
            romaji:
                titles['en_jp']?.toString() ??
                attributes['canonicalTitle']?.toString(),
            english: titles['en']?.toString(),
            native: titles['ja_jp']?.toString(),
          ),
          coverImage: UniversalCoverImage(
            extraLarge: poster['original']?.toString(),
            large: poster['large']?.toString(),
            medium: poster['medium']?.toString(),
          ),
          format: attributes['subtype']?.toString(),
          status: attributes['status']?.toString(),
          description: attributes['synopsis']?.toString(),
          episodes: (attributes['episodeCount'] as num?)?.toInt(),
          duration: (attributes['episodeLength'] as num?)?.toInt(),
          averageScore: rating,
          isAdult: attributes['ageRating']?.toString() == 'R18',
          siteUrl: 'https://kitsu.io/anime/${item['id']}',
        );
      }).toList();
    } catch (error) {
      AppLogger.e('Kitsu browse fallback error: $error');
      return const [];
    }
  }

  Future<List<JikanEpisode>> getEpisodes(int malId, int page) async {
    Object? lastError;
    final url = '$_baseUrl/anime/$malId/episodes?page=$page';
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await UniversalHttpClient.instance
            .get(Uri.parse(url), cacheConfig: CacheConfig.long)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> episodes = data['data'];
          return episodes.map((e) => JikanEpisode.fromJson(e)).toList();
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      }
    }
    AppLogger.e('Jikan Episodes Error: $lastError');
    return [];
  }

  Future<({Map<String, dynamic> details, List<dynamic> staff, List<dynamic> characters})?> getFullDetails(
    int malId,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final detailsResponse = await UniversalHttpClient.instance
            .get(
              Uri.parse('$_baseUrl/anime/$malId/full'),
              cacheConfig: CacheConfig.long,
            )
            .timeout(const Duration(seconds: 15));
        if (detailsResponse.statusCode != 200) {
          lastError = 'HTTP ${detailsResponse.statusCode}';
          continue;
        }
        final detailsJson = json.decode(detailsResponse.body);
        List<dynamic> staff = const [];
        try {
          final staffResponse = await UniversalHttpClient.instance
              .get(
                Uri.parse('$_baseUrl/anime/$malId/staff'),
                cacheConfig: CacheConfig.long,
              )
              .timeout(const Duration(seconds: 10));
          if (staffResponse.statusCode == 200) {
            staff = List<dynamic>.from(
              json.decode(staffResponse.body)['data'] ?? const [],
            );
          }
        } catch (_) {
          // Core details are still useful when the optional staff call fails.
        }

        List<dynamic> characters = const [];
        try {
          final charactersResponse = await UniversalHttpClient.instance
              .get(
                Uri.parse('$_baseUrl/anime/$malId/characters'),
                cacheConfig: CacheConfig.long,
              )
              .timeout(const Duration(seconds: 10));
          if (charactersResponse.statusCode == 200) {
            characters = List<dynamic>.from(
              json.decode(charactersResponse.body)['data'] ?? const [],
            );
          }
        } catch (_) {
          // Core details are still useful when the optional characters call fails.
        }

        return (
          details: Map<String, dynamic>.from(detailsJson['data'] ?? {}),
          staff: staff,
          characters: characters,
        );
      } catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      }
    }
    AppLogger.e('Jikan Full Details Error: $lastError');
    return null;
  }
}
