import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AnimixStreamProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animixstream';

  @override
  String get name => 'AnimixStream';

  static const String _defaultBaseUrl = 'https://animixstream.com';
  String _baseUrl = _defaultBaseUrl;
  List<String> _mirrors = const [_defaultBaseUrl];

  @override
  String get baseUrl => _baseUrl;

  @override
  List<String> get mirrors => _mirrors;

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsDownloads => true;

  @override
  bool get supportsMultiAudio => true;

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  @override
  void configure(HindiSourceModel model) {
    if (model.baseUrl.isNotEmpty) _baseUrl = model.baseUrl;
    if (model.mirrors.isNotEmpty) _mirrors = model.mirrors;
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: {'User-Agent': _ua},
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> findAnime({
    required String title,
    String? romajiTitle,
    int? anilistId,
    int? malId,
    int? year,
  }) async {
    final cleanQ = title
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanQ.isEmpty) return null;

    final url = '$_baseUrl/search?q=${Uri.encodeComponent(cleanQ)}';
    AppLogger.d('[AnimixStream] Searching: $url');

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final doc = html_parser.parse(res.body);

      // Match anime-card links
      final cards = doc.querySelectorAll('a[href*="/anime/"]');
      final candidates = <Map<String, String>>[];

      for (final card in cards) {
        final href = card.attributes['href'];
        if (href == null || href.isEmpty) continue;
        final imgAlt = card.querySelector('img[alt]')?.attributes['alt']?.trim();
        String rawTitle = imgAlt ?? '';
        if (rawTitle.isEmpty) {
          final lines = card.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          for (int i = 0; i < lines.length; i++) {
            if (lines[i] == '▶' && i + 1 < lines.length) {
              rawTitle = lines[i + 1];
              break;
            }
          }
          if (rawTitle.isEmpty && lines.isNotEmpty) {
            rawTitle = lines.first;
          }
        }

        if (rawTitle.isNotEmpty) {
          final fullHref = href.startsWith('http') ? href : '$_baseUrl$href';
          candidates.add({'title': rawTitle, 'url': fullHref});
        }
      }

      if (candidates.isEmpty) return null;

      final normalizedTarget = title.toLowerCase();
      final targetTokens = normalizedTarget.split(' ').where((t) => t.length > 2).toSet();

      Map<String, String>? bestMatch;
      int bestScore = -1;

      for (final c in candidates) {
        final cTitleNorm = c['title']!.toLowerCase();
        if (cTitleNorm == normalizedTarget) {
          bestMatch = c;
          break;
        }
        final cTokens = cTitleNorm.split(' ').where((t) => t.length > 2).toSet();
        final common = targetTokens.intersection(cTokens).length;
        if (common > bestScore) {
          bestScore = common;
          bestMatch = c;
        }
      }

      return bestMatch?['url'];
    } catch (e) {
      AppLogger.w('[AnimixStream] Search error: $e');
      return null;
    }
  }

  @override
  Future<int?> getEpisodeCount(String providerAnimeId) async {
    try {
      final pageUrl = providerAnimeId.startsWith('http')
          ? providerAnimeId
          : '$_baseUrl$providerAnimeId';

      final res = await http.get(
        Uri.parse(pageUrl),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final html = res.body;

      final watchRe = RegExp(r'/watch/\d+/(\d+)', caseSensitive: false);
      int maxPos = 0;
      for (final m in watchRe.allMatches(html)) {
        final pos = int.tryParse(m.group(1) ?? '') ?? 0;
        if (pos > maxPos) maxPos = pos;
      }
      return maxPos > 0 ? maxPos : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BaseSourcesModel?> resolveEpisode({
    required String providerAnimeId,
    required int episodeNumber,
    String? animeTitle,
  }) async {
    final animeId = RegExp(r'\d+').firstMatch(providerAnimeId)?.group(0);
    if (animeId == null) return null;
    final watchUrl = '$_baseUrl/watch/$animeId/$episodeNumber';

    AppLogger.d('[AnimixStream] Resolving Ep $episodeNumber on $watchUrl');

    try {
      final res = await http.get(
        Uri.parse(watchUrl),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final html = res.body;

      // Extract iframe src
      final iframeMatch = RegExp(r'<iframe[^>]*src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
      final iframeSrc = iframeMatch?.group(1);
      if (iframeSrc == null || iframeSrc.isEmpty) {
        return null;
      }

      if (iframeSrc.contains('.m3u8')) {
        return BaseSourcesModel(
          sources: [
            Source(
              url: iframeSrc,
              quality: 'auto (multi-audio)',
              isM3U8: true,
            ),
          ],
          headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
        );
      }

      final iframeRes = await http.get(
        Uri.parse(iframeSrc),
        headers: {'User-Agent': _ua, 'Referer': watchUrl},
      ).timeout(const Duration(seconds: 10));

      if (iframeRes.statusCode == 200) {
        final iHtml = iframeRes.body;
        final m3u8Match = RegExp(r'["\x27](https?://[^"\x27]*\.m3u8[^"\x27]*)["\x27]').firstMatch(iHtml);
        if (m3u8Match != null) {
          final streamUrl = m3u8Match.group(1)!;
          return BaseSourcesModel(
            sources: [
              Source(
                url: streamUrl,
                quality: 'auto (multi-audio)',
                isM3U8: true,
              ),
            ],
            headers: {'User-Agent': _ua, 'Referer': iframeSrc},
          );
        }
      }

      return null;
    } catch (e) {
      AppLogger.e('[AnimixStream] Episode resolution error: $e');
      return null;
    }
  }

  @override
  Future<String?> resolveDownload({
    required String providerAnimeId,
    required int episodeNumber,
    String? quality,
  }) async {
    final stream = await resolveEpisode(
      providerAnimeId: providerAnimeId,
      episodeNumber: episodeNumber,
    );
    return stream?.sources.firstOrNull?.url;
  }
}
