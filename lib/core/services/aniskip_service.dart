import 'dart:convert';
import 'package:ani_dash/core/models/aniskip/aniskip_result.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AniSkipService {
  static const String _baseUrl = 'https://api.aniskip.com/v2';

  Future<List<AniSkipResultItem>> getSkipTimes(
    int malId,
    int episodeNumber,
    int episodeLength,
  ) async {
    try {
      // Query with episodeLength=0 so AniSkip returns all available intro AND outro segments
      final uri = Uri.parse(
        '$_baseUrl/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed&types[]=mixed-op&types[]=mixed-ed&types[]=recap&episodeLength=0',
      );

      final response = await UniversalHttpClient.instance.get(
        uri,
        cacheConfig: CacheConfig.veryLong,
      );

      AppLogger.d('AniSkip API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = AniSkipResponse.fromJson(data);
        if (result.found && result.results.isNotEmpty) {
          return result.results;
        }
      }

      // Fallback with specific episodeLength if length=0 returned nothing
      if (episodeLength > 0) {
        final fallbackUri = Uri.parse(
          '$_baseUrl/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed&types[]=mixed-op&types[]=mixed-ed&types[]=recap&episodeLength=$episodeLength',
        );
        final fallbackRes = await UniversalHttpClient.instance.get(
          fallbackUri,
          cacheConfig: CacheConfig.veryLong,
        );
        if (fallbackRes.statusCode == 200) {
          final data = jsonDecode(fallbackRes.body);
          final result = AniSkipResponse.fromJson(data);
          if (result.found) return result.results;
        }
      }
    } catch (e) {
      AppLogger.e('Failed to fetch AniSkip data: $e');
    }
    return [];
  }
}

final aniSkipService = AniSkipService();
