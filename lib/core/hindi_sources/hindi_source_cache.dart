import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class _CachedStreamEntry {
  final BaseSourcesModel data;
  final DateTime expiresAt;

  _CachedStreamEntry(this.data, {Duration ttl = const Duration(minutes: 20)})
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class HindiSourceCache {
  static final HindiSourceCache instance = HindiSourceCache._();
  HindiSourceCache._();

  // In-memory stream cache: anime_ep_provider -> BaseSourcesModel
  final Map<String, _CachedStreamEntry> _streamCache = {};

  // Anime mapping cache: animeKey -> {providerId: providerAnimeId, "cached_at": timestamp}
  final Map<String, Map<String, dynamic>> _mappingMemoryCache = {};
  static const String _prefPrefix = 'hindi_mapping_';
  static const Duration _mappingTtl = Duration(hours: 24);

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.w('[Hindi Cache] Failed to init SharedPreferences: $e');
    }
  }

  String _cleanKey(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  // --- ANIME MAPPING CACHE ---

  Future<String?> getMappedAnimeId({
    required String providerId,
    required String title,
    String? romajiTitle,
    int? anilistId,
  }) async {
    final keys = <String>[];
    if (anilistId != null && anilistId > 0) keys.add('anilist_$anilistId');
    if (title.isNotEmpty) keys.add(_cleanKey(title));
    if (romajiTitle != null && romajiTitle.isNotEmpty) {
      keys.add(_cleanKey(romajiTitle));
    }

    await init();

    for (final key in keys) {
      // Check memory cache first
      final mem = _mappingMemoryCache[key];
      if (mem != null) {
        final cachedAt = mem['_ts'] as int?;
        if (cachedAt != null &&
            DateTime.now().millisecondsSinceEpoch - cachedAt <
                _mappingTtl.inMilliseconds) {
          final mapped = mem[providerId] as String?;
          if (mapped != null && mapped.isNotEmpty) {
            AppLogger.d('[Hindi] mapping cache hit (mem) for $key -> $mapped');
            return mapped;
          }
        }
      }

      // Check persistent prefs
      if (_prefs != null) {
        final raw = _prefs!.getString('$_prefPrefix$key');
        if (raw != null) {
          try {
            final decoded = json.decode(raw) as Map<String, dynamic>;
            final cachedAt = decoded['_ts'] as int?;
            if (cachedAt != null &&
                DateTime.now().millisecondsSinceEpoch - cachedAt <
                    _mappingTtl.inMilliseconds) {
              _mappingMemoryCache[key] = decoded;
              final mapped = decoded[providerId] as String?;
              if (mapped != null && mapped.isNotEmpty) {
                AppLogger.d('[Hindi] mapping cache hit (disk) for $key -> $mapped');
                return mapped;
              }
            } else {
              _prefs!.remove('$_prefPrefix$key');
            }
          } catch (_) {}
        }
      }
    }

    return null;
  }

  Future<void> saveMappedAnimeId({
    required String providerId,
    required String providerAnimeId,
    required String title,
    String? romajiTitle,
    int? anilistId,
  }) async {
    if (providerAnimeId.isEmpty) return;

    final keys = <String>[];
    if (anilistId != null && anilistId > 0) keys.add('anilist_$anilistId');
    if (title.isNotEmpty) keys.add(_cleanKey(title));
    if (romajiTitle != null && romajiTitle.isNotEmpty) {
      keys.add(_cleanKey(romajiTitle));
    }

    await init();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final key in keys) {
      final entry = _mappingMemoryCache[key] ?? <String, dynamic>{};
      entry[providerId] = providerAnimeId;
      entry['_ts'] = now;
      _mappingMemoryCache[key] = entry;

      if (_prefs != null) {
        try {
          await _prefs!.setString('$_prefPrefix$key', json.encode(entry));
        } catch (_) {}
      }
    }
    AppLogger.d('[Hindi] saved mapping cache for $providerId: $providerAnimeId');
  }

  // --- STREAM CACHE ---

  BaseSourcesModel? getCachedStream({
    required String animeId,
    required int episodeNumber,
    required String providerId,
  }) {
    final key = '${animeId}_${episodeNumber}_${providerId}_hindi';
    final entry = _streamCache[key];
    if (entry != null && !entry.isExpired) {
      AppLogger.success('[Hindi] stream cache hit for Ep $episodeNumber ($providerId)');
      return entry.data;
    }
    if (entry != null && entry.isExpired) {
      _streamCache.remove(key);
    }
    return null;
  }

  void saveCachedStream({
    required String animeId,
    required int episodeNumber,
    required String providerId,
    required BaseSourcesModel data,
    Duration ttl = const Duration(minutes: 20),
  }) {
    if (data.sources.isEmpty) return;
    final key = '${animeId}_${episodeNumber}_${providerId}_hindi';
    _streamCache[key] = _CachedStreamEntry(data, ttl: ttl);
    AppLogger.d('[Hindi] saved stream cache for Ep $episodeNumber ($providerId)');
  }

  void clearStreamCache({String? animeId, int? episodeNumber}) {
    if (animeId == null && episodeNumber == null) {
      _streamCache.clear();
    } else if (animeId != null && episodeNumber != null) {
      _streamCache.removeWhere(
        (k, _) => k.startsWith('${animeId}_$episodeNumber'),
      );
    } else if (animeId != null) {
      _streamCache.removeWhere((k, _) => k.startsWith('${animeId}_'));
    }
  }

  void clearAll() {
    _streamCache.clear();
    _mappingMemoryCache.clear();
  }
}
