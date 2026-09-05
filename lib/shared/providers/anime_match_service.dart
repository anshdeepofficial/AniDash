import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ani_dash/core/models/anime/anime_model.dep.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/core/repositories/source_preference_repository.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/helpers/matcher.dart';
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/settings/content_settings_notifier.dart';
import 'package:collection/collection.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';

part 'anime_match_service.g.dart';

@Riverpod(keepAlive: true)
AnimeMatchService animeMatchService(Ref ref) {
  return AnimeMatchService(ref);
}

class AnimeMatchService {
  final Ref _ref;

  AnimeMatchService(this._ref);

  /// Finds the best match for the given [title] using the active source.
  ///
  /// Iterates through English, Romaji, and Native titles.
  /// Returns the best match as a [BaseAnimeModel] or null if no match is found.
  Future<BaseAnimeModel?> findBestMatch(UniversalTitle title) async {
    final titles =
        [title.english, title.romaji, title.native]
            .where((t) => t != null && t.trim().isNotEmpty)
            .cast<String>()
            .toList();

    if (titles.isEmpty) {
      AppLogger.w("No valid title available for searching episodes.");
      return null;
    }

    BaseAnimeModel? bestCandidate;
    double bestSimilarity = 0.0;

    for (final title in titles) {
      try {
        final results = await search(title);

        if (results.isEmpty) continue;

        final matches = getBestMatches<BaseAnimeModel>(
          results: results,
          title: title,
          nameSelector: (r) => r.name,
          idSelector: (r) => r.id,
        );

        if (matches.isNotEmpty) {
          final topMatch = matches.first;
          if (topMatch.similarity >= 0.75) {
            AppLogger.d(
              'High-confidence match found: ${topMatch.result.name} (via "$title")',
            );
            return topMatch.result;
          }
          if (topMatch.similarity > bestSimilarity) {
            bestSimilarity = topMatch.similarity;
            bestCandidate = topMatch.result;
          }
        } else if (bestCandidate == null && results.isNotEmpty) {
          bestCandidate = results.first;
        }
      } catch (e) {
        AppLogger.e('Error searching for title: $title', e);
        // Continue to next title
      }
    }

    if (bestCandidate != null) {
      AppLogger.d(
        'Using closest match: ${bestCandidate.name} (similarity: ${bestSimilarity.toStringAsFixed(2)})',
      );
      return bestCandidate;
    }

    return null;
  }

  /// Searches for anime using the configured source (Mangayomi or Legacy).
  Future<List<BaseAnimeModel>> search(String query) async {
    final useExtensions = _ref.read(experimentalProvider).useExtensions;
    final nativeKey = _ref.read(selectedProviderKeyProvider);
    final isNative =
        nativeKey != null &&
        _ref.read(animeSourceRegistryProvider).has(nativeKey);

    if (useExtensions && !isNative) {
      final res = await _ref.read(sourceProvider.notifier).search(query);

      return res.list
          .where((r) => r.title != null && r.url != null)
          .map((r) => BaseAnimeModel(id: r.url, name: r.title, poster: r.cover))
          .toList();
    } else {
      final provider = _ref.read(selectedAnimeProvider);
      if (provider == null) return [];

      final registry = _ref.read(animeSourceRegistryProvider);
      final currentKey = _ref.read(selectedProviderKeyProvider);
      final keys = [
        if (currentKey != null) currentKey,
        ...registry.keys.where((key) => key != currentKey),
      ];
      for (final key in keys) {
        final candidate = registry.get(key);
        if (candidate == null) continue;
        try {
          final res = await candidate
              .getSearch(query, null, 1)
              .timeout(const Duration(seconds: 8));
          final results =
              res.results
                  .where((item) => item.id != null && item.name != null)
                  .map(
                    (item) => BaseAnimeModel(
                      id: item.id,
                      name: item.name,
                      poster: item.poster,
                    ),
                  )
                  .toList();
          if (results.isNotEmpty) {
            if (key != currentKey) {
              _ref.read(selectedProviderKeyProvider.notifier).select(key);
              AppLogger.w('Source $currentKey unavailable; using $key');
            }
            return results;
          }
        } catch (error) {
          AppLogger.d('Search failed on $key: $error');
        }
      }
      return [];
    }
  }

  /// Attempts to restore a previously selected source for the given [animeId].
  ///
  /// Checks if smart source is enabled and if a saved selection exists.
  /// resteres the source (legacy or extension) and returns the matched anime.
  /// Returns null if restoration fails or is disabled.
  Future<BaseAnimeModel?> restoreSource(
    String animeId, {
    bool showSnackbar = false,
  }) async {
    try {
      final repo = _ref.read(sourcePreferenceRepositoryProvider);
      final settings = _ref.read(contentSettingsProvider);

      // Smart Source Persistence Check
      AppLogger.d('Auto-Restore: Check enabled=${settings.smartSourceEnabled}');
      if (!settings.smartSourceEnabled) return null;

      final selection = repo.getSourcePreference(animeId);
      AppLogger.d('Auto-Restore: Selection found=${selection != null}');

      if (selection != null) {
        if (selection.sourceType == 'legacy') {
          final targetSourceKey = selection.sourceId ?? 'justanime';
          final registry = _ref.read(animeSourceRegistryProvider);
          final provider = registry.get(targetSourceKey) ?? registry.get('justanime');
          final matchedId = selection.matchedAnimeId;
          if (provider != null && matchedId != null && matchedId.isNotEmpty) {
            try {
              final episodes = await provider
                  .getEpisodes(matchedId)
                  .timeout(const Duration(seconds: 12));
              if (episodes.episodes?.isNotEmpty == true) {
                _ref
                    .read(selectedProviderKeyProvider.notifier)
                    .select(provider.providerName);
                AppLogger.d('Auto-Restore: Success with ${provider.providerName}');
                return BaseAnimeModel(
                  id: matchedId,
                  name: selection.matchedAnimeTitle,
                );
              }
              AppLogger.w('Auto-Restore: Saved match has no episodes');
            } catch (error) {
              AppLogger.w('Auto-Restore: Saved match is stale: $error');
            }
          } else {
            AppLogger.w('Auto-Restore: Legacy provider not found');
          }
          // Fallback to justanime if saved source is stale
          _ref.read(selectedProviderKeyProvider.notifier).select('justanime');
        } else if (['mangayomi', 'aniyomi'].contains(selection.sourceType)) {
          AppLogger.d(
            'Auto-Restore: Restoring extension source ${selection.sourceId}',
          );
          // Switch to extensions
          _ref.read(experimentalProvider.notifier).toggleExtensions(true);
          _ref.read(selectedProviderKeyProvider.notifier).clear();

          final sourceNotifier = _ref.read(sourceProvider.notifier);
          final source = _ref
              .read(sourceProvider)
              .installedAnimeExtensions
              .firstWhereOrNull((s) => s.id.toString() == selection.sourceId);

          if (source != null) {
            sourceNotifier.setActiveSource(source);
            AppLogger.d('Auto-Restore: Success');
            return BaseAnimeModel(
              id: selection.matchedAnimeId,
              name: selection.matchedAnimeTitle,
            );
          } else {
            AppLogger.w('Auto-Restore: Extension source not found');
          }
        }
      }
    } catch (e, st) {
      AppLogger.e('Failed to auto-restore source selection', e, st);
    }
    return null;
  }
}
