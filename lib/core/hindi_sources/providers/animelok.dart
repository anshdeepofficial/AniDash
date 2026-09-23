import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/hindi_sources/interfaces/hindi_playback_provider.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

/// Experimental sandbox provider for AnimeLok.
/// Disabled by default due to Cloudflare WAF on upstream video CDN (hawk.24stream.xyz).
class AnimeLokProvider implements HindiPlaybackProvider {
  @override
  String get id => 'animelok';

  @override
  String get name => 'AnimeLok';

  static const String _defaultBaseUrl = 'https://animelok.online';
  String _baseUrl = _defaultBaseUrl;
  List<String> _mirrors = const [_defaultBaseUrl];

  @override
  String get baseUrl => _baseUrl;

  @override
  List<String> get mirrors => _mirrors;

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsDownloads => false;

  @override
  bool get supportsMultiAudio => false;

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
    if (anilistId != null) {
      return anilistId.toString();
    }

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/search?keyword=${Uri.encodeComponent(title)}'),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/', 'RSC': '1'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final body = res.body;

      // Extract slug from {"slug":"<name>-<anilistId>"}
      final m = RegExp(r'\{"slug":"[a-z0-9-]+-(\d+)"\}').firstMatch(body);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> getEpisodeCount(String providerAnimeId) async {
    return null; // Resolved dynamically per-episode
  }

  @override
  Future<BaseSourcesModel?> resolveEpisode({
    required String providerAnimeId,
    required int episodeNumber,
    String? animeTitle,
  }) async {
    try {
      final aid = providerAnimeId;
      final url = '$_baseUrl/api/get-vibeplayer-data?anilistId=$aid&epNum=$episodeNumber&type=dub';

      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 || res.body.isEmpty) return null;

      final dynamic data = jsonDecode(res.body);
      final sources = (data['sources'] as List<dynamic>?) ?? [];
      if (sources.isEmpty) return null;

      final playable = <Source>[];
      for (final s in sources) {
        final streamUrl = s['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) {
          playable.add(
            Source(
              url: streamUrl,
              quality: s['quality']?.toString() ?? 'auto',
              isM3U8: streamUrl.contains('.m3u8'),
            ),
          );
        }
      }

      if (playable.isEmpty) return null;

      return BaseSourcesModel(
        sources: playable,
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      );
    } catch (e) {
      AppLogger.w('[AnimeLok] Resolution failed: $e');
      return null;
    }
  }

  @override
  Future<String?> resolveDownload({
    required String providerAnimeId,
    required int episodeNumber,
    String? quality,
  }) async => null;
}
