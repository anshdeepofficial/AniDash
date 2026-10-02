import 'dart:async';
import 'dart:convert';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:collection/collection.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ani_dash/core/jikan/jikan_service.dart';
import 'package:ani_dash/core/jikan/models/jikan_media.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/services/anime_filler_service.dart';
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:ani_dash/core/registery/sources/anime/justanime.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/models/settings/experimental_model.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'package:ani_dash/helpers/matcher.dart';
import 'package:ani_dash/main.dart';

part 'episode_list_provider.g.dart';

@immutable
class EpisodeListState {
  final String? mediaId;
  final String? animeId;
  final String? animeTitle;
  final String? animeCover;
  final int? malId;
  final List<EpisodeDataModel> episodes;
  final List<({JikanMedia result, double similarity})> jikanMatches;
  final bool isLoading;
  final bool isJikanSyncing;
  final String? error;
  final bool isAdult;

  const EpisodeListState({
    this.mediaId,
    this.animeId,
    this.animeTitle,
    this.animeCover,
    this.malId,
    this.episodes = const [],
    this.jikanMatches = const [],
    this.isLoading = false,
    this.isJikanSyncing = false,
    this.error,
    this.isAdult = false,
  });

  EpisodeListState copyWith({
    String? mediaId,
    String? animeId,
    String? animeTitle,
    String? animeCover,
    int? malId,
    List<EpisodeDataModel>? episodes,
    List<({JikanMedia result, double similarity})>? jikanMatches,
    bool? isLoading,
    bool? isJikanSyncing,
    String? error,
    bool? isAdult,
    bool clearMalId = false,
  }) {
    return EpisodeListState(
      mediaId: mediaId ?? this.mediaId,
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      animeCover: animeCover ?? this.animeCover,
      malId: clearMalId ? null : (malId ?? this.malId),
      episodes: episodes ?? this.episodes,
      jikanMatches: jikanMatches ?? this.jikanMatches,
      isLoading: isLoading ?? this.isLoading,
      isJikanSyncing: isJikanSyncing ?? this.isJikanSyncing,
      error: error ?? this.error,
      isAdult: isAdult ?? this.isAdult,
    );
  }

  EpisodeDataModel? getEpisode(int episode) =>
      episodes.firstWhereOrNull((e) => e.number == episode);
}

@Riverpod(keepAlive: true)
class EpisodeListNotifier extends _$EpisodeListNotifier {
  final JikanService _jikan = JikanService();
  int _requestGeneration = 0;

  ExperimentalFeaturesModel get _exp => ref.read(experimentalProvider);
  AnimeProvider? get _animeProvider => ref.read(selectedAnimeProvider);
  SourceNotifier get _sourceNotifier => ref.read(sourceProvider.notifier);

  @override
  EpisodeListState build() => const EpisodeListState();

  // --- Core Fetching Logic ---

  Future<List<EpisodeDataModel>> fetchEpisodes({
    required String animeTitle,
    String? animeId,
    String? mediaId,
    String? animeCover,
    required bool force,
    List<EpisodeDataModel> episodes = const [],
    DMedia? media,
    int? malId,
    bool isAdult = false,
    bool isMovie = false,
  }) async {
    final requestGeneration = ++_requestGeneration;
    final requestedMediaId = mediaId;
    // 1. Check Cache
    if (!force &&
        state.episodes.isNotEmpty &&
        state.animeId == animeId &&
        state.mediaId == requestedMediaId) {
      AppLogger.d('Episode list cache hit for: $animeTitle');
      return state.episodes;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      mediaId: mediaId ?? state.mediaId,
      animeId: animeId,
      animeTitle: animeTitle,
      animeCover: animeCover ?? media?.cover,
      malId: malId ?? state.malId,
      clearMalId: malId == null && state.malId == null,
      jikanMatches: const [],
      isAdult: isAdult,
    );
    AppLogger.section('Fetching Episodes: $animeTitle');

    // 2. Use provided episodes if available
    if (episodes.isNotEmpty) {
      AppLogger.success('Using ${episodes.length} pre-provided episodes');
      final normalized = _normalizeEpisodeTitles(
        episodes,
        animeTitle: animeTitle,
        isMovie: isMovie,
      );
      if (requestGeneration != _requestGeneration) return const [];
      state = state.copyWith(episodes: normalized, isLoading: false);
      _syncMetadataIfEnabled();
      return normalized;
    }

    // 3. Fetch from remote sources
    var fetched = await _fetchEpisodesInternal(animeId, media: media);
    if (requestGeneration != _requestGeneration) return const [];

    fetched = _normalizeEpisodeTitles(
      fetched,
      animeTitle: animeTitle,
      isMovie: isMovie,
    );

    if (fetched.isEmpty) {
      final titleLow = animeTitle.toLowerCase();
      final isLikelyMovie =
          titleLow.contains('movie') ||
          titleLow.contains('film') ||
          (media?.title?.toLowerCase().contains('movie') == true) ||
          (media?.title?.toLowerCase().contains('film') == true);

      if (isLikelyMovie) {
        final synth = [
          EpisodeDataModel(
            id: '1',
            number: 1,
            title: animeTitle,
            thumbnail: animeCover ?? media?.cover,
          ),
        ];
        AppLogger.success('Synthesized single movie episode for $animeTitle');
        state = state.copyWith(episodes: synth, isLoading: false);
        return synth;
      }

      AppLogger.fail('No episodes found for $animeTitle');
      state = state.copyWith(isLoading: false, error: 'No episodes found');
      return [];
    }

    AppLogger.success('Successfully loaded ${fetched.length} episodes');
    state = state.copyWith(episodes: fetched, isLoading: false);
    _syncMetadataIfEnabled();

    return fetched;
  }

  Future<void> refreshEpisodes() async {
    final id = state.animeId;
    final title = state.animeTitle;
    final mediaId = state.mediaId;
    if (id == null || title == null) return;

    await fetchEpisodes(
      animeId: id,
      animeTitle: title,
      mediaId: mediaId,
      force: true,
    );
  }

  void reset() {
    _requestGeneration++;
    state = const EpisodeListState();
  }

  List<EpisodeDataModel> _normalizeEpisodeTitles(
    List<EpisodeDataModel> episodes, {
    required String animeTitle,
    required bool isMovie,
  }) {
    return episodes.indexed
        .map((entry) {
          final index = entry.$1;
          final episode = entry.$2;
          final number = episode.number ?? index + 1;
          final title = episode.title?.trim() ?? '';
          final genericTitle = RegExp(
            r'^(episode|ep\.?)\s*\d+$',
            caseSensitive: false,
          ).hasMatch(title);
          if (title.isNotEmpty && !(isMovie && genericTitle)) return episode;
          return episode.copyWith(
            title: isMovie ? animeTitle : 'Episode $number',
            number: number,
          );
        })
        .toList(growable: false);
  }

  void attachMalId(int malId) {
    if (state.malId == malId) return;
    state = state.copyWith(malId: malId);
    _syncMetadataIfEnabled();
  }

  // --- Internal Source Routing ---

  Future<List<EpisodeDataModel>> _fetchEpisodesInternal(
    String? animeId, {
    DMedia? media,
  }) async {
    try {
      final registry = ref.read(animeSourceRegistryProvider);
      final currentKey = ref.read(selectedProviderKeyProvider);
      final isNative = currentKey != null && registry.has(currentKey);

      // Fast path for JustAnime: AniList mediaId is the exact anime ID
      if (currentKey == 'justanime') {
        final directId =
            (int.tryParse(animeId ?? '') != null)
                ? animeId
                : (int.tryParse(state.mediaId ?? '') != null
                    ? state.mediaId
                    : null);
        if (directId != null) {
          final directEps = await _fetchLegacyEpisodes(directId);
          if (directEps.isNotEmpty) {
            state = state.copyWith(animeId: directId);
            return directEps;
          }
        }
      }

      var eps =
          (!isNative && _exp.useExtensions)
              ? await _fetchExtensionEpisodes(media)
              : await _fetchLegacyEpisodes(animeId);

      // Multi-Source Fallback: If 0 episodes returned, search active and fallback sources by title
      if (eps.isEmpty &&
          state.animeTitle != null &&
          state.animeTitle!.isNotEmpty) {
        final candidateKeys = [
          if (currentKey != null) currentKey,
          if (registry.has('justanime') && currentKey != 'justanime')
            'justanime',
          ...registry.keys.where((k) => k != currentKey && k != 'justanime'),
        ];

        final cleanTitle =
            state.animeTitle!
                .replaceAll(':', ' ')
                .replaceAll('-', ' ')
                .replaceAll(RegExp(r'[^\w\s]'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

        for (final altKey in candidateKeys) {
          final altProvider = registry.get(altKey);
          if (altProvider == null) continue;

          try {
            AppLogger.w(
              'Resolving episodes by title on: $altKey for "$cleanTitle"',
            );
            String? matchId;
            if (altKey == 'justanime' &&
                state.mediaId != null &&
                int.tryParse(state.mediaId!) != null) {
              matchId = state.mediaId;
            } else {
              final searchResults = await altProvider
                  .getSearch(
                    cleanTitle.isNotEmpty ? cleanTitle : state.animeTitle!,
                    null,
                    1,
                  )
                  .timeout(const Duration(seconds: 20));
              final altMatch = searchResults.results.firstOrNull;
              matchId = altMatch?.id;
            }
            if (matchId != null && matchId.isNotEmpty) {
              final altResult = await altProvider
                  .getEpisodes(matchId)
                  .timeout(const Duration(seconds: 15));
              final altEps = altResult.episodes ?? [];
              if (altEps.isNotEmpty) {
                AppLogger.success(
                  'Source $altKey found ${altEps.length} episodes!',
                );
                state = state.copyWith(animeId: matchId);
                return altEps;
              }
            }
          } catch (e) {
            AppLogger.d('Fallback $altKey failed: $e');
          }
        }
      }

      return eps;
    } catch (e, st) {
      AppLogger.e('Episode fetch pipeline failed', e, st);
      showAppSnackBar(
        'Episode Fetch',
        'Failed to load episodes',
        type: ContentType.failure,
      );
      reset();
      return [];
    }
  }

  Future<List<EpisodeDataModel>> _fetchExtensionEpisodes(DMedia? media) async {
    media ??= DMedia(title: state.animeTitle, url: state.animeId);
    if (media.url == null) return [];

    AppLogger.d('Fetching episodes via Extensions');
    final details = await _sourceNotifier.getDetails(media);
    final chapters = details?.episodes ?? [];

    final mapped =
        chapters.map((ch) {
          // Safely extract episode number string before parsing
          final numStr =
              ch.episodeNumber.isNotEmpty
                  ? ch.episodeNumber
                  : RegExp(r'\d+').firstMatch(ch.name ?? '')?.group(0) ?? '';

          return EpisodeDataModel(
            title: ch.name,
            url: ch.url,
            isFiller: false,
            number: int.tryParse(numStr),
          );
        }).toList();

    // Sort ascending if valid numbers exist
    if (mapped.isNotEmpty && mapped.first.number != null) {
      mapped.sort((a, b) => (a.number ?? 999999).compareTo(b.number ?? 999999));
    }

    return mapped;
  }

  Future<List<EpisodeDataModel>> _fetchLegacyEpisodes(String? animeId) async {
    final provider = _animeProvider;
    if (provider == null || animeId == null) {
      AppLogger.warning('Legacy provider or AnimeID is null');
      return [];
    }

    var targetId = animeId;
    if (provider.providerName == 'justanime' &&
        int.tryParse(animeId) == null &&
        state.mediaId != null &&
        int.tryParse(state.mediaId!) != null) {
      targetId = state.mediaId!;
    }

    AppLogger.d(
      'Fetching episodes via Legacy Provider: $provider (id: $targetId)',
    );
    try {
      return (await provider.getEpisodes(targetId)).episodes ?? [];
    } catch (e) {
      AppLogger.w('Direct legacy episode fetch failed: $e');
      return [];
    }
  }

  // --- Metadata & Episode Name Syncing ---

  static final Map<String, List<EpisodeDataModel>> _justAnimeTitlesCache = {};
  static final Map<String, Map<int, String>> _tvMazeThumbnailCache = {};

  void _syncMetadataIfEnabled() {
    if (state.episodes.isEmpty || state.animeTitle == null) {
      return;
    }

    state = state.copyWith(isJikanSyncing: true);
    AppLogger.i(
      'Initializing metadata and episode name sync for: ${state.animeTitle}',
    );

    // unawaited ensures Riverpod doesn't block while fetching non-critical metadata
    unawaited(
      _runMetadataSync().whenComplete(
        () => state = state.copyWith(isJikanSyncing: false),
      ),
    );
  }

  Future<void> _runMetadataSync() async {
    // 1. Instant Filler Sync via AnimeFillerService (AnimeFillerList + local cache)
    await _syncFillerInfo();

    // 2. Fetch and enrich episode names & rich metadata from JustAnime
    await _syncWithJustAnime();

    // 3. Long-running shows often have only a small subset of images in the
    // streaming catalogue. TVMaze supplies episode stills independently of
    // playback, so it is safe to use only for missing thumbnails.
    await _syncMissingThumbnailsFromTvMaze();

    // 4. Fallback / supplementary title and metadata sync via Jikan (MAL)
    await _syncWithJikan();
  }

  Future<void> _syncMissingThumbnailsFromTvMaze() async {
    final currentEpisodes = state.episodes;
    final currentTitle = state.animeTitle?.trim();
    if (currentEpisodes.length < 100 || currentTitle == null) return;

    final missingCount =
        currentEpisodes
            .where((episode) => episode.thumbnail?.trim().isNotEmpty != true)
            .length;
    if (missingCount < currentEpisodes.length ~/ 2) return;

    final mediaId = state.mediaId;
    final animeId = state.animeId;
    final cacheKey = currentTitle.toLowerCase();

    try {
      var thumbnails = _tvMazeThumbnailCache[cacheKey];
      if (thumbnails == null) {
        final searchUri = Uri.https('api.tvmaze.com', '/search/shows', {
          'q': currentTitle,
        });
        final searchResponse = await UniversalHttpClient.instance
            .get(searchUri)
            .timeout(const Duration(seconds: 15));
        final searchResults = jsonDecode(searchResponse.body) as List<dynamic>;
        final normalizedTitle = _normalizeMetadataTitle(currentTitle);

        Map<String, dynamic>? matchedShow;
        for (final result in searchResults) {
          final show = Map<String, dynamic>.from(
            (result as Map)['show'] as Map,
          );
          final showName = show['name']?.toString() ?? '';
          final showType = show['type']?.toString().toLowerCase() ?? '';
          if (_normalizeMetadataTitle(showName) == normalizedTitle &&
              showType == 'animation') {
            matchedShow = show;
            break;
          }
        }
        if (matchedShow == null) return;

        final showId = matchedShow['id'];
        if (showId == null) return;
        final episodeResponse = await UniversalHttpClient.instance
            .get(Uri.parse('https://api.tvmaze.com/shows/$showId/episodes'))
            .timeout(const Duration(seconds: 25));
        final rawEpisodes = jsonDecode(episodeResponse.body) as List<dynamic>;
        thumbnails = <int, String>{};
        var absoluteNumber = 0;
        for (final raw in rawEpisodes) {
          final episode = Map<String, dynamic>.from(raw as Map);
          if (episode['type']?.toString().toLowerCase() != 'regular') continue;
          absoluteNumber++;
          final image = episode['image'];
          if (image is! Map) continue;
          final url =
              image['original']?.toString() ?? image['medium']?.toString();
          if (url != null && url.isNotEmpty) thumbnails[absoluteNumber] = url;
        }
        _tvMazeThumbnailCache[cacheKey] = thumbnails;
      }

      if (thumbnails.isEmpty) return;
      final latestState = state;
      if (latestState.mediaId != mediaId ||
          latestState.animeId != animeId ||
          latestState.animeTitle != currentTitle) {
        return;
      }

      final updated = List<EpisodeDataModel>.of(latestState.episodes);
      var added = 0;
      for (var index = 0; index < updated.length; index++) {
        final episode = updated[index];
        if (episode.thumbnail?.trim().isNotEmpty == true) continue;
        final number = episode.number ?? index + 1;
        final thumbnail = thumbnails[number];
        if (thumbnail == null) continue;
        updated[index] = episode.copyWith(thumbnail: thumbnail);
        added++;
      }
      if (added > 0) {
        state = state.copyWith(episodes: updated);
        AppLogger.success(
          'Added $added missing episode thumbnails from TVMaze for "$currentTitle"',
        );
      }
    } catch (error) {
      AppLogger.d('TVMaze thumbnail enrichment skipped: $error');
    }
  }

  String _normalizeMetadataTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  Future<void> _syncFillerInfo() async {
    try {
      final currentTitle = state.animeTitle!;
      final malId = state.malId;

      final fillerInfo = await AnimeFillerService().getFillerInfo(
        title: currentTitle,
        malId: malId,
      );

      if ((fillerInfo.fillers.isNotEmpty || fillerInfo.mixed.isNotEmpty) &&
          state.episodes.isNotEmpty) {
        final updated = List<EpisodeDataModel>.of(state.episodes);
        var fillerCount = 0;
        for (var i = 0; i < updated.length; i++) {
          final epNum = updated[i].number ?? (i + 1);
          final isFiller =
              fillerInfo.fillers.contains(epNum) || updated[i].isFiller == true;
          final isMixed = fillerInfo.mixed.contains(epNum);
          if (isFiller != (updated[i].isFiller ?? false) ||
              isMixed != (updated[i].isMixed ?? false)) {
            updated[i] = updated[i].copyWith(
              isFiller: isFiller,
              isMixed: isMixed,
            );
            if (isFiller || isMixed) fillerCount++;
          }
        }
        if (fillerCount > 0) {
          AppLogger.success(
            'Highlighted $fillerCount filler/mixed episodes for "$currentTitle"',
          );
          state = state.copyWith(episodes: updated);
        }
      }
    } catch (e) {
      AppLogger.d('AnimeFillerService sync error: $e');
    }
  }

  Future<void> _syncWithJustAnime() async {
    if (state.episodes.isEmpty || state.animeTitle == null) return;

    final currentTitle = state.animeTitle!;
    final mediaId = state.mediaId;
    final animeId = state.animeId;

    try {
      final registry = ref.read(animeSourceRegistryProvider);
      final justAnime = registry.get('justanime') ?? JustAnimeProvider();

      List<EpisodeDataModel>? justAnimeEps;

      // 1. Check in-memory cache
      final cacheKey = mediaId ?? currentTitle.toLowerCase().trim();
      if (_justAnimeTitlesCache.containsKey(cacheKey)) {
        justAnimeEps = _justAnimeTitlesCache[cacheKey];
      }

      // 2. Direct AniList ID lookup (JustAnime uses exact AniList IDs for all anime)
      if (justAnimeEps == null && mediaId != null && mediaId.isNotEmpty) {
        try {
          AppLogger.d(
            'Enriching episode names via JustAnime direct AniList ID: $mediaId',
          );
          final res = await justAnime
              .getEpisodes(mediaId)
              .timeout(const Duration(seconds: 15));
          if (res.episodes != null && res.episodes!.isNotEmpty) {
            justAnimeEps = res.episodes;
            _justAnimeTitlesCache[mediaId] = res.episodes!;
            _justAnimeTitlesCache[cacheKey] = res.episodes!;
          }
        } catch (e) {
          AppLogger.d('JustAnime direct AniList ID fetch error: $e');
        }
      }

      // 3. Fallback: Search JustAnime by cleaned title
      if (justAnimeEps == null || justAnimeEps.isEmpty) {
        try {
          final cleanTitle =
              currentTitle
                  .replaceAll(
                    RegExp(
                      r'\s*\((?:Dub|Sub|TV|Audio|Uncensored)[^)]*\)',
                      caseSensitive: false,
                    ),
                    '',
                  )
                  .replaceAll(
                    RegExp(
                      r'\s*\[(?:Dub|Sub|TV|Audio|Uncensored)[^\]]*\]',
                      caseSensitive: false,
                    ),
                    '',
                  )
                  .replaceAll(
                    RegExp(r'\s*-\s*(?:Dub|Sub)$', caseSensitive: false),
                    '',
                  )
                  .replaceAll('-', ' ')
                  .replaceAll(':', ' ')
                  .replaceAll(RegExp(r'[^\w\s]'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();

          final searchTitle = cleanTitle.isNotEmpty ? cleanTitle : currentTitle;
          AppLogger.d('Searching JustAnime for episode names: "$searchTitle"');

          final searchPage = await justAnime
              .getSearch(searchTitle, null, 1)
              .timeout(const Duration(seconds: 10));
          if (searchPage.results.isNotEmpty) {
            final match =
                searchPage.results.firstWhereOrNull(
                  (r) => r.id == mediaId || r.anilistId?.toString() == mediaId,
                ) ??
                searchPage.results.firstOrNull;

            final matchId = match?.id;
            if (matchId != null && matchId.isNotEmpty) {
              final res = await justAnime
                  .getEpisodes(matchId)
                  .timeout(const Duration(seconds: 15));
              if (res.episodes != null && res.episodes!.isNotEmpty) {
                justAnimeEps = res.episodes;
                _justAnimeTitlesCache[cacheKey] = res.episodes!;
                if (mediaId != null) {
                  _justAnimeTitlesCache[mediaId] = res.episodes!;
                }
              }
            }
          }
        } catch (e) {
          AppLogger.d('JustAnime title search for episode names error: $e');
        }
      }

      // 4. Apply JustAnime episode names and metadata
      if (justAnimeEps != null && justAnimeEps.isNotEmpty) {
        final justEpByNum = <int, EpisodeDataModel>{};
        for (final ep in justAnimeEps) {
          if (ep.number != null) {
            justEpByNum[ep.number!] = ep;
          }
        }

        final updated = List<EpisodeDataModel>.of(state.episodes);
        int enrichedTitleCount = 0;
        int enrichedThumbnailCount = 0;

        for (var i = 0; i < updated.length; i++) {
          final epNum = updated[i].number ?? (i + 1);
          final justEp = justEpByNum[epNum];
          if (justEp == null) continue;

          var ep = updated[i];
          bool modified = false;

          // Title: enrich if current is generic or if JustAnime has a real title
          final currentEpTitle = ep.title?.trim() ?? '';
          final isCurrentGeneric =
              currentEpTitle.isEmpty ||
              RegExp(
                r'^(episode|ep\.?)\s*\d+$',
                caseSensitive: false,
              ).hasMatch(currentEpTitle);

          final justTitle = justEp.title?.trim();
          final isJustGeneric =
              justTitle == null ||
              justTitle.isEmpty ||
              RegExp(
                r'^(episode|ep\.?)\s*\d+$',
                caseSensitive: false,
              ).hasMatch(justTitle);

          // Never replace a real source title with a catalogue enrichment.
          // A stale match previously labelled One Piece 183+ as Alabasta
          // while the correct Skypiea stream was playing.
          if (!isJustGeneric && isCurrentGeneric) {
            ep = ep.copyWith(title: justTitle);
            modified = true;
            enrichedTitleCount++;
          }

          // Thumbnail: if current is empty or missing, use JustAnime's HD TMDB thumbnail
          if ((ep.thumbnail == null || ep.thumbnail!.isEmpty) &&
              justEp.thumbnail != null &&
              justEp.thumbnail!.isNotEmpty) {
            ep = ep.copyWith(thumbnail: justEp.thumbnail);
            modified = true;
            enrichedThumbnailCount++;
          }

          // Description: if current is empty, use JustAnime's description
          if ((ep.description == null || ep.description!.isEmpty) &&
              justEp.description != null &&
              justEp.description!.isNotEmpty) {
            ep = ep.copyWith(description: justEp.description);
            modified = true;
          }

          // Filler: if JustAnime marks it as filler
          if (justEp.isFiller == true && ep.isFiller != true) {
            ep = ep.copyWith(isFiller: true);
            modified = true;
          }

          if (modified) {
            updated[i] = ep;
          }
        }

        // Metadata sync runs in the background. Never let a late response from
        // the previously opened anime overwrite the current episode list.
        final isSameAnime =
            state.mediaId == mediaId &&
            state.animeId == animeId &&
            state.animeTitle == currentTitle &&
            state.episodes.length == updated.length;
        final metadataChanged =
            isSameAnime &&
            updated.indexed.any(
              (entry) => !identical(entry.$2, state.episodes[entry.$1]),
            );

        if (isSameAnime && metadataChanged) {
          AppLogger.success(
            'Enriched $enrichedTitleCount titles and '
            '$enrichedThumbnailCount thumbnails from JustAnime for "$currentTitle"',
          );
          state = state.copyWith(episodes: updated);
        }
      }
    } catch (e) {
      AppLogger.w('JustAnime episode names sync error: $e');
    }
  }

  Future<void> _syncWithJikan() async {
    try {
      final currentTitle = state.animeTitle!;
      int? malId = state.malId;

      // Title and metadata sync via Jikan (MAL) as fallback
      if (malId == null) {
        var matches = state.jikanMatches;

        // Only search Jikan if we haven't already cached the matches
        if (matches.isEmpty) {
          final cleanedTitle =
              currentTitle
                  .replaceAll(
                    RegExp(
                      r'\s*\((?:Dub|Sub|TV|Audio|Uncensored)[^)]*\)',
                      caseSensitive: false,
                    ),
                    '',
                  )
                  .replaceAll(
                    RegExp(
                      r'\s*\[(?:Dub|Sub|TV|Audio|Uncensored)[^\]]*\]',
                      caseSensitive: false,
                    ),
                    '',
                  )
                  .replaceAll(
                    RegExp(r'\s*-\s*(?:Dub|Sub)$', caseSensitive: false),
                    '',
                  )
                  .trim();
          final searchTitle =
              cleanedTitle.isNotEmpty ? cleanedTitle : currentTitle;

          final searchResults = await _jikan.getSearch(
            title: searchTitle,
            limit: 10,
          );
          matches = getBestMatches<JikanMedia>(
            results: searchResults,
            title: searchTitle,
            nameSelector: (e) => e.title,
            idSelector: (e) => e.malId.toString(),
          );
        }

        if (matches.isNotEmpty && matches.first.similarity >= 0.55) {
          state = state.copyWith(jikanMatches: matches);
          malId = matches.first.result.malId;
        }
      }

      if (malId != null && malId > 0) {
        AppLogger.d('Fetching MAL episode data for ID: $malId');
        final allJikanEpisodes = <JikanEpisode>[];
        int page = 1;
        final totalNeeded = state.episodes.length;

        while (allJikanEpisodes.length < totalNeeded && page <= 15) {
          final jikanEpisodes = await _jikan
              .getEpisodes(malId, page)
              .timeout(const Duration(seconds: 10));
          if (jikanEpisodes.isEmpty) break;
          allJikanEpisodes.addAll(jikanEpisodes);
          if (jikanEpisodes.length < 100) break; // Last page
          page++;
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (allJikanEpisodes.isNotEmpty) {
          // Create a lookup by malId (episode number in Jikan)
          final titleByEpNum = <int, String>{};
          final fillerByEpNum = <int, bool>{};
          for (final jEp in allJikanEpisodes) {
            fillerByEpNum[jEp.malId] = jEp.filler;
            if (jEp.title.isNotEmpty) {
              titleByEpNum[jEp.malId] = jEp.title;
            }
          }

          // Create a mutable copy of the list to update titles and fillers
          final updated = List<EpisodeDataModel>.of(state.episodes);
          int syncedCount = 0;

          for (var i = 0; i < updated.length; i++) {
            final epNum = updated[i].number ?? (i + 1);
            final syncedTitle = titleByEpNum[epNum];
            final isFiller =
                fillerByEpNum[epNum] == true || updated[i].isFiller == true;
            if (isFiller && updated[i].isFiller != true) {
              updated[i] = updated[i].copyWith(isFiller: true);
            }
            if (syncedTitle != null && syncedTitle.isNotEmpty) {
              final currentEpTitle = updated[i].title ?? '';
              final currentPlainTitle =
                  currentEpTitle
                      .replaceFirst(
                        RegExp(r'^EP\s*\d+\s*-\s*', caseSensitive: false),
                        '',
                      )
                      .trim();
              final isGeneric =
                  currentEpTitle.isEmpty ||
                  RegExp(
                    r'^(episode|ep\.?)\s*\d+$',
                    caseSensitive: false,
                  ).hasMatch(currentEpTitle.trim());

              // Jikan is keyed by the real episode number and becomes the
              // authoritative display title after the MAL series is matched.
              if (isGeneric || currentEpTitle != 'EP $epNum - $syncedTitle') {
                updated[i] = updated[i].copyWith(
                  title: 'EP $epNum - $syncedTitle',
                  // Title and image arrive as one catalogue record. If its
                  // title disagrees with Jikan's number-keyed title, its image
                  // is from that same wrong record (seen on One Piece 183-200),
                  // so fall back to the anime cover instead of showing a false
                  // episode thumbnail.
                  clearThumbnail:
                      !isGeneric &&
                      currentPlainTitle.toLowerCase() !=
                          syncedTitle.trim().toLowerCase(),
                );
                syncedCount++;
              }
            }
          }

          if (syncedCount > 0) {
            AppLogger.success(
              'Successfully synced $syncedCount episode titles from Jikan',
            );
          }
          state = state.copyWith(episodes: updated);
        }
      }
    } catch (e, st) {
      AppLogger.w('Metadata and filler sync failed: $e', e, st);
    }
  }
}
