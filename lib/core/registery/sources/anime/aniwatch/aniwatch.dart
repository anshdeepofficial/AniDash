import 'dart:convert';
import 'package:html/dom.dart';
import 'package:ani_dash/core/models/anime/anime_model.dep.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/core/models/anime/page_model.dart';
import 'package:ani_dash/core/models/anime/server_model.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/registery/sources/anime/aniwatch/extractors.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:html/parser.dart' show parse;

class AniwatchProvider extends AnimeProvider {
  final HomeExtractor homeExtractor;
  final DetailExtractor detailExtractor;
  final WatchExtractor watchExtractor;
  final SearchExtractor searchExtractor;

  AniwatchProvider({
    String? customApiUrl,
    this.homeExtractor = const HomeExtractor(),
    this.detailExtractor = const DetailExtractor(),
    this.watchExtractor = const WatchExtractor(),
    this.searchExtractor = const SearchExtractor(),
  })
      : super(
            apiUrl: customApiUrl != null
                ? '$customApiUrl/anime/zoro'
                : "https://AniDash-aniwatch-instance.vercel.app/api/v2/hianime",
            baseUrl: 'https://hianime.in',
            providerName: 'aniwatch');

  Map<String, String> _getHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
    };
  }

  @override
  Future<HomePage> getHome() async {
    return HomePage();
  }

  @override
  Future<DetailPage> getDetails(String animeId) async {
    final response =
        await UniversalHttpClient.instance.get(Uri.parse('$baseUrl/$animeId'), headers: _getHeaders());
    final document = parse(response.body);
    return detailExtractor.parseDetail(document, baseUrl, animeId: animeId);
  }

  @override
  Future<WatchPage> getWatch(String animeId) async {
    final response = await UniversalHttpClient.instance.get(Uri.parse('$baseUrl/watch/$animeId'),
        headers: _getHeaders());
    final document = parse(response.body);
    return watchExtractor.parseWatch(document, baseUrl, animeId: animeId);
  }

  @override
  Future<BaseEpisodeModel> getEpisodes(String animeId,
      {String? anilistId, String? malId}) async {
    final response =
        await UniversalHttpClient.instance.get(Uri.parse("$apiUrl/anime/$animeId/episodes"));
    final data = jsonDecode(response.body)['data'];

    return BaseEpisodeModel(
      episodes: (data['episodes'] as List<dynamic>)
          .map((episode) => EpisodeDataModel(
              id: episode['episodeId'],
              number: episode['number'],
              title: episode['title'],
              isFiller: episode['isFiller']))
          .toList(),
      totalEpisodes: data['totalEpisodes'],
    );
  }

  String? retrieveServerId(Document document, int index, String category) {
    final serverItems = document.querySelectorAll(
        '.ps_-block.ps_-block-sub.servers-$category > .ps__-list .server-item');
    return serverItems
        .firstWhere((el) => el.attributes['data-server-id'] == index.toString())
        .attributes['data-id'];
  }

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
      );
      if (response.statusCode != 200) return BaseSourcesModel();

      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data == null) return BaseSourcesModel();

      final List rawTracks = (data['tracks'] as List?) ?? (data['subtitles'] as List?) ?? [];
      final tracks = rawTracks
          .map(
            (track) => Subtitle(
              url: track['url']?.toString(),
              lang: track['lang']?.toString(),
              isSub: track['lang'] != 'thumbnails',
            ),
          )
          .where((t) => t.url != null && t.url!.isNotEmpty)
          .toList();

      final sources = ((data['sources'] as List?) ?? [])
          .map(
            (source) => Source(
              url: source['url']?.toString(),
              isM3U8: source['isM3U8'] == true || (source['url']?.toString().contains('.m3u8') ?? false),
              quality: source['quality']?.toString() ?? 'Default',
              isDub: categoryParam == 'dub',
            ),
          )
          .where((s) => s.url != null && s.url!.isNotEmpty)
          .toList();

      return BaseSourcesModel(
        sources: sources,
        tracks: tracks,
        headers: data['headers'] is Map ? Map<String, dynamic>.from(data['headers']) : null,
      );
    } catch (_) {
      return BaseSourcesModel();
    }
  }

  @override
  Future<SearchPage> getSearch(String keyword, String? type, int page) async {
    final hianimeType =
        type != null ? _mapTypeToHianimeType(type.toLowerCase()) : null;
    final url = hianimeType != null
        ? '$apiUrl/search?q=$keyword&page=$page'
        : '$apiUrl/search?q=$keyword&page=$page';

    final response = await UniversalHttpClient.instance.get(Uri.parse(url), headers: _getHeaders());
    final data = jsonDecode(response.body)['data'];

    return SearchPage(
      totalPages: data['totalPages'],
      currentPage: data['currentPage'],
      results: (data['animes'] as List<dynamic>)
          .map((anime) => BaseAnimeModel(
                id: anime['id'],
                name: anime['name'],
                type: anime['type'],
                duration: anime['duration'],
                episodes: EpisodesModel(
                  sub: anime['episodes']['sub'],
                  dub: anime['episodes']['dub'],
                  total: anime['sub'],
                ),
                poster: anime['poster'],
              ))
          .toList(),
    );
  }

  @override
  Future<SearchPage> getPage(String route, int page) async {
    final response = await UniversalHttpClient.instance.get(Uri.parse('$baseUrl/$route?page=$page'),
        headers: _getHeaders());
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
      _ => null
    };
  }

  @override
  Future<BaseServerModel> getSupportedServers({dynamic metadata}) async {
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
