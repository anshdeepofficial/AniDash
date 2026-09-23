import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AnimeLokProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animelok';

  @override
  String get name => 'AnimeLok (Experimental)';

  @override
  String get baseUrl => 'https://animelok.org';

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsDownloads => false;

  @override
  bool get supportsMultiAudio => false;

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
          .timeout(const Duration(seconds: 4));
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
        AppLogger.d('[Hindi] AnimeLok searching: $term');
        final searchUrl = Uri.parse('$baseUrl/?s=${Uri.encodeComponent(term)}');
        final res = await http
            .get(searchUrl, headers: _defaultHeaders)
            .timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          final doc = html_parser.parse(res.body);
          final links = doc.querySelectorAll('a[href*="/series/"], a[href*="/anime/"]');
          for (final a in links) {
            final linkTitle = a.text.trim().toLowerCase();
            final href = a.attributes['href'];
            if (href != null && href.isNotEmpty) {
              if (linkTitle.contains(term.toLowerCase()) ||
                  term.toLowerCase().contains(linkTitle) ||
                  links.length == 1) {
                AppLogger.success('[Hindi] AnimeLok matched anime: $href');
                return href;
              }
            }
          }
          if (links.isNotEmpty) {
            final firstHref = links.first.attributes['href'];
            if (firstHref != null && firstHref.isNotEmpty) return firstHref;
          }
        }
      } catch (e) {
        AppLogger.w('[Hindi] AnimeLok search error for $term: $e');
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
        '[Hindi] AnimeLok resolving $animeTitle Ep $episodeNumber from $providerAnimeId',
      );

      final res = await http
          .get(Uri.parse(providerAnimeId), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;

      final body = res.body;
      final m3u8Match = RegExp(
        r'''(?:file|source|src)\s*:\s*["']([^"']+\.m3u8[^"']*)["']''',
        caseSensitive: false,
      ).firstMatch(body);

      final streamUrl = m3u8Match?.group(1);

      if (streamUrl != null && streamUrl.isNotEmpty) {
        final sources = [
          Source(
            url: streamUrl,
            quality: 'AnimeLok (Hindi Dub)',
            isM3U8: true,
            isDub: false,
            headers: {
              'User-Agent': _userAgent,
              'Referer': providerAnimeId,
            },
          ),
        ];

        AppLogger.success(
          '[Hindi] AnimeLok successfully resolved stream for Ep $episodeNumber',
        );
        return BaseSourcesModel(
          sources: sources,
          headers: {'User-Agent': _userAgent, 'Referer': providerAnimeId},
        );
      }
    } catch (e) {
      AppLogger.w('[Hindi] AnimeLok resolveEpisode error: $e');
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
