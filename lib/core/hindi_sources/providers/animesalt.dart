import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/helpers/matcher.dart';

class AnimeSaltProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animesalt';

  @override
  String get name => 'AnimeSalt';

  static const String _defaultBaseUrl = 'https://animesalt.ac';
  static const List<String> _defaultMirrors = [
    'https://animesalt.ac',
    'https://animesalt.to',
    'https://animesalt.me',
    'https://animesalt.ro',
  ];

  String _baseUrl = _defaultBaseUrl;
  List<String> _mirrors = _defaultMirrors;
  String? _workingMirror;

  @override
  String get baseUrl => _workingMirror ?? _baseUrl;

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

  /// Picks first reachable mirror with real homepage content (>800 chars, status < 500).
  /// Caches working mirror for the current app session.
  Future<String> _pickMain() async {
    if (_workingMirror != null) return _workingMirror!;
    final candidateMirrors = [_baseUrl, ..._mirrors.where((m) => m != _baseUrl)];

    for (final mirror in candidateMirrors) {
      try {
        final res = await http.get(
          Uri.parse('$mirror/'),
          headers: {'User-Agent': _ua},
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode < 500 && res.body.length > 500) {
          _workingMirror = mirror;
          AppLogger.i('[AnimeSalt] Selected healthy mirror: $mirror');
          return mirror;
        }
      } catch (_) {}
    }
    _workingMirror = _baseUrl;
    return _baseUrl;
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final main = await _pickMain();
      final res = await http.get(
        Uri.parse('$main/'),
        headers: {'User-Agent': _ua},
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'^\s*(?:download|watch)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*animesalt\s*[|\-–:]\s*', caseSensitive: false), '')
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
    final main = await _pickMain();
    final cleanQ = title
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanQ.isEmpty) return null;

    final url = '$main/filter?keyword=${Uri.encodeComponent(cleanQ)}';
    AppLogger.d('[AnimeSalt] Searching: $url');

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Referer': '$main/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final doc = html_parser.parse(res.body);
      final links = doc.querySelectorAll('a[href*="/watch/"]');

      final candidates = <Map<String, String>>[];
      for (final link in links) {
        var href = link.attributes['href'];
        if (href == null || href.isEmpty) continue;
        if (!href.startsWith('http')) {
          href = '$main$href';
        }
        final cleanHref = href.replaceAll(RegExp(r'/ep-\d+/?$'), '');
        final title = link.attributes['title'] ?? link.text.trim();
        final cTitle = _cleanTitle(title);

        if (cTitle.isNotEmpty && !candidates.any((c) => c['url'] == cleanHref)) {
          candidates.add({'title': cTitle, 'url': cleanHref});
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
        AppLogger.d('[AnimeSalt] Matched: ${best['title']} (score: ${matches.first.similarity})');
        return best['url'];
      }
      return null;
    } catch (e) {
      AppLogger.w('[AnimeSalt] Search failed: $e');
      return null;
    }
  }

  @override
  Future<int?> getEpisodeCount(String providerAnimeId) async {
    try {
      final main = await _pickMain();
      final pageUrl = providerAnimeId.startsWith('http')
          ? providerAnimeId
          : '$main$providerAnimeId';

      final res = await http.get(
        Uri.parse(pageUrl),
        headers: {'User-Agent': _ua, 'Referer': '$main/'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final html = res.body;

      final dataIdMatch = RegExp(
        r'id=["\x27]wrapper["\x27][^>]*data-id=["\x27]?(\d+)["\x27]?|data-id=["\x27]?(\d+)["\x27]?[^>]*id=["\x27]wrapper["\x27]',
        caseSensitive: false,
      ).firstMatch(html);
      final animeId = dataIdMatch?.group(1) ?? dataIdMatch?.group(2);
      if (animeId != null) {
        final listRes = await http.get(
          Uri.parse('$main/ajax/episode/list/$animeId'),
          headers: {'User-Agent': _ua, 'X-Requested-With': 'XMLHttpRequest', 'Referer': pageUrl},
        ).timeout(const Duration(seconds: 6));
        if (listRes.statusCode == 200) {
          try {
            final data = jsonDecode(listRes.body);
            final ajaxHtml = data['html']?.toString() ?? '';
            final numMatches = RegExp(r'data-number=["\x27](\d+)["\x27]').allMatches(ajaxHtml);
            int maxEp = 0;
            for (final m in numMatches) {
              final ep = int.tryParse(m.group(1) ?? '') ?? 0;
              if (ep > maxEp) maxEp = ep;
            }
            if (maxEp > 0) return maxEp;
          } catch (_) {}
        }
      }

      return null;
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
    final main = await _pickMain();
    final pageUrl = providerAnimeId.startsWith('http')
        ? providerAnimeId
        : '$main$providerAnimeId';

    AppLogger.d('[AnimeSalt] Resolving Ep $episodeNumber on $pageUrl');

    try {
      final res = await http.get(
        Uri.parse(pageUrl),
        headers: {'User-Agent': _ua, 'Referer': '$main/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final html = res.body;

      String? targetEpisodePageUrl;

      // Check inline episodes: /episode/[slug]-(\d+)x(\d+)
      final re = RegExp(r'<a[^>]+href=["\x27]([^"\x27]+/episode/[a-z0-9-]+-(\d+)x(\d+)/?)["\x27]', caseSensitive: false);
      final matches = re.allMatches(html);

      for (final m in matches) {
        final ep = int.tryParse(m.group(3) ?? '') ?? 0;
        if (ep == episodeNumber) {
          targetEpisodePageUrl = m.group(1);
          break;
        }
      }

      // If not inline and page has data-post and seasons, try admin-ajax
      if (targetEpisodePageUrl == null) {
        final postIdMatch = RegExp(r'data-post=["\x27](\d+)["\x27]').firstMatch(html);
        final seasonMatches = RegExp(r'data-season=["\x27](\d+)["\x27]').allMatches(html);
        final postId = postIdMatch?.group(1);

        if (postId != null && seasonMatches.isNotEmpty) {
          for (final sm in seasonMatches) {
            final sNum = sm.group(1);
            if (sNum == null) continue;
            try {
              final ajaxRes = await http.post(
                Uri.parse('$main/wp-admin/admin-ajax.php'),
                headers: {
                  'User-Agent': _ua,
                  'X-Requested-With': 'XMLHttpRequest',
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Referer': pageUrl,
                },
                body: 'action=action_select_season&season=$sNum&post=$postId',
              ).timeout(const Duration(seconds: 6));

              if (ajaxRes.statusCode == 200) {
                final ajaxMatches = re.allMatches(ajaxRes.body);
                for (final am in ajaxMatches) {
                  final ep = int.tryParse(am.group(3) ?? '') ?? 0;
                  if (ep == episodeNumber) {
                    targetEpisodePageUrl = am.group(1);
                    break;
                  }
                }
              }
              if (targetEpisodePageUrl != null) break;
            } catch (_) {}
          }
        }
      }

      if (targetEpisodePageUrl == null) {
        AppLogger.w('[AnimeSalt] Episode $episodeNumber link not found');
        return null;
      }

      // Fetch episode page to extract player embed
      final epRes = await http.get(
        Uri.parse(targetEpisodePageUrl),
        headers: {'User-Agent': _ua, 'Referer': pageUrl},
      ).timeout(const Duration(seconds: 10));

      if (epRes.statusCode != 200) return null;
      final epHtml = epRes.body;

      // Match player embed: https?://as-cdn*.top/video/[a-f0-9]+
      final embedMatch = RegExp(
        r'https?://(?:[a-z0-9.-]*cdn\d*\.top)/video/([a-f0-9]+)',
        caseSensitive: false,
      ).firstMatch(epHtml);

      if (embedMatch == null) {
        AppLogger.w('[AnimeSalt] No as-cdn embed found on $targetEpisodePageUrl');
        return null;
      }

      final fullEmbedUrl = embedMatch.group(0)!;
      final hex = embedMatch.group(1)!;
      final host = Uri.parse(fullEmbedUrl).origin;

      // Request signed master.m3u8 via getVideo API
      final videoRes = await http.post(
        Uri.parse('$host/player/index.php?data=$hex&do=getVideo'),
        headers: {
          'User-Agent': _ua,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': fullEmbedUrl,
        },
      ).timeout(const Duration(seconds: 10));

      if (videoRes.statusCode != 200 || videoRes.body.isEmpty) {
        AppLogger.w('[AnimeSalt] getVideo returned ${videoRes.statusCode}');
        return null;
      }

      final dynamic data = jsonDecode(videoRes.body);
      final masterUrl = data['videoSource'] ?? data['securedLink'];
      if (masterUrl == null || masterUrl.toString().isEmpty) {
        AppLogger.w('[AnimeSalt] getVideo response has no videoSource');
        return null;
      }

      final streamUrl = masterUrl.toString();
      final isHls = streamUrl.contains('.m3u8');

      AppLogger.success('[AnimeSalt] Playable stream resolved: $streamUrl');

      return BaseSourcesModel(
        sources: [
          Source(
            url: streamUrl,
            quality: 'auto (multi-audio)',
            isM3U8: isHls,
          ),
        ],
        headers: {
          'User-Agent': _ua,
          'Referer': '$host/',
        },
      );
    } catch (e) {
      AppLogger.e('[AnimeSalt] Episode resolution error: $e');
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
