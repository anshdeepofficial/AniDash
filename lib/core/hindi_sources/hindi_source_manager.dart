import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

import 'models/hindi_source_model.dart';
import 'interfaces/hindi_playback_provider.dart';
import 'hindi_source_cache.dart';
import 'hindi_source_health.dart';
import 'hindi_source_preferences.dart';
import 'providers/animesalt.dart';
import 'providers/animixstream.dart';
import 'providers/animedrive.dart';
import 'providers/animelok.dart';

final hindiSourceManagerProvider =
    NotifierProvider<HindiSourceManagerNotifier, List<HindiSourceModel>>(
  HindiSourceManagerNotifier.new,
);

class HindiSourceManagerNotifier extends Notifier<List<HindiSourceModel>> {
  @override
  List<HindiSourceModel> build() {
    Future.microtask(() => init());
    return const [];
  }

  final Map<String, HindiPlaybackProvider> _providers = {
    'animesalt': AnimeSaltProvider(),
    'animixstream': AnimixStreamProvider(),
    'animedrive': AnimeDriveProvider(),
    'animelok': AnimeLokProvider(),
  };

  final HindiSourceCache _cache = HindiSourceCache.instance;
  final HindiSourceHealthTracker _health = HindiSourceHealthTracker.instance;
  final HindiSourcePreferences _prefs = HindiSourcePreferences.instance;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _prefs.init();
      await _cache.init();

      // 1. Load bundled registry
      final bundledRaw =
          await rootBundle.loadString('assets/sources/hindi_sources.json');
      final decoded = json.decode(bundledRaw) as Map<String, dynamic>;
      final rawList = decoded['sources'] as List<dynamic>? ?? [];

      var models = rawList
          .map((m) => HindiSourceModel.fromMap(m as Map<String, dynamic>))
          .toList();

      // 2. Apply user custom enabled/disabled status
      final enabledMap = _prefs.getEnabledMap();
      models = models.map((m) {
        final userPref = enabledMap[m.id];
        return userPref != null ? m.copyWith(enabled: userPref) : m;
      }).toList();

      // 3. Apply user custom ordering
      final userOrder = _prefs.getOrder();
      if (userOrder.isNotEmpty) {
        final orderMap = {
          for (int i = 0; i < userOrder.length; i++) userOrder[i]: i,
        };
        models.sort((a, b) {
          final aIdx = orderMap[a.id] ?? 999;
          final bIdx = orderMap[b.id] ?? 999;
          return aIdx.compareTo(bIdx);
        });
      } else {
        models.sort((a, b) => a.priority.compareTo(b.priority));
      }

      state = models;
      _isInitialized = true;
      AppLogger.i(
        '[Hindi Manager] Initialized with ${models.length} Hindi providers',
      );

      // 4. Background non-blocking remote registry check
      _syncRemoteRegistry();
    } catch (e, stack) {
      AppLogger.e('[Hindi Manager] Init failed, using fallback defaults', e, stack);
      state = [
        const HindiSourceModel(
          id: 'animesalt',
          name: 'AnimeSalt',
          priority: 10,
          status: 'stable',
        ),
        const HindiSourceModel(
          id: 'animixstream',
          name: 'AnimixStream',
          priority: 20,
          status: 'stable',
        ),
        const HindiSourceModel(
          id: 'animedrive',
          name: 'AnimeDrive',
          priority: 30,
          status: 'backup',
        ),
        const HindiSourceModel(
          id: 'animelok',
          name: 'AnimeLok',
          priority: 40,
          enabled: false,
          status: 'experimental',
        ),
      ];
      _isInitialized = true;
    }
  }

  Future<void> _syncRemoteRegistry() async {
    // Non-blocking background sync from remote if desired
    try {
      // In production, can ping remote config URL without blocking
    } catch (_) {}
  }

  List<HindiSourceModel> getSources() => state;

  HindiPlaybackProvider? getProvider(String id) => _providers[id];

  Future<void> reorderSources(List<String> orderedIds) async {
    await _prefs.saveOrder(orderedIds);
    final orderMap = {
      for (int i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    final updated = List<HindiSourceModel>.from(state);
    updated.sort((a, b) {
      final aIdx = orderMap[a.id] ?? 999;
      final bIdx = orderMap[b.id] ?? 999;
      return aIdx.compareTo(bIdx);
    });
    state = updated;
  }

  Future<void> setSourceEnabled(String id, bool enabled) async {
    await _prefs.setSourceEnabled(id, enabled);
    state = state.map((m) {
      if (m.id == id) return m.copyWith(enabled: enabled);
      return m;
    }).toList();
  }

  Future<void> resetToDefaults() async {
    await _prefs.resetDefaults();
    _health.resetAll();
    _isInitialized = false;
    await init();
  }

  Future<({bool success, int latencyMs})> testProvider(String id) async {
    final provider = _providers[id];
    if (provider == null) return (success: false, latencyMs: 0);

    final sw = Stopwatch()..start();
    try {
      final ok = await provider.healthCheck().timeout(
            const Duration(seconds: 6),
            onTimeout: () => false,
          );
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      if (ok) {
        _health.recordSuccess(id, ms);
        state = state.map((m) {
          if (m.id == id) {
            return m.copyWith(
              isHealthy: true,
              lastLatencyMs: ms,
              lastTestedTime: DateTime.now(),
            );
          }
          return m;
        }).toList();
        return (success: true, latencyMs: ms);
      } else {
        _health.recordFailure(id);
        state = state.map((m) {
          if (m.id == id) {
            return m.copyWith(
              isHealthy: false,
              lastLatencyMs: ms,
              lastTestedTime: DateTime.now(),
            );
          }
          return m;
        }).toList();
        return (success: false, latencyMs: ms);
      }
    } catch (_) {
      sw.stop();
      _health.recordFailure(id);
      return (success: false, latencyMs: sw.elapsedMilliseconds);
    }
  }

  /// Fast hedged parallel resolution
  Future<BaseSourcesModel?> resolveEpisode({
    required String animeTitle,
    String? romajiTitle,
    required int episodeNumber,
    String? animeId,
    int? anilistId,
    int? malId,
    int? year,
    String? manualProviderId,
  }) async {
    await init();

    final targetAnimeId = animeId ?? anilistId?.toString() ?? animeTitle;

    // 1. Manual provider override
    if (manualProviderId != null &&
        manualProviderId.isNotEmpty &&
        manualProviderId != 'auto') {
      final cachedStream = _cache.getCachedStream(
        animeId: targetAnimeId,
        episodeNumber: episodeNumber,
        providerId: manualProviderId,
      );
      if (cachedStream != null) return cachedStream;

      final provider = _providers[manualProviderId];
      if (provider != null) {
        AppLogger.i('[Hindi] Manual provider selected: $manualProviderId');
        return await _resolveWithSingleProvider(
          provider: provider,
          animeTitle: animeTitle,
          romajiTitle: romajiTitle,
          episodeNumber: episodeNumber,
          targetAnimeId: targetAnimeId,
          anilistId: anilistId,
          malId: malId,
          year: year,
        );
      }
    }

    // 2. Check stream cache for ANY enabled provider in priority order
    for (final src in state.where((s) => s.enabled)) {
      final cached = _cache.getCachedStream(
        animeId: targetAnimeId,
        episodeNumber: episodeNumber,
        providerId: src.id,
      );
      if (cached != null) return cached;
    }

    // 3. Collect candidate providers: enabled & available (not in cooldown)
    final candidateModels = state
        .where((s) => s.enabled && _health.isAvailable(s.id))
        .toList();

    // Fallback: if all candidate providers in cooldown, allow all enabled
    final activeCandidates = candidateModels.isNotEmpty
        ? candidateModels
        : state.where((s) => s.enabled).toList();

    if (activeCandidates.isEmpty) {
      AppLogger.w('[Hindi] No enabled Hindi providers available');
      return null;
    }

    // 4. Hedged resolution:
    // T+0ms: Start candidate #1
    // T+800ms: If candidate #1 hasn't resolved, start candidate #2
    // T+1600ms: If candidates haven't resolved, start candidate #3
    final completer = Completer<BaseSourcesModel?>();
    final activeFutures = <Future<void>>[];
    var isDone = false;

    Future<void> runProvider(HindiSourceModel model) async {
      final provider = _providers[model.id];
      if (provider == null || isDone) return;

      final sw = Stopwatch()..start();
      try {
        final result = await _resolveWithSingleProvider(
          provider: provider,
          animeTitle: animeTitle,
          romajiTitle: romajiTitle,
          episodeNumber: episodeNumber,
          targetAnimeId: targetAnimeId,
          anilistId: anilistId,
          malId: malId,
          year: year,
        );
        sw.stop();

        if (result != null && result.sources.isNotEmpty && !isDone) {
          isDone = true;
          _health.recordSuccess(model.id, sw.elapsedMilliseconds);
          AppLogger.success(
            '[Hindi] ${model.name} resolved in ${sw.elapsedMilliseconds}ms. Selected as winning stream.',
          );
          if (!completer.isCompleted) completer.complete(result);
        } else {
          _health.recordFailure(model.id);
        }
      } catch (e) {
        sw.stop();
        _health.recordFailure(model.id);
        AppLogger.w('[Hindi] ${model.name} failed: $e');
      }
    }

    // Launch with staggered delays
    for (int i = 0; i < activeCandidates.length; i++) {
      final candidate = activeCandidates[i];
      final delayMs = i * 800;

      activeFutures.add(
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (!isDone) return runProvider(candidate);
        }),
      );
    }

    // Overall timeout: 14 seconds
    Future.wait(activeFutures).then((_) {
      if (!completer.isCompleted && !isDone) {
        completer.complete(null);
      }
    });

    return await completer.future.timeout(
      const Duration(seconds: 14),
      onTimeout: () => null,
    );
  }

  Future<BaseSourcesModel?> _resolveWithSingleProvider({
    required HindiPlaybackProvider provider,
    required String animeTitle,
    String? romajiTitle,
    required int episodeNumber,
    required String targetAnimeId,
    int? anilistId,
    int? malId,
    int? year,
  }) async {
    // A. Check mapped anime ID cache
    String? mappedId = await _cache.getMappedAnimeId(
      providerId: provider.id,
      title: animeTitle,
      romajiTitle: romajiTitle,
      anilistId: anilistId,
    );

    // B. Search provider if not cached
    if (mappedId == null || mappedId.isEmpty) {
      mappedId = await provider
          .findAnime(
            title: animeTitle,
            romajiTitle: romajiTitle,
            anilistId: anilistId,
            malId: malId,
            year: year,
          )
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

      if (mappedId != null && mappedId.isNotEmpty) {
        await _cache.saveMappedAnimeId(
          providerId: provider.id,
          providerAnimeId: mappedId,
          title: animeTitle,
          romajiTitle: romajiTitle,
          anilistId: anilistId,
        );
      }
    }

    if (mappedId == null || mappedId.isEmpty) {
      AppLogger.d('[Hindi] ${provider.name}: Could not find anime "$animeTitle"');
      return null;
    }

    // C. Resolve episode stream
    final sourcesModel = await provider
        .resolveEpisode(
          providerAnimeId: mappedId,
          episodeNumber: episodeNumber,
          animeTitle: animeTitle,
        )
        .timeout(const Duration(seconds: 10), onTimeout: () => null);

    if (sourcesModel != null && sourcesModel.sources.isNotEmpty) {
      _cache.saveCachedStream(
        animeId: targetAnimeId,
        episodeNumber: episodeNumber,
        providerId: provider.id,
        data: sourcesModel,
      );
      return sourcesModel;
    }

    return null;
  }

  /// Lightweight background next-episode prefetch
  Future<void> prefetchNextEpisode({
    required String animeTitle,
    String? romajiTitle,
    required int nextEpisodeNumber,
    String? animeId,
    int? anilistId,
    String? preferredProviderId,
  }) async {
    final targetAnimeId = animeId ?? anilistId?.toString() ?? animeTitle;

    // Check if already cached
    for (final src in state.where((s) => s.enabled)) {
      final cached = _cache.getCachedStream(
        animeId: targetAnimeId,
        episodeNumber: nextEpisodeNumber,
        providerId: src.id,
      );
      if (cached != null) return;
    }

    // Prefetch using preferred provider first
    final targetProvider = preferredProviderId != null
        ? _providers[preferredProviderId]
        : () {
            final firstEnabled = state.firstWhereOrNull((s) => s.enabled);
            return firstEnabled != null ? _providers[firstEnabled.id] : null;
          }();

    if (targetProvider != null) {
      AppLogger.d(
        '[Hindi] Background prefetching Ep $nextEpisodeNumber via ${targetProvider.name}',
      );
      await _resolveWithSingleProvider(
        provider: targetProvider,
        animeTitle: animeTitle,
        romajiTitle: romajiTitle,
        episodeNumber: nextEpisodeNumber,
        targetAnimeId: targetAnimeId,
        anilistId: anilistId,
      ).catchError((_) => null);
    }
  }
}
