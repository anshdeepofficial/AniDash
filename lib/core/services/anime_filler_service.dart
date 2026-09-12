import 'package:ani_dash/core/jikan/jikan_service.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AnimeFillerInfo {
  final Set<int> fillers;
  final Set<int> mixed;

  const AnimeFillerInfo({
    this.fillers = const {},
    this.mixed = const {},
  });
}

class AnimeFillerService {
  static final AnimeFillerService _instance = AnimeFillerService._internal();
  factory AnimeFillerService() => _instance;
  AnimeFillerService._internal();

  final Map<String, AnimeFillerInfo> _cache = {};
  final JikanService _jikan = JikanService();

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  /// Returns full filler and mixed canon/filler info for the specified anime.
  Future<AnimeFillerInfo> getFillerInfo({
    required String title,
    int? malId,
    List<String> alternateTitles = const [],
  }) async {
    final cacheKey = title.trim().toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 1. Try AnimeFillerList (fastest, most accurate, 1 request)
    final aflInfo = await _fetchFromAnimeFillerList(
      title,
      alternateTitles: alternateTitles,
    );
    if (aflInfo.fillers.isNotEmpty || aflInfo.mixed.isNotEmpty) {
      _cache[cacheKey] = aflInfo;
      AppLogger.success(
        '[AnimeFillerService] Found ${aflInfo.fillers.length} fillers and ${aflInfo.mixed.length} mixed episodes from AnimeFillerList for "$title"',
      );
      return aflInfo;
    }

    // 2. Fallback to Jikan if MAL ID is available
    if (malId != null && malId > 0) {
      final jikanFillers = await _fetchFromJikan(malId);
      if (jikanFillers.isNotEmpty) {
        final jikanInfo = AnimeFillerInfo(fillers: jikanFillers);
        _cache[cacheKey] = jikanInfo;
        AppLogger.success(
          '[AnimeFillerService] Found ${jikanFillers.length} filler episodes from Jikan for MAL ID: $malId',
        );
        return jikanInfo;
      }
    }

    const empty = AnimeFillerInfo();
    _cache[cacheKey] = empty;
    return empty;
  }

  /// Returns the set of episode numbers that are identified as filler.
  Future<Set<int>> getFillerEpisodes({
    required String title,
    int? malId,
    List<String> alternateTitles = const [],
  }) async {
    final info = await getFillerInfo(
      title: title,
      malId: malId,
      alternateTitles: alternateTitles,
    );
    return info.fillers;
  }

  Future<AnimeFillerInfo> _fetchFromAnimeFillerList(
    String title, {
    List<String> alternateTitles = const [],
  }) async {
    final candidateSlugs = _generateSlugs([title, ...alternateTitles]);

    for (final slug in candidateSlugs) {
      try {
        final url = Uri.parse('https://www.animefillerlist.com/shows/$slug');
        final response = await UniversalHttpClient.instance
            .get(url, headers: _headers, cacheConfig: CacheConfig.long)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) continue;

        final body = response.body;
        if (!body.contains('EpisodeList')) continue;

        final regex = RegExp(
          r'<tr class="([^"]*)" id="eps-(\d+)">.*?<td class="Type"><span>([^<]+)</span></td>',
          dotAll: true,
        );
        final matches = regex.allMatches(body);
        if (matches.isEmpty) continue;

        final fillers = <int>{};
        final mixed = <int>{};
        for (final m in matches) {
          final rowClass = (m.group(1) ?? '').toLowerCase();
          final epNum = int.tryParse(m.group(2) ?? '') ?? 0;
          final type = (m.group(3) ?? '').toLowerCase();

          if (rowClass.contains('mixed') || type.contains('mixed')) {
            mixed.add(epNum);
          } else if (rowClass.contains('filler') || type.contains('filler')) {
            fillers.add(epNum);
          }
        }

        if (fillers.isNotEmpty || mixed.isNotEmpty) {
          return AnimeFillerInfo(fillers: fillers, mixed: mixed);
        }
      } catch (e) {
        AppLogger.d('[AnimeFillerService] AFL probe failed for slug "$slug": $e');
      }
    }

    return const AnimeFillerInfo();
  }

  List<String> _generateSlugs(List<String> titles) {
    final slugs = <String>{};

    for (final raw in titles) {
      if (raw.trim().isEmpty) continue;

      // Clean brackets, suffixes, Dub/Sub markers
      var cleaned = raw
          .replaceAll(
            RegExp(
              r'\s*\((?:dub|sub|tv|audio|uncensored|season\s*\d*)[^)]*\)',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\s*\[(?:dub|sub|tv|audio|uncensored)[^\]]*\]',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s*-\s*(?:dub|sub)$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[:!]'), '')
          .toLowerCase()
          .trim();

      String toSlug(String s) => s
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');

      final baseSlug = toSlug(cleaned);
      if (baseSlug.isNotEmpty) {
        slugs.add(baseSlug);
      }

      // Specific popular series variations
      if (baseSlug.contains('shippuden') && !baseSlug.startsWith('naruto-')) {
        slugs.add('naruto-shippuden');
      }
      if (baseSlug.contains('bleach') && baseSlug != 'bleach') {
        slugs.add('bleach');
      }
      if (baseSlug.contains('one-piece') && baseSlug != 'one-piece') {
        slugs.add('one-piece');
      }
      if (baseSlug.contains('fairy-tail') && baseSlug != 'fairy-tail') {
        slugs.add('fairy-tail');
      }
      if (baseSlug.contains('boruto')) {
        slugs.add('boruto-naruto-next-generations');
      }
      if (baseSlug.contains('conan') || baseSlug.contains('case-closed')) {
        slugs.add('detective-conan');
      }
    }

    return slugs.toList();
  }

  Future<Set<int>> _fetchFromJikan(int malId) async {
    final fillers = <int>{};
    try {
      int page = 1;
      while (page <= 15) {
        final jikanEpisodes = await _jikan
            .getEpisodes(malId, page)
            .timeout(const Duration(seconds: 10));

        if (jikanEpisodes.isEmpty) break;

        for (final ep in jikanEpisodes) {
          if (ep.filler) {
            fillers.add(ep.malId);
          }
        }

        if (jikanEpisodes.length < 100) break;
        page++;
        // Throttle to respect Jikan's rate limit of 3 requests per second
        await Future.delayed(const Duration(milliseconds: 350));
      }
    } catch (e) {
      AppLogger.d('[AnimeFillerService] Jikan fallback failed: $e');
    }
    return fillers;
  }
}
