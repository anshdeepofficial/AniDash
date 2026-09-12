import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/core/jikan/jikan_service.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';
import 'package:ani_dash/shared/providers/anime_repo_provider.dart';
import 'package:ani_dash/shared/providers/anilist_service_provider.dart';
import 'package:ani_dash/shared/providers/anime_match_service.dart';

part 'details_page_notifier.g.dart';

@immutable
class DetailsPageState {
  final AsyncValue<UniversalMedia> details;
  final bool isSearchingMatch;
  final String? bestMatchName;
  final String? animeIdForSource;
  final String selectedRange;
  final List<String> rangeOptions;
  final bool isSortedDescending;
  final String? error;

  const DetailsPageState({
    this.details = const AsyncLoading(),
    this.isSearchingMatch = false,
    this.bestMatchName,
    this.animeIdForSource,
    this.selectedRange = 'All',
    this.rangeOptions = const ['All'],
    this.isSortedDescending = false,
    this.error,
  });

  DetailsPageState copyWith({
    AsyncValue<UniversalMedia>? details,
    bool? isSearchingMatch,
    String? bestMatchName,
    String? animeIdForSource,
    String? selectedRange,
    List<String>? rangeOptions,
    bool? isSortedDescending,
    String? error,
    bool setBestMatchNull = false,
  }) {
    return DetailsPageState(
      details: details ?? this.details,
      isSearchingMatch: isSearchingMatch ?? this.isSearchingMatch,
      bestMatchName:
          setBestMatchNull ? null : (bestMatchName ?? this.bestMatchName),
      animeIdForSource:
          setBestMatchNull ? null : (animeIdForSource ?? this.animeIdForSource),
      selectedRange: selectedRange ?? this.selectedRange,
      rangeOptions: rangeOptions ?? this.rangeOptions,
      isSortedDescending: isSortedDescending ?? this.isSortedDescending,
      error: error ?? this.error,
    );
  }
}

@riverpod
class DetailsPageNotifier extends _$DetailsPageNotifier {
  @override
  DetailsPageState build(String animeId) {
    return const DetailsPageState();
  }

  void init(UniversalMedia media) {
    if (state.details is AsyncLoading) {
      state = state.copyWith(details: AsyncData(media));
      fetchDetails();
      _fetchEpisodes(media.title);
    }
  }

  Future<void> fetchDetails() async {
    final currentData = state.details.value;

    try {
      final anilistId = int.tryParse(currentData?.id ?? animeId);
      UniversalMedia? fresh;
      if (anilistId != null) {
        try {
          fresh = await ref
              .read(anilistServiceProvider)
              .getAnimeDetails(anilistId)
              .timeout(const Duration(seconds: 15));
        } catch (error) {
          // AniList outages must not prevent the MAL/Jikan fallback below.
          AppLogger.w('AniList details unavailable; trying fallback: $error');
        }
      }
      if (fresh == null && currentData != null) {
        var malId = int.tryParse(currentData.idMal ?? '');
        if (malId == null) {
          final title =
              currentData.title.english ?? currentData.title.romaji ?? '';
          final matches = await JikanService().searchUniversal(title);
          malId =
              matches.isEmpty ? null : int.tryParse(matches.first.idMal ?? '');
        }
        if (malId != null) {
          final jikan = await JikanService().getFullDetails(malId);
          if (jikan != null) {
            fresh = _mergeJikanDetails(currentData, malId, jikan);
          }
        }
      }
      if (fresh == null) {
        final repo = ref.read(animeRepositoryProvider);
        final fallbackId =
            int.tryParse(currentData?.idMal ?? '') ??
            int.tryParse(animeId) ??
            0;
        fresh = await repo
            .getAnimeDetails(fallbackId)
            .timeout(const Duration(seconds: 15));
      }

      if (!ref.mounted) return;

      if (fresh != null) {
        final enriched = fresh.copyWith(
          description:
              fresh.description?.trim().isNotEmpty == true
                  ? fresh.description
                  : currentData?.description,
          episodes: fresh.episodes ?? currentData?.episodes,
          duration: fresh.duration ?? currentData?.duration,
          staff: fresh.staff.isNotEmpty ? fresh.staff : currentData?.staff,
          studios:
              fresh.studios.isNotEmpty ? fresh.studios : currentData?.studios,
          relations:
              fresh.relations.isNotEmpty
                  ? fresh.relations
                  : currentData?.relations,
          characters:
              fresh.characters.isNotEmpty
                  ? fresh.characters
                  : currentData?.characters ?? const [],
        );
        state = state.copyWith(details: AsyncData(enriched));
        if (state.animeIdForSource == null) {
          _fetchEpisodes(enriched.title);
        }
      } else if (currentData != null) {
        state = state.copyWith(details: AsyncData(currentData));
      }
    } catch (e, st) {
      AppLogger.e('Failed to fetch anime details for $animeId', e, st);
      if (!ref.mounted) return;
      if (currentData != null) {
        state = state.copyWith(details: AsyncData(currentData));
      } else {
        state = state.copyWith(details: AsyncError(e, st));
      }
    }
  }

  UniversalMedia _mergeJikanDetails(
    UniversalMedia current,
    int malId,
    ({Map<String, dynamic> details, List<dynamic> staff}) jikan,
  ) {
    final data = jikan.details;
    final studios =
        (data['studios'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item))
            .map(
              (item) => UniversalStudio(
                name: item['name']?.toString() ?? '',
                isMain: true,
              ),
            )
            .where((studio) => studio.name.isNotEmpty)
            .toList();
    final staff =
        jikan.staff.map((item) => Map<String, dynamic>.from(item)).map((item) {
          final person = Map<String, dynamic>.from(item['person'] ?? {});
          final images = Map<String, dynamic>.from(person['images'] ?? {});
          final jpg = Map<String, dynamic>.from(images['jpg'] ?? {});
          return UniversalStaff(
            id: person['mal_id'] as int?,
            name: UniversalStaffName(full: person['name']?.toString()),
            image: UniversalStaffImage(
              large: jpg['image_url']?.toString(),
              medium: jpg['image_url']?.toString(),
            ),
            role: (item['positions'] as List? ?? const []).join(', '),
          );
        }).toList();
    final genres =
        <String>{
          for (final key in const [
            'genres',
            'explicit_genres',
            'themes',
            'demographics',
          ])
            for (final item in data[key] as List? ?? const [])
              if (item['name']?.toString().isNotEmpty == true)
                item['name'].toString(),
        }.toList();
    final duration = int.tryParse(
      RegExp(r'\d+').firstMatch(data['duration']?.toString() ?? '')?.group(0) ??
          '',
    );
    final trailer = Map<String, dynamic>.from(data['trailer'] ?? {});
    final trailerId = trailer['youtube_id']?.toString();
    return current.copyWith(
      idMal: malId.toString(),
      description: data['synopsis']?.toString(),
      episodes: data['episodes'] as int?,
      duration: duration,
      averageScore:
          data['score'] is num ? (data['score'] as num).toDouble() * 10 : null,
      popularity: data['popularity'] as int?,
      genres: genres.isNotEmpty ? genres : null,
      synonyms:
          (data['title_synonyms'] as List? ?? const [])
              .map((item) => item.toString())
              .toList(),
      source: data['source']?.toString(),
      studios: studios,
      staff: staff,
      trailer:
          trailerId == null
              ? null
              : UniversalTrailer(
                id: trailerId,
                site: 'youtube',
                thumbnail: trailer['images']?['large_image_url']?.toString(),
              ),
      siteUrl: data['url']?.toString(),
    );
  }

  Future<void> _fetchEpisodes(
    UniversalTitle mediaTitle, {
    bool force = false,
  }) async {
    if (!ref.mounted) return;

    final episodeListState = ref.read(episodeListProvider);

    if (!force &&
        state.animeIdForSource != null &&
        (episodeListState.episodes.isNotEmpty || episodeListState.isLoading)) {
      return;
    }

    AppLogger.d(
      "Fetching episodes for: ${mediaTitle.english ?? mediaTitle.romaji}",
    );

    if (force && state.animeIdForSource == null) {
      state = state.copyWith(setBestMatchNull: true);
    }

    try {
      if (state.animeIdForSource == null) {
        state = state.copyWith(isSearchingMatch: true);

        // Reset old episodes to avoid bleeding from previously opened anime
        ref.read(episodeListProvider.notifier).reset();

        // Try to restore source first
        final restored =
            force
                ? null
                : await ref
                    .read(animeMatchServiceProvider)
                    .restoreSource(animeId, showSnackbar: false);

        if (!ref.mounted) return;

        if (restored != null) {
          state = state.copyWith(
            animeIdForSource: restored.id,
            bestMatchName: restored.name,
          );
        } else {
          // Fallback to search if restoration failed
          final isAdultMedia =
              state.details.value?.isAdult == true ||
              state.details.value?.isMature == true;
          final match = await ref
              .read(animeMatchServiceProvider)
              .findBestMatch(
                mediaTitle,
                isAdult: isAdultMedia,
                mediaId: animeId,
                malId: state.details.value?.idMal,
              );

          if (!ref.mounted) return;

          if (match == null) {
            _fail(
              'Anime Match',
              'No suitable match found for any title.',
              ContentType.failure,
            );
            return;
          }

          state = state.copyWith(
            animeIdForSource: match.id,
            bestMatchName: match.name,
          );
        }
      }

      state = state.copyWith(isSearchingMatch: false);

      if (state.bestMatchName == null || state.animeIdForSource == null) {
        return;
      }

      await ref
          .read(episodeListProvider.notifier)
          .fetchEpisodes(
            animeTitle: state.bestMatchName!,
            animeId: state.animeIdForSource,
            force: force,
            malId: int.tryParse(state.details.value?.idMal ?? ''),
            media: DMedia(
              title: state.bestMatchName,
              url: state.animeIdForSource,
              cover:
                  state.details.value?.coverImage.large ??
                  state.details.value?.coverImage.medium,
            ),
          );

      if (!ref.mounted) return;
      final currentListState = ref.read(episodeListProvider);
      if (currentListState.animeId != null &&
          currentListState.animeId != state.animeIdForSource) {
        state = state.copyWith(animeIdForSource: currentListState.animeId);
      }
      _updateRanges();
    } catch (err, stack) {
      AppLogger.e(err, stack);
      if (ref.mounted) {
        state = state.copyWith(isSearchingMatch: false, error: err.toString());
      }
    } finally {
      if (ref.mounted && state.isSearchingMatch) {
        state = state.copyWith(isSearchingMatch: false);
      }
    }
  }

  void _fail(String title, String message, ContentType type) {
    if (!ref.mounted) return;
    state = state.copyWith(isSearchingMatch: false, error: message);
  }

  Future<void> refresh() async {
    final title = state.details.value?.title;
    if (title != null) {
      state = state.copyWith(
        setBestMatchNull: true,
        selectedRange: 'All',
        isSortedDescending: false,
        error: null,
      );
      await _fetchEpisodes(title, force: true);
    }
  }

  void setManualMatch(String id, String name) {
    state = state.copyWith(animeIdForSource: id, bestMatchName: name);
    final title = state.details.value?.title;
    if (title != null) {
      _fetchEpisodes(title, force: true);
    }
  }

  void updateRange(String range) {
    state = state.copyWith(selectedRange: range);
  }

  void toggleSort() {
    state = state.copyWith(isSortedDescending: !state.isSortedDescending);
  }

  void _updateRanges() {
    final episodes = ref.read(episodeListProvider).episodes;
    final total = episodes.length;
    final ranges = <String>['All'];
    for (int i = 0; i < total; i += 50) {
      final start = i + 1;
      final end = (i + 50).clamp(0, total);
      ranges.add('$start–$end');
    }

    if (!listEquals(state.rangeOptions, ranges)) {
      state = state.copyWith(rangeOptions: ranges);
    }
  }
}
