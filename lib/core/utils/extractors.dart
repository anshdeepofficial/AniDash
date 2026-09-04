import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

Future<List<Map<String, dynamic>>> extractQualities(
  String url,
  Map<String, String>? headers,
  bool isM3U8,
) async {
  if (!isM3U8) {
    return [
      {'quality': 'Default', 'url': url},
    ];
  }

  try {
    final response = await UniversalHttpClient.instance.get(
      Uri.parse(url),
      headers: headers,
      cacheConfig: CacheConfig.long,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _parseM3U8(response.body, url);
    }
  } catch (e) {
    AppLogger.w('Error parsing M3U8: $e');
  }

  return [
    {'quality': 'Default', 'url': url},
  ];
}

List<Map<String, dynamic>> _parseM3U8(String body, String masterUrl) {
  if (!body.contains('#EXTM3U')) {
    return [
      {'quality': 'Default', 'url': masterUrl}
    ];
  }

  final lines = body.split('\n');
  final extractedQualities = <Map<String, dynamic>>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    if (line.startsWith('#EXT-X-STREAM-INF')) {
      final resolutionMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
      final nameMatch = RegExp(r'NAME="([^"]+)"').firstMatch(line);
      
      String quality = 'Unknown';

      if (resolutionMatch != null) {
        quality = '${resolutionMatch.group(1)}p';
      } else if (nameMatch != null) {
        quality = nameMatch.group(1)!;
      }

      for (int j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty) continue;
        if (candidate.startsWith('#')) {
          if (candidate.startsWith('#EXT-X-STREAM-INF')) break;
          continue;
        }
        final fullUrl = Uri.parse(masterUrl).resolve(candidate).toString();
        extractedQualities.add({'quality': quality, 'url': fullUrl});
        break;
      }
    }
  }

  if (extractedQualities.isEmpty) {
    return [{'quality': 'Default', 'url': masterUrl}];
  }

  extractedQualities.sort((a, b) {
    final aVal = int.tryParse(a['quality'].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final bVal = int.tryParse(b['quality'].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return bVal.compareTo(aVal);
  });

  return [
    {'quality': 'Auto', 'url': masterUrl},
    ...extractedQualities,
  ];
}
