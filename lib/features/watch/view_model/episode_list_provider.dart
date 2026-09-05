import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:collection/collection.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ani_dash/core/jikan/jikan_service.dart';
import 'package:ani_dash/core/jikan/models/jikan_media.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/models/settings/experimental_model.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'package:ani_dash/helpers/matcher.dart';
import 'package:ani_dash/main.dart';

part 'episode_list_provider.g.dart';

@immutable
class EpisodeListState {
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
  }) {
    return EpisodeListState(
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      animeCover: animeCover ?? this.animeCover,
      malId: malId ?? this.malId,
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

  ExperimentalFeaturesModel get _exp => ref.read(experimentalProvider);
  AnimeProvider? get _animeProvider => ref.read(selectedAnimeProvider);
  SourceNotifier get _sourceNotifier => ref.read(sourceProvider.notifier);

  @override
  EpisodeListState build() => const EpisodeListState();

  // --- Core Fetching Logic ---

  Future<List<EpisodeDataModel>> fetchEpisodes({
    required String animeTitle,
    String? animeId,
    String? animeCover,
    required bool force,
    List<EpisodeDataModel> episodes = const [],
    DMedia? media,
    int? malId,
    bool isAdult = false,
  }) async {
    // 1. Check Cache
    if (!force && state.episodes.isNotEmpty && state.animeId == animeId) {
      AppLogger.d('Episode list cache hit for: $animeTitle');
      return state.episodes;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      animeId: animeId,
      animeTitle: animeTitle,
      animeCover: animeCover ?? media?.cover,
      malId: malId,
      isAdult: isAdult,
    );
    AppLogger.section('Fetching Episodes: $animeTitle');

    // 2. Use provided episodes if available
    if (episodes.isNotEmpty) {
      AppLogger.success('Using ${episodes.length} pre-provided episodes');
      state = state.copyWith(episodes: episodes, isLoading: false);
      _syncJikanIfEnabled();
      return episodes;
    }

    // 3. Fetch from remote sources
    final fetched = await _fetchEpisodesInternal(animeId, media: media);

    if (fetched.isEmpty) {
      AppLogger.fail('No episodes found for $animeTitle');
      state = state.copyWith(isLoading: false, error: 'No episodes found');
      return [];
    }

    AppLogger.success('Successfully loaded ${fetched.length} episodes');
    state = state.copyWith(episodes: fetched, isLoading: false);
    _syncJikanIfEnabled();

    return fetched;
  }

  Future<void> refreshEpisodes() async {
    final id = state.animeId;
    final title = state.animeTitle;
    if (id == null || title == null) return;

    await fetchEpisodes(animeId: id, animeTitle: title, force: true);
  }

  void reset() => state = const EpisodeListState();

  // --- Internal Source Routing ---

  Future<List<EpisodeDataModel>> _fetchEpisodesInternal(
    String? animeId, {
    DMedia? media,
  }) async {
    try {
      final registry = ref.read(animeSourceRegistryProvider);
      final currentKey = ref.read(selectedProviderKeyProvider);
      final isNative = currentKey != null && registry.has(currentKey);

      var eps = (!isNative && _exp.useExtensions)
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

        for (final altKey in candidateKeys) {
          final altProvider = registry.get(altKey);
          if (altProvider == null) continue;

          try {
            AppLogger.w(
              'Resolving episodes by title on: $altKey for "${state.animeTitle}"',
            );
            final searchResults = await altProvider
                .getSearch(state.animeTitle!, null, 1)
                .timeout(const Duration(seconds: 8));
            final altMatch = searchResults.results.firstOrNull;
            final matchId = altMatch?.id;
            if (matchId != null && matchId.isNotEmpty) {
              final altResult = await altProvider
                  .getEpisodes(matchId)
                  .timeout(const Duration(seconds: 15));
              final altEps = altResult.episodes ?? [];
              if (altEps.isNotEmpty) {
                AppLogger.success(
                  'Source $altKey found ${altEps.length} episodes!',
                );
                ref.read(selectedProviderKeyProvider.notifier).select(altKey);
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

    AppLogger.d('Fetching episodes via Legacy Provider: $provider');
    try {
      return (await provider.getEpisodes(animeId)).episodes ?? [];
    } catch (e) {
      AppLogger.w('Direct legacy episode fetch failed: $e');
      return [];
    }
  }

  // --- Jikan Metadata Syncing ---

  void _syncJikanIfEnabled() {
    if (state.episodes.isEmpty || state.animeTitle == null) {
      return;
    }

    state = state.copyWith(isJikanSyncing: true);
    AppLogger.i('Initializing Jikan title sync for: ${state.animeTitle}');

    // unawaited ensures Riverpod doesn't block while fetching non-critical metadata
    unawaited(
      _syncWithJikan().whenComplete(
        () => state = state.copyWith(isJikanSyncing: false),
      ),
    );
  }

  Future<void> _syncWithJikan() async {
    try {
      int? malId = state.malId;

      if (malId == null) {
        var matches = state.jikanMatches;

        // Only search Jikan if we haven't already cached the matches
        if (matches.isEmpty) {
          final cleanedTitle =
              state.animeTitle!
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
              cleanedTitle.isNotEmpty ? cleanedTitle : state.animeTitle!;

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

        if (matches.isEmpty || matches.first.similarity < 0.55) {
          AppLogger.warning(
            'No strong Jikan match found for title sync. Aborting sync.',
          );
          return;
        }

        state = state.copyWith(jikanMatches: matches);
        malId = matches.first.result.malId;
      }

      AppLogger.d('Fetching MAL episode data for ID: $malId');
      final allJikanEpisodes = <JikanEpisode>[];
      int page = 1;
      final totalNeeded = state.episodes.length;

      while (allJikanEpisodes.length < totalNeeded) {
        final jikanEpisodes = await _jikan.getEpisodes(malId, page);
        if (jikanEpisodes.isEmpty) break;
        allJikanEpisodes.addAll(jikanEpisodes);
        if (jikanEpisodes.length < 100) break; // Last page
        page++;
        if (page > 15) break; // Safety cap ~1500 episodes
      }

      if (allJikanEpisodes.isEmpty) return;

      // Create a lookup by malId (episode number in Jikan)
      final titleByEpNum = <int, String>{};
      for (final jEp in allJikanEpisodes) {
        if (jEp.title.isNotEmpty &&
            !jEp.title.toLowerCase().startsWith('episode ')) {
          titleByEpNum[jEp.malId] = jEp.title;
        } else if (jEp.title.isNotEmpty) {
          titleByEpNum[jEp.malId] = jEp.title;
        }
      }

      // Create a mutable copy of the list to update titles
      final updated = List<EpisodeDataModel>.of(state.episodes);
      int syncedCount = 0;

      for (var i = 0; i < updated.length; i++) {
        final epNum = updated[i].number ?? (i + 1);
        final syncedTitle = titleByEpNum[epNum];
        if (syncedTitle != null && syncedTitle.isNotEmpty) {
          // If extension already gave a real title (not just "Episode X"), keep it or enrich it
          final currentTitle = updated[i].title ?? '';
          final isGeneric =
              currentTitle.isEmpty ||
              RegExp(
                r'^(episode|ep\.?)\s*\d+$',
                caseSensitive: false,
              ).hasMatch(currentTitle.trim());

          if (isGeneric) {
            updated[i] = updated[i].copyWith(title: 'EP $epNum - $syncedTitle');
            syncedCount++;
          }
        }
      }

      AppLogger.success(
        'Successfully synced $syncedCount episode titles from Jikan',
      );
      state = state.copyWith(episodes: updated);
    } catch (e, st) {
      AppLogger.w('Jikan sync failed dynamically', e, st);
    }
  }
}
