import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/helpers/matcher.dart';

class AnimeDriveProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animedrive';

  @override
  String get name => 'AnimeDrive';

  static const String _defaultBaseUrl = 'https://animedrive.in';
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

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'\s+(?:Hindi|Tamil|Telugu|English|Japanese|Multi[ -]?Audio|Dual[ -]?Audio|WEB-?DL|Episodes?|Download|Free)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
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

    final url = '$_baseUrl/?s=${Uri.encodeComponent(cleanQ)}';
    AppLogger.d('[AnimeDrive] Searching: $url');

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final doc = html_parser.parse(res.body);

      final links = doc.querySelectorAll('a[aria-label*="Read:"]');
      final candidates = <Map<String, String>>[];

      for (final link in links) {
        final href = link.attributes['href'];
        final aria = link.attributes['aria-label'] ?? '';
        final cleanT = _cleanTitle(aria.replaceAll('Read:', ''));

        if (href != null && cleanT.isNotEmpty) {
          candidates.add({'title': cleanT, 'url': href});
        }
      }

      if (candidates.isEmpty) return null;

      final matches = getBestMatches<Map<String, String>>(
        results: candidates,
        title: title,
        nameSelector: (c) => c['title'],
        idSelector: (c) => c['url'],
        minThreshold: 0.5,
      );

      if (matches.isNotEmpty) {
        final best = matches.first.result;
        AppLogger.d('[AnimeDrive] Matched: ${best['title']} (score: ${matches.first.similarity})');
        return best['url'];
      }
      return null;
    } catch (e) {
      AppLogger.w('[AnimeDrive] Search error: $e');
      return null;
    }
  }

  @override
  Future<int?> getEpisodeCount(String providerAnimeId) async {
    try {
      final res = await http.get(
        Uri.parse(providerAnimeId),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final html = res.body;

      final gwMatch = RegExp(
        r'''https?://link\.animedrive\.in/[^\s"'<>]+''',
        caseSensitive: false,
      ).firstMatch(html);
      if (gwMatch == null) return null;

      final gwRes = await http.get(
        Uri.parse(gwMatch.group(0)!),
        headers: {'User-Agent': _ua, 'Referer': providerAnimeId},
      ).timeout(const Duration(seconds: 8));

      if (gwRes.statusCode != 200) return null;
      final gwHtml = gwRes.body;

      final epMatches = RegExp(r'Episode\s*(\d+)', caseSensitive: false).allMatches(gwHtml);
      int maxEp = 0;
      for (final m in epMatches) {
        final ep = int.tryParse(m.group(1) ?? '') ?? 0;
        if (ep > maxEp) maxEp = ep;
      }
      return maxEp > 0 ? maxEp : null;
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
    AppLogger.d('[AnimeDrive] Resolving Ep $episodeNumber on $providerAnimeId');

    try {
      final res = await http.get(
        Uri.parse(providerAnimeId),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final html = res.body;

      // Extract gateway link
      final gwMatch = RegExp(
        r'''https?://link\.animedrive\.in/[^\s"'<>]+''',
        caseSensitive: false,
      ).firstMatch(html);
      if (gwMatch == null) {
        AppLogger.w('[AnimeDrive] No gateway link found');
        return null;
      }

      final gwUrl = gwMatch.group(0)!;
      final gwRes = await http.get(
        Uri.parse(gwUrl),
        headers: {'User-Agent': _ua, 'Referer': providerAnimeId},
      ).timeout(const Duration(seconds: 10));

      if (gwRes.statusCode != 200) return null;
      final gwHtml = gwRes.body;

      // Parse Episode blocks and HubCloud links
      final epMarkers = <Map<String, dynamic>>[];
      final epRegex = RegExp(r'Episode\s*(\d+)', caseSensitive: false);
      for (final m in epRegex.allMatches(gwHtml)) {
        epMarkers.add({'ep': int.parse(m.group(1)!), 'at': m.start});
      }

      if (epMarkers.isEmpty) return null;

      final hubcloudHrefs = <String>[];
      for (int i = 0; i < epMarkers.length; i++) {
        final ep = epMarkers[i]['ep'] as int;
        if (ep != episodeNumber) continue;

        final start = epMarkers[i]['at'] as int;
        final end = (i + 1 < epMarkers.length) ? (epMarkers[i + 1]['at'] as int) : gwHtml.length;
        final block = gwHtml.substring(start, end);

        final hubRe = RegExp(r'href=["\x27](https?://[a-z0-9.-]*hubcloud[a-z0-9.-]*/[^"\x27]+)["\x27]', caseSensitive: false);
        for (final hm in hubRe.allMatches(block)) {
          final hUrl = hm.group(1)!;
          if (!hubcloudHrefs.contains(hUrl)) hubcloudHrefs.add(hUrl);
        }
      }

      if (hubcloudHrefs.isEmpty) {
        AppLogger.w('[AnimeDrive] No HubCloud links found for Ep $episodeNumber');
        return null;
      }

      // Resolve direct stream from first working HubCloud link
      for (final hubUrl in hubcloudHrefs.take(4)) {
        final directSource = await _resolveHubCloud(hubUrl);
        if (directSource != null) {
          AppLogger.success('[AnimeDrive] Playable stream resolved: ${directSource.url}');
          return BaseSourcesModel(
            sources: [directSource],
            headers: {'User-Agent': _ua},
          );
        }
      }

      return null;
    } catch (e) {
      AppLogger.e('[AnimeDrive] Episode resolution error: $e');
      return null;
    }
  }

  Future<Source?> _resolveHubCloud(String url) async {
    try {
      final base = Uri.parse(url).origin;
      String downloadPageUrl = url;

      if (!url.contains('hubcloud.php')) {
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': _ua},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final m = RegExp(r'id=["\x27]download["\x27][^>]*href=["\x27]([^"\x27]+)["\x27]').firstMatch(res.body) ??
              RegExp(r'href=["\x27]([^"\x27]+)["\x27][^>]*id=["\x27]download["\x27]').firstMatch(res.body);
          final raw = m?.group(1);
          if (raw != null) {
            downloadPageUrl = raw.startsWith('http') ? raw : '$base/${raw.replaceFirst(RegExp(r'^/'), '')}';
          }
        }
      }

      final docRes = await http.get(
        Uri.parse(downloadPageUrl),
        headers: {'User-Agent': _ua},
      ).timeout(const Duration(seconds: 8));

      if (docRes.statusCode != 200) return null;
      final docHtml = docRes.body;

      // Extract server download buttons
      final btnRe = RegExp(
        r'<a[^>]*href=["\x27]([^"\x27]+)["\x27][^>]*class=["\x27][^"\x27]*\bbtn\b[^"\x27]*["\x27][^>]*>([\s\S]*?)<\/a>',
        caseSensitive: false,
      );

      for (final bm in btnRe.allMatches(docHtml)) {
        final link = bm.group(1)!;
        final text = bm.group(2)!.toLowerCase();

        if (link.contains('.mp4') || link.contains('.m3u8')) {
          return Source(
            url: link,
            quality: 'auto',
            isM3U8: link.contains('.m3u8'),
          );
        }

        if (text.contains('buzz') || text.contains('buzzserver')) {
          try {
            final client = http.Client();
            final req = http.Request('GET', Uri.parse('$link/download'))..followRedirects = false;
            req.headers.addAll({'Referer': link, 'User-Agent': _ua});
            final streamedRes = await client.send(req).timeout(const Duration(seconds: 5));
            client.close();
            final hx = streamedRes.headers['hx-redirect'] ?? streamedRes.headers['HX-Redirect'];
            if (hx != null && hx.isNotEmpty) {
              return Source(
                url: hx,
                quality: 'auto',
                isM3U8: hx.contains('.m3u8'),
              );
            }
          } catch (_) {}
        }

        if (text.contains('pixeldra') || text.contains('pixel')) {
          final b = Uri.parse(link).origin;
          final id = link.replaceAll(RegExp(r'/$'), '').split('/').last;
          final fin = link.contains('download') ? link : '$b/api/file/$id?download';
          return Source(
            url: fin,
            quality: 'auto',
            isM3U8: false,
          );
        }

        if (text.contains('fsl') || text.contains('s3') || text.contains('mega') || text.contains('10gb')) {
          return Source(
            url: link,
            quality: 'auto',
            isM3U8: link.contains('.m3u8'),
          );
        }
      }

      return null;
    } catch (_) {
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
