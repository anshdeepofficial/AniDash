import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ani_dash/core/jikan/jikan_service.dart';
import 'package:ani_dash/core/models/aniskip/aniskip_result.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/services/aniskip_service.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';

part 'aniskip_notifier.g.dart';

@riverpod
class AniSkipNotifier extends _$AniSkipNotifier {
  final JikanService _jikan = JikanService();
  static final Map<String, int> _malIdCache = {};

  @override
  List<AniSkipResultItem> build() {
    return const [];
  }

  Future<void> fetchSkipTimes({
    required String mediaId,
    required String animeTitle,
    required int episodeNumber,
    required int episodeLength,
  }) async {
    state = [];
    int? malId;

    try {
      final cacheKey = animeTitle.trim().toLowerCase();

      // 1. Check in-memory cache
      if (_malIdCache.containsKey(mediaId)) {
        malId = _malIdCache[mediaId];
      } else if (_malIdCache.containsKey(cacheKey)) {
        malId = _malIdCache[cacheKey];
      }

      // 2. Check EpisodeListState.malId
      if (malId == null) {
        malId = ref.read(episodeListProvider).malId;
      }

      // 3. Query AniList directly by numeric ID (fast GraphQL, ~200ms)
      final anilistId = int.tryParse(mediaId);
      if (malId == null && anilistId != null) {
        try {
          final res = await UniversalHttpClient.instance.post(
            Uri.parse('https://graphql.anilist.co'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query':
                  'query (\$id: Int) { Media(id: \$id, type: ANIME) { idMal } }',
              'variables': {'id': anilistId},
            }),
            cacheConfig: CacheConfig.veryLong,
          );

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final rawMal = data?['data']?['Media']?['idMal'];
            if (rawMal != null) {
              malId = rawMal is int ? rawMal : int.tryParse(rawMal.toString());
            }
          }
        } catch (e) {
          AppLogger.w('AniList fast ID query failed: $e');
        }
      }

      // 4. Query AniList by Title Search if ID was not numeric or had no MAL ID
      if (malId == null && animeTitle.isNotEmpty) {
        try {
          final res = await UniversalHttpClient.instance.post(
            Uri.parse('https://graphql.anilist.co'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query':
                  'query (\$search: String) { Media(search: \$search, type: ANIME) { idMal } }',
              'variables': {'search': animeTitle},
            }),
            cacheConfig: CacheConfig.veryLong,
          );

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final rawMal = data?['data']?['Media']?['idMal'];
            if (rawMal != null) {
              malId = rawMal is int ? rawMal : int.tryParse(rawMal.toString());
            }
          }
        } catch (e) {
          AppLogger.w('AniList search MAL query failed: $e');
        }
      }

      // 5. Fallback via Jikan search
      if (malId == null && animeTitle.isNotEmpty) {
        try {
          final results = await _jikan.getSearch(title: animeTitle, limit: 1);
          if (results.isNotEmpty) {
            malId = results.first.malId;
          }
        } catch (e) {
          AppLogger.w('Jikan search failed: $e');
        }
      }

      // 6. Fetch skip times if MAL ID resolved
      if (malId != null) {
        _malIdCache[mediaId] = malId;
        _malIdCache[cacheKey] = malId;

        AppLogger.d('Resolved MAL ID $malId for $animeTitle ($mediaId)');
        final results = await aniSkipService.getSkipTimes(
          malId,
          episodeNumber,
          episodeLength,
        );
        state = results;
        AppLogger.d(
          'AniSkip: ${results.length} skip intervals found for ep $episodeNumber',
        );
      } else {
        AppLogger.w('Could not resolve MAL ID for $animeTitle ($mediaId)');
      }
    } catch (e) {
      AppLogger.w('Failed to fetch skip times for ep $episodeNumber: $e');
    }
  }

  void clear() {
    state = [];
  }
}
