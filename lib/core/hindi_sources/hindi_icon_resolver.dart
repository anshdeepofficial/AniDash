import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class HindiIconResolver {
  static final HindiIconResolver _instance = HindiIconResolver._internal();
  factory HindiIconResolver() => _instance;
  HindiIconResolver._internal();

  final Map<String, String> _memoryCache = {};
  bool _isPrefsLoaded = false;

  Future<void> init() async {
    if (_isPrefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('hindi_icon_')) {
          final id = key.substring('hindi_icon_'.length);
          final url = prefs.getString(key);
          if (url != null && url.isNotEmpty) {
            _memoryCache[id] = url;
          }
        }
      }
      _isPrefsLoaded = true;
    } catch (e) {
      AppLogger.w('Failed to load hindi icon cache: $e');
    }
  }

  String? getCachedIcon(String sourceId) {
    return _memoryCache[sourceId];
  }

  Future<String?> resolveIcon({
    required String sourceId,
    required String baseUrl,
    String? configuredLogoUrl,
  }) async {
    // 1. Configured logoUrl takes precedence
    if (configuredLogoUrl != null && configuredLogoUrl.trim().isNotEmpty) {
      _memoryCache[sourceId] = configuredLogoUrl.trim();
      return configuredLogoUrl.trim();
    }

    // 2. Check memory cache
    if (_memoryCache.containsKey(sourceId)) {
      return _memoryCache[sourceId];
    }

    await init();
    if (_memoryCache.containsKey(sourceId)) {
      return _memoryCache[sourceId];
    }

    if (baseUrl.trim().isEmpty) return null;

    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    try {
      // 3. Query baseUrl HTML to inspect <link rel="icon"> or <link rel="shortcut icon">
      final uri = Uri.tryParse(cleanBase);
      if (uri == null) return null;

      final res = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final html = res.body;

        // Check for link rel="icon" or rel="shortcut icon"
        final iconRegex = RegExp(
          r'<link[^>]+(?:rel=["\x27](?:shortcut\s+)?icon["\x27][^>]+href=["\x27]([^"\x27]+)["\x27]|href=["\x27]([^"\x27]+)["\x27][^>]+rel=["\x27](?:shortcut\s+)?icon["\x27])',
          caseSensitive: false,
        );

        final match = iconRegex.firstMatch(html);
        if (match != null) {
          final rawUrl = (match.group(1) ?? match.group(2) ?? '').trim();
          if (rawUrl.isNotEmpty) {
            final resolvedUrl = _resolveUrl(rawUrl, cleanBase);
            if (resolvedUrl != null) {
              await _saveToCache(sourceId, resolvedUrl);
              return resolvedUrl;
            }
          }
        }
      }
    } catch (_) {
      // Network lookup timed out or failed; proceed to default favicon
    }

    // 4. Fallback to ${baseUrl}/favicon.ico
    final defaultFavicon = '$cleanBase/favicon.ico';
    await _saveToCache(sourceId, defaultFavicon);
    return defaultFavicon;
  }

  String? _resolveUrl(String href, String base) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    if (href.startsWith('//')) {
      return 'https:$href';
    }
    if (href.startsWith('/')) {
      final baseUri = Uri.tryParse(base);
      if (baseUri != null) {
        return '${baseUri.scheme}://${baseUri.host}$href';
      }
    }
    return '$base/$href';
  }

  Future<void> _saveToCache(String sourceId, String url) async {
    _memoryCache[sourceId] = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hindi_icon_$sourceId', url);
    } catch (_) {}
  }
}
