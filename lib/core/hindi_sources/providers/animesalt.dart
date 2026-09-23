import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AnimeSaltProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animesalt';

  @override
  String get name => 'AnimeSalt';

  @override
  String get baseUrl => 'https://animesalt.cc';

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsDownloads => true;

  @override
  bool get supportsMultiAudio => true;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  Map<String, String> get _defaultHeaders => {
        'User-Agent': _userAgent,
        'Referer': '$baseUrl/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      };

  @override
  Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 5));
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  String _cleanSearchTitle(String title) {
    var clean = title.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    clean = clean.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    return clean.replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Future<String?> findAnime({
    required String title,
    String? romajiTitle,
    int? anilistId,
    int? malId,
    int? year,
  }) async {
    final searchTerms = <String>[];
    final cleanTitle = _cleanSearchTitle(title);
    searchTerms.add(cleanTitle);
    if (romajiTitle != null && romajiTitle.isNotEmpty) {
      final cleanRomaji = _cleanSearchTitle(romajiTitle);
      if (!searchTerms.contains(cleanRomaji)) searchTerms.add(cleanRomaji);
    }

    for (final term in searchTerms) {
      try {
        AppLogger.d('[Hindi] AnimeSalt searching for: $term');
        final searchUrl = Uri.parse('$baseUrl/search').replace(
          queryParameters: {'keyword': term},
        );

        final res = await http
            .get(searchUrl, headers: _defaultHeaders)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final doc = html_parser.parse(res.body);
          // Look for anime cards/links in search results
          final links = doc.querySelectorAll('a[href*="/anime/"], a[href*="/watch/"]');
          for (final a in links) {
            final linkTitle = a.text.trim().toLowerCase();
            final href = a.attributes['href'];
            if (href != null && href.isNotEmpty) {
              if (linkTitle.contains(term.toLowerCase()) ||
                  term.toLowerCase().contains(linkTitle) ||
                  links.length == 1) {
                final fullPath = href.startsWith('http') ? href : '$baseUrl$href';
                AppLogger.success('[Hindi] AnimeSalt matched anime: $fullPath');
                return fullPath;
              }
            }
          }

          // Fallback: Check first card result
          if (links.isNotEmpty) {
            final firstHref = links.first.attributes['href'];
            if (firstHref != null && firstHref.isNotEmpty) {
              final fullPath = firstHref.startsWith('http') ? firstHref : '$baseUrl$firstHref';
              AppLogger.i('[Hindi] AnimeSalt using first search match: $fullPath');
              return fullPath;
            }
          }
        }
      } catch (e) {
        AppLogger.w('[Hindi] AnimeSalt search error for $term: $e');
      }
    }
    return null;
  }

  @override
  Future<BaseSourcesModel?> resolveEpisode({
    required String providerAnimeId,
    required int episodeNumber,
    String? animeTitle,
  }) async {
    try {
      AppLogger.d(
        '[Hindi] AnimeSalt resolving $animeTitle Ep $episodeNumber from $providerAnimeId',
      );

      // Construct target episode page URL
      String targetUrl = providerAnimeId;
      if (!targetUrl.contains('episode-') && !targetUrl.contains('ep-')) {
        final uri = Uri.parse(providerAnimeId);
        final segments = List<String>.from(uri.pathSegments);
        if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
        if (segments.isNotEmpty) {
          final slug = segments.last;
          targetUrl = '$baseUrl/watch/$slug/episode-$episodeNumber';
        }
      }

      var res = await http
          .get(Uri.parse(targetUrl), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 && targetUrl != providerAnimeId) {
        // Fallback to providerAnimeId directly
        res = await http
            .get(Uri.parse(providerAnimeId), headers: _defaultHeaders)
            .timeout(const Duration(seconds: 10));
      }

      if (res.statusCode != 200) {
        AppLogger.w('[Hindi] AnimeSalt episode page returned ${res.statusCode}');
        return null;
      }

      final body = res.body;

      // 1. Look for direct m3u8 in page scripts or iframes
      final m3u8Match = RegExp(r'''(?:file|source|src)\s*:\s*["']([^"']+\.m3u8[^"']*)["']''', caseSensitive: false)
          .firstMatch(body);

      String? streamUrl = m3u8Match?.group(1);

      // 2. Look for iframe player src
      if (streamUrl == null) {
        final iframeMatch = RegExp(r'''<iframe[^>]+src=["']([^"']+)["']''', caseSensitive: false)
            .firstMatch(body);
        if (iframeMatch != null) {
          final iframeSrc = iframeMatch.group(1)!;
          final resolvedIframe = iframeSrc.startsWith('http')
              ? iframeSrc
              : (iframeSrc.startsWith('//') ? 'https:$iframeSrc' : '$baseUrl$iframeSrc');

          try {
            final iframeRes = await http
                .get(Uri.parse(resolvedIframe), headers: {
                  ..._defaultHeaders,
                  'Referer': targetUrl,
                })
                .timeout(const Duration(seconds: 6));
            if (iframeRes.statusCode == 200) {
              final iframeM3u8 = RegExp(r'''["']([^"']+\.m3u8[^"']*)["']''')
                  .firstMatch(iframeRes.body);
              streamUrl = iframeM3u8?.group(1);
            }
          } catch (_) {}
        }
      }

      // 3. Look for direct mp4 links
      if (streamUrl == null) {
        final mp4Match = RegExp(r'''["']([^"']+\.mp4[^"']*)["']''', caseSensitive: false)
            .firstMatch(body);
        streamUrl = mp4Match?.group(1);
      }

      if (streamUrl != null && streamUrl.isNotEmpty) {
        final isM3U8 = streamUrl.contains('.m3u8');
        final sources = [
          Source(
            url: streamUrl,
            quality: 'Hindi (Multi-Audio)',
            isM3U8: isM3U8,
            isDub: false,
            headers: {
              'User-Agent': _userAgent,
              'Referer': targetUrl,
            },
          ),
        ];

        AppLogger.success(
          '[Hindi] AnimeSalt successfully resolved stream for Ep $episodeNumber',
        );
        return BaseSourcesModel(
          sources: sources,
          headers: {'User-Agent': _userAgent, 'Referer': targetUrl},
        );
      }
    } catch (e) {
      AppLogger.w('[Hindi] AnimeSalt resolveEpisode error: $e');
    }
    return null;
  }

  @override
  Future<String?> resolveDownload({
    required String providerAnimeId,
    required int episodeNumber,
    String? quality,
  }) async {
    final streamData = await resolveEpisode(
      providerAnimeId: providerAnimeId,
      episodeNumber: episodeNumber,
    );
    return streamData?.sources.firstOrNull?.url;
  }
}
