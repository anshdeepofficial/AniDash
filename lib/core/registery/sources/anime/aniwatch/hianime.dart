import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:html/dom.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/core/models/anime/page_model.dart';
import 'package:ani_dash/core/models/anime/server_model.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/registery/sources/anime/aniwatch/extractors.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/utils/env_loader.dart';
import 'package:html/parser.dart' show parse;

class HiAnimeProvider extends AnimeProvider {
  final HomeExtractor homeExtractor;
  final DetailExtractor detailExtractor;
  final WatchExtractor watchExtractor;
  final SearchExtractor searchExtractor;

  HiAnimeProvider({
    String? customApiUrl,
    this.homeExtractor = const HomeExtractor(),
    this.detailExtractor = const DetailExtractor(),
    this.watchExtractor = const WatchExtractor(),
    this.searchExtractor = const SearchExtractor(),
  }) : super(
        apiUrl: (customApiUrl != null && customApiUrl.isNotEmpty)
            ? customApiUrl
            : (API_URL.isNotEmpty
                ? API_URL
                : "https://shonenx-aniwatch-instance.vercel.app/api/v2/hianime"),
        baseUrl: 'https://hianimez.to',
        providerName: 'hianime',
      );

  @override
  Map<String, String> get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
  };

  @override
  Future<HomePage> getHome() async {
    return HomePage();
    // final response =
    //     await UniversalHttpClient.instance.get(Uri.parse('$baseUrl/home'), headers: headers);

    // final document = parse(response.body);
    // return HomePage(
    //   spotlight: parseSpotlight(document, baseUrl),
    //   trending: parseTrending(document, baseUrl),
    //   featured: parseFeatured(document, baseUrl),
    // );
  }

  @override
  Future<DetailPage> getDetails(String animeId) async {
    final response = await UniversalHttpClient.instance.get(
      Uri.parse('$baseUrl/$animeId'),
      headers: headers,
    );
    final document = parse(response.body);
    return detailExtractor.parseDetail(document, baseUrl, animeId: animeId);
  }

  @override
  Future<WatchPage> getWatch(String animeId) async {
    final response = await UniversalHttpClient.instance.get(
      Uri.parse('$baseUrl/watch/$animeId'),
      headers: headers,
    );
    final document = parse(response.body);
    return watchExtractor.parseWatch(document, baseUrl, animeId: animeId);
  }

  // @override
  // Future<BaseEpisodeModel> getEpisodes(String animeId) async {

  //   final response = await UniversalHttpClient.instance.get(
  //       Uri.parse("$baseUrl/ajax/v2/episode/list/${animeId.split('-').last}"),
  //       headers: headers);

  //   final document = parse(json.decode(response.body)['html']);
  //   return parseEpisodes(document, "$baseUrl/ajax/v2/episode/list/",
  //       animeId: animeId);
  // }
  String _sanitizeEpisodeId(String animeId, String episodeId) {
    if (episodeId.isEmpty) return animeId;
    if (episodeId.startsWith('$animeId?')) return episodeId;
    if (episodeId.contains('?ep=')) {
      if (episodeId.startsWith(animeId)) return episodeId;
      return '$animeId?$episodeId';
    }
    if (episodeId.startsWith('?')) return '$animeId$episodeId';
    return '$animeId?$episodeId';
  }

  @override
  Future<BaseEpisodeModel> getEpisodes(
    String animeId, {
    String? anilistId,
    String? malId,
  }) async {
    try {
      final response = await UniversalHttpClient.instance.get(
        Uri.parse('$apiUrl/anime/$animeId/episodes'),
        cacheConfig: CacheConfig.medium,
      );
      if (response.statusCode != 200) {
        return BaseEpisodeModel(episodes: [], totalEpisodes: 0);
      }
      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data == null || data['episodes'] == null) {
        return BaseEpisodeModel(episodes: [], totalEpisodes: 0);
      }

      return BaseEpisodeModel(
        episodes: (data['episodes'] as List<dynamic>)
            .map(
              (episode) => EpisodeDataModel(
                id: episode['episodeId']?.toString(),
                number: (episode['number'] as num?)?.toInt() ?? 0,
                title: episode['title']?.toString(),
                isFiller: episode['isFiller'] == true,
              ),
            )
            .toList(),
        totalEpisodes: (data['totalEpisodes'] as num?)?.toInt() ?? 0,
      );
    } catch (e, st) {
      AppLogger.e('HiAnime getEpisodes failed: $e\n$st');
      return BaseEpisodeModel(episodes: [], totalEpisodes: 0);
    }
  }

  String? retrieveServerId(Document document, int index, String category) {
    final serverItems = document.querySelectorAll(
      '.ps_-block.ps_-block-sub.servers-$category > .ps__-list .server-item',
    );
    return serverItems
        .firstWhereOrNull((el) => el.attributes['data-server-id'] == index.toString())
        ?.attributes['data-id'];
  }

  @override
  Future<BaseSourcesModel> getSources(
    String animeId,
    String episodeId,
    String? serverName,
    String? category,
  ) async {
    final actualEpisodeId = _sanitizeEpisodeId(animeId, episodeId);
    final categoryParam = (category?.toLowerCase() == 'dub') ? 'dub' : 'sub';
    final serverParam = (serverName != null && serverName.isNotEmpty) ? serverName : 'hd-1';

    try {
      final response = await UniversalHttpClient.instance.get(
        Uri.parse(
          '$apiUrl/episode/sources?animeEpisodeId=$actualEpisodeId&server=$serverParam&category=$categoryParam',
        ),
        cacheConfig: CacheConfig.veryLong,
      );

      if (response.statusCode != 200) {
        AppLogger.w('HiAnime getSources returned status ${response.statusCode}');
        return BaseSourcesModel();
      }

      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data == null) return BaseSourcesModel();

      final List rawTracks = (data['tracks'] as List?) ?? (data['subtitles'] as List?) ?? [];
      final tracks = rawTracks
          .map(
            (t) => Subtitle(
              url: t['url']?.toString(),
              lang: t['lang']?.toString(),
              isSub: t['lang'] != 'thumbnails' && t['kind'] != 'thumbnails',
            ),
          )
          .where((t) => t.url != null && t.url!.isNotEmpty)
          .toList();

      final preview = tracks.firstWhereOrNull((t) => t.isSub == false || t.lang?.toLowerCase() == 'thumbnails');

      Intro? intro;
      if (data['intro'] is Map) {
        intro = Intro(
          start: (data['intro']['start'] as num?)?.toInt(),
          end: (data['intro']['end'] as num?)?.toInt(),
        );
      }

      Intro? outro;
      if (data['outro'] is Map) {
        outro = Intro(
          start: (data['outro']['start'] as num?)?.toInt(),
          end: (data['outro']['end'] as num?)?.toInt(),
        );
      }

      final sources = ((data['sources'] as List?) ?? [])
          .map(
            (source) => Source(
              url: source['url']?.toString(),
              isM3U8: source['isM3U8'] == true || (source['url']?.toString().contains('.m3u8') ?? false),
              quality: source['quality']?.toString() ?? 'Auto',
              type: source['type']?.toString(),
              isDub: categoryParam == 'dub',
            ),
          )
          .where((s) => s.url != null && s.url!.isNotEmpty)
          .toList();

      return BaseSourcesModel(
        headers: data['headers'] is Map ? Map<String, dynamic>.from(data['headers']) : null,
        preview: preview,
        intro: intro,
        outro: outro,
        sources: sources,
        anilistID: (data['anilistID'] as num?)?.toInt(),
        malID: (data['malID'] as num?)?.toInt(),
        tracks: tracks.where((t) => t.isSub == true).toList(),
      );
    } catch (e, st) {
      AppLogger.e('HiAnime getSources error: $e\n$st');
      return BaseSourcesModel();
    }
  }

  @override
  Future<SearchPage> getSearch(String keyword, String? type, int page) async {
    final hianimeType = type != null
        ? _mapTypeToHianimeType(type.toLowerCase())
        : null;
    final url = hianimeType != null
        ? '$baseUrl/search?keyword=$keyword&type=$hianimeType&page=$page'
        : '$baseUrl/search?keyword=$keyword&page=$page';
    final response = await UniversalHttpClient.instance.get(
      Uri.parse(url),
      headers: headers,
    );
    final document = parse(response.body);
    return searchExtractor.parseSearch(document, baseUrl, keyword: keyword, page: page);
  }

  @override
  Future<SearchPage> getPage(String route, int page) async {
    final response = await UniversalHttpClient.instance.get(
      Uri.parse('$baseUrl/$route?page=$page'),
      headers: headers,
    );
    final document = parse(response.body);
    return searchExtractor.parsePage(document, baseUrl, route: route, page: page);
  }

  int? _mapTypeToHianimeType(String type) {
    return switch (type) {
      'movie' => 1,
      'tv' => 2,
      'ova' => 3,
      'ona' => 4,
      'special' => 5,
      'music' => 6,
      _ => null,
    };
  }

  @override
  Future<BaseServerModel> getSupportedServers({dynamic metadata}) async {
    try {
      final animeId = metadata?['id']?.toString() ?? '';
      final episodeId = metadata?['epId']?.toString() ?? '';

      if (animeId.isNotEmpty) {
        final actualEpisodeId = _sanitizeEpisodeId(animeId, episodeId);
        final res = await UniversalHttpClient.instance.get(
          Uri.parse('$apiUrl/episode/servers?animeEpisodeId=$actualEpisodeId'),
          cacheConfig: CacheConfig.veryLong,
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final sub = data['data']?['sub'] as List?;
          final dub = data['data']?['dub'] as List?;

          final subServers = sub
                  ?.map(
                    (server) => ServerData(
                      id: server['serverName']?.toString() ?? server['serverId']?.toString(),
                      name: server['serverName']?.toString() ?? server['serverId']?.toString(),
                      isDub: false,
                    ),
                  )
                  .toList() ??
              [];

          final dubServers = dub
                  ?.map(
                    (server) => ServerData(
                      id: server['serverName']?.toString() ?? server['serverId']?.toString(),
                      name: server['serverName']?.toString() ?? server['serverId']?.toString(),
                      isDub: true,
                    ),
                  )
                  .toList() ??
              [];

          if (subServers.isNotEmpty || dubServers.isNotEmpty) {
            return BaseServerModel(sub: subServers, dub: dubServers);
          }
        }
      }
    } catch (e, st) {
      AppLogger.e('HiAnime getSupportedServers error: $e\n$st');
    }

    return BaseServerModel(
      sub: [
        ServerData(id: 'hd-1', name: 'HD-1', isDub: false),
        ServerData(id: 'hd-2', name: 'HD-2', isDub: false),
        ServerData(id: 'megacloud', name: 'Megacloud', isDub: false),
      ],
      dub: [
        ServerData(id: 'hd-1', name: 'HD-1', isDub: true),
        ServerData(id: 'hd-2', name: 'HD-2', isDub: true),
        ServerData(id: 'megacloud', name: 'Megacloud', isDub: true),
      ],
    );
  }
}
