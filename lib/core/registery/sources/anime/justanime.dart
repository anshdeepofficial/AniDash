import 'dart:convert';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/models/anime/anime_model.dep.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/core/models/anime/page_model.dart';
import 'package:ani_dash/core/models/anime/server_model.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';

class JustAnimeProvider extends AnimeProvider {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36';

  final Map<String, String> _sourceHeaders = {
    'Origin': 'https://justanime.to',
    'Referer': 'https://justanime.to/',
    'User-Agent': _userAgent,
  };

  JustAnimeProvider()
    : super(
        baseUrl: "https://justanime.to",
        apiUrl: "https://core.justanime.to/api",
        providerName: "justanime",
      );

  @override
  Map<String, String> get headers => _sourceHeaders;

  @override
  Future<DetailPage> getDetails(String animeId) {
    throw UnimplementedError();
  }

  @override
  Future<HomePage> getHome() {
    throw UnimplementedError();
  }

  @override
  Future<SearchPage> getPage(String route, int page) {
    throw UnimplementedError();
  }

  @override
  Future<SearchPage> getSearch(String keyword, String? type, int page) async {
    final url = Uri.parse('$apiUrl/search').replace(
      queryParameters: {'query': keyword.replaceAll('-', ' '), 'page': '$page'},
    );
    final res = await UniversalHttpClient.instance
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> decoded = json.decode(res.body);
    final results = (decoded['results'] as List<dynamic>? ?? const []);
    return SearchPage(
      results:
          results.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final title = Map<String, dynamic>.from(
              item['title'] as Map? ?? {},
            );
            return BaseAnimeModel(
              id: item['id']?.toString(),
              anilistId: int.tryParse(item['id']?.toString() ?? ''),
              name: title['english'] ?? title['romaji'] ?? 'Unknown',
              jname: title['romaji'],
              type: item['type'],
              poster: item['cover'],
              releaseDate: item['year']?.toString(),
              number: item['episodes'],
            );
          }).toList(),
    );
  }

  @override
  Future<BaseEpisodeModel> getEpisodes(
    String animeId, {
    String? anilistId,
    String? malId,
  }) async {
    Future<Map<String, dynamic>> fetchPage(int page) async {
      final response = await UniversalHttpClient.instance
          .get(
            Uri.parse('$apiUrl/anime/$animeId/episodes?page=$page'),
            headers: headers,
            cacheConfig: CacheConfig.short,
          )
          .timeout(const Duration(seconds: 25));
      return Map<String, dynamic>.from(json.decode(response.body) as Map);
    }

    final first = await fetchPage(1);
    final pages = <Map<String, dynamic>>[first];
    final firstEps = first['episodes'] as List<dynamic>? ?? const [];

    int? totalPages = (first['totalPages'] as num?)?.toInt();
    if (totalPages == null && first['pageInfo'] is Map) {
      totalPages = (first['pageInfo']['lastPage'] as num?)?.toInt();
    }

    if (totalPages != null && totalPages > 1) {
      pages.addAll(
        await Future.wait([
          for (var page = 2; page <= totalPages; page++) fetchPage(page),
        ]),
      );
    } else if (firstEps.length >= 100) {
      // Loop until less than 100 items or empty (up to max 25 pages)
      int currentPage = 2;
      while (currentPage <= 25) {
        try {
          final next = await fetchPage(currentPage);
          final nextEps = next['episodes'] as List<dynamic>? ?? const [];
          if (nextEps.isEmpty) break;
          pages.add(next);
          if (nextEps.length < 100) break;
          currentPage++;
        } catch (_) {
          break;
        }
      }
    }

    final episodes =
        pages
            .expand((page) => page['episodes'] as List<dynamic>? ?? const [])
            .map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final number = (item['number'] as num?)?.toInt();
              return EpisodeDataModel(
                id: number?.toString(),
                number: number,
                title: item['title'] ?? 'Episode ${number ?? ''}',
                thumbnail: item['image'],
                description: item['description'],
                date: item['airDate'],
                isFiller: item['filler'] == true,
              );
            })
            .where((episode) => episode.number != null)
            .toList()
          ..sort((a, b) => a.number!.compareTo(b.number!));
    return BaseEpisodeModel(episodes: episodes, totalEpisodes: episodes.length);
  }

  @override
  Future<BaseSourcesModel> getSources(
    String animeId,
    String episodeId,
    String? serverName,
    String? category,
  ) async {
    final rawEp = episodeId.split('+').last.replaceAll(RegExp(r'[^0-9]'), '');
    final episode = int.tryParse(rawEp) ?? int.tryParse(episodeId);
    if (episode == null) throw Exception('Invalid episode ID: $episodeId');
    final audio = category?.toLowerCase() == 'dub' ? 'dub' : 'sub';

    Future<Map<String, dynamic>?> request(String path) async {
      try {
        final response = await UniversalHttpClient.instance
            .get(Uri.parse('$apiUrl$path'), headers: headers)
            .timeout(const Duration(seconds: 25));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final decoded = json.decode(response.body);
        if (decoded is! Map || decoded['error'] != null) return null;
        return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }

    // Default to AniNeko (HLS .m3u8 with subtitles, fast start) and fallback to AnimeGG (direct MP4)
    final preferAnimeGG = serverName?.toLowerCase().contains('animegg') == true;
    final endpoints =
        preferAnimeGG
            ? [
              '/watch/$animeId/episode/$episode/animegg',
              '/watch/$animeId/episode/$episode/anineko/$audio',
            ]
            : [
              '/watch/$animeId/episode/$episode/anineko/$audio',
              '/watch/$animeId/episode/$episode/animegg',
            ];

    for (final endpoint in endpoints) {
      final payload = await request(endpoint);
      if (payload == null) continue;
      final raw =
          endpoint.contains('animegg')
              ? payload[audio] as Map<String, dynamic>?
              : payload;
      if (raw == null) continue;

      final commonHeaders = Map<String, String>.from(
        (raw['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            (payload['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
      );

      final sources =
          (raw['sources'] as List<dynamic>? ?? const [])
              .map((value) {
                final item = Map<String, dynamic>.from(value as Map);
                final sourceHeaders = Map<String, String>.from(
                  (item['headers'] as Map?)?.map(
                        (key, value) =>
                            MapEntry(key.toString(), value.toString()),
                      ) ??
                      commonHeaders,
                );
                final urlStr = item['url']?.toString() ?? '';
                return Source(
                  url: urlStr,
                  quality: item['quality']?.toString() ?? 'Auto',
                  isM3U8:
                      item['isM3U8'] == true || urlStr.contains('.m3u8'),
                  isDub: audio == 'dub',
                  type: endpoint.contains('animegg') ? 'AnimeGG' : 'AniNeko',
                  headers: sourceHeaders,
                );
              })
              .where((source) => source.url?.isNotEmpty == true)
              .toList();

      if (sources.isEmpty) continue;

      final tracks =
          (raw['subtitles'] as List<dynamic>? ??
                  raw['tracks'] as List<dynamic>? ??
                  payload['subtitles'] as List<dynamic>? ??
                  const [])
              .map((value) {
                final item = Map<String, dynamic>.from(value as Map);
                return Subtitle(
                  url: (item['url'] ?? item['file'])?.toString(),
                  lang:
                      (item['lang'] ?? item['label'])?.toString() ??
                      'English',
                  isSub: true,
                );
              })
              .where((track) => track.url?.isNotEmpty == true)
              .toList();

      return BaseSourcesModel(
        sources: sources,
        tracks: tracks,
        headers: commonHeaders,
        intro: Intro(start: 0, end: 0),
        outro: Intro(start: 0, end: 0),
      );
    }
    throw Exception('No playable JustAnime source found for episode $episode');
  }

  @override
  Future<BaseServerModel> getSupportedServers({dynamic metadata}) async {
    final subServers = [
      ServerData(name: "AniNeko (HLS)", id: "anineko", isDub: false),
      ServerData(name: "AnimeGG (MP4)", id: "animegg", isDub: false),
    ];

    final dubServers = [
      ServerData(name: "AniNeko (HLS)", id: "anineko", isDub: true),
      ServerData(name: "AnimeGG (MP4)", id: "animegg", isDub: true),
    ];

    return BaseServerModel(sub: subServers, dub: dubServers);
  }

  @override
  Future<WatchPage> getWatch(String animeId) {
    throw UnimplementedError();
  }
}
