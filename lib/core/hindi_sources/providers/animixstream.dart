import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AnimixStreamProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animixstream';

  @override
  String get name => 'AnimixStream';

  @override
  String get baseUrl => 'https://animixstream.com';

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsDownloads => false;

  @override
  bool get supportsMultiAudio => true;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  Map<String, String> get _defaultHeaders => {
        'User-Agent': _userAgent,
        'Referer': '$baseUrl/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
        AppLogger.d('[Hindi] AnimixStream searching: $term');
        final searchUrl = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(term)}');
        final res = await http
            .get(searchUrl, headers: _defaultHeaders)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final doc = html_parser.parse(res.body);
          final links = doc.querySelectorAll('a[href*="/anime/"], a[href*="/v/"]');
          for (final a in links) {
            final linkTitle = a.text.trim().toLowerCase();
            final href = a.attributes['href'];
            if (href != null && href.isNotEmpty) {
              if (linkTitle.contains(term.toLowerCase()) ||
                  term.toLowerCase().contains(linkTitle) ||
                  links.length == 1) {
                final fullPath = href.startsWith('http') ? href : '$baseUrl$href';
                AppLogger.success('[Hindi] AnimixStream matched anime: $fullPath');
                return fullPath;
              }
            }
          }
          if (links.isNotEmpty) {
            final firstHref = links.first.attributes['href'];
            if (firstHref != null && firstHref.isNotEmpty) {
              final fullPath = firstHref.startsWith('http') ? firstHref : '$baseUrl$firstHref';
              return fullPath;
            }
          }
        }
      } catch (e) {
        AppLogger.w('[Hindi] AnimixStream search error for $term: $e');
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
        '[Hindi] AnimixStream resolving $animeTitle Ep $episodeNumber from $providerAnimeId',
      );

      String targetUrl = providerAnimeId;
      if (!targetUrl.contains('ep') && !targetUrl.contains('episode')) {
        final uri = Uri.parse(providerAnimeId);
        final slug = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
        targetUrl = '$baseUrl/v/$slug/ep-$episodeNumber';
      }

      var res = await http
          .get(Uri.parse(targetUrl), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200 && targetUrl != providerAnimeId) {
        res = await http
            .get(Uri.parse(providerAnimeId), headers: _defaultHeaders)
            .timeout(const Duration(seconds: 8));
      }

      if (res.statusCode != 200) return null;

      final body = res.body;

      // Extract m3u8 or player iframe
      final m3u8Match = RegExp(r'''(?:file|source|src)\s*:\s*["']([^"']+\.m3u8[^"']*)["']''', caseSensitive: false)
          .firstMatch(body);

      String? streamUrl = m3u8Match?.group(1);

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

      if (streamUrl != null && streamUrl.isNotEmpty) {
        final sources = [
          Source(
            url: streamUrl,
            quality: 'Animix Multi-Audio (Hindi)',
            isM3U8: streamUrl.contains('.m3u8'),
            isDub: false,
            headers: {
              'User-Agent': _userAgent,
              'Referer': targetUrl,
            },
          ),
        ];

        AppLogger.success(
          '[Hindi] AnimixStream successfully resolved stream for Ep $episodeNumber',
        );
        return BaseSourcesModel(
          sources: sources,
          headers: {'User-Agent': _userAgent, 'Referer': targetUrl},
        );
      }
    } catch (e) {
      AppLogger.w('[Hindi] AnimixStream resolveEpisode error: $e');
    }
    return null;
  }

  @override
  Future<String?> resolveDownload({
    required String providerAnimeId,
    required int episodeNumber,
    String? quality,
  }) async {
    return null;
  }
}
