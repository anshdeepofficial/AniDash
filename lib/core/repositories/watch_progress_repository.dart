import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:isar_community/isar.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/utils/app_utils.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:ani_dash/data/isar/isar_anime_watch_progress.dart';
import 'package:ani_dash/main.dart';
import 'package:ani_dash/core/repositories/interfaces/watch_progress_repository_interface.dart';
import 'package:ani_dash/shared/providers/incognito_provider.dart';

final watchProgressRepositoryProvider = Provider<WatchProgressRepositoryInterface>((
  ref,
) {
  return WatchProgressRepository();
});

final watchProgressStreamProvider =
    StreamProvider.autoDispose<List<AnimeWatchProgressEntry>>((ref) {
      return ref.watch(watchProgressRepositoryProvider).watchAllProgress();
    });

final animeWatchProgressProvider = StreamProvider.autoDispose
    .family<AnimeWatchProgressEntry?, String>((ref, animeId) {
      return ref.watch(watchProgressRepositoryProvider).watchProgress(animeId);
    });

class WatchProgressRepository implements WatchProgressRepositoryInterface {
  WatchProgressRepository();

  // --- Migration ---

  @override
  Future<void> migrateFromHive() async {
    try {
      final isarCount = isar.isarAnimeWatchProgress.countSync();
      if (sharedPrefs.getBool('migrated_watch_progress_isar') == true && isarCount > 0) return;

      AppLogger.i('Starting migration of watch progress to Isar...');

      final box = Hive.isBoxOpen('anime_watch_progress')
          ? Hive.box<AnimeWatchProgressEntry>('anime_watch_progress')
          : await Hive.openBox<AnimeWatchProgressEntry>('anime_watch_progress');

      if (box.isEmpty) {
        await sharedPrefs.setBool('migrated_watch_progress_isar', true);
        return;
      }

      final entries = box.values.toList();
      final isarEntries = entries
          .map(
            (e) => IsarAnimeWatchProgress(
              id: fastHash(e.animeId),
              animeId: e.animeId,
              animeTitle: e.animeTitle,
              animeFormat: e.animeFormat,
              animeCover: e.animeCover,
              totalEpisodes: e.totalEpisodes,
              lastUpdated: e.lastUpdated,
              currentEpisode: e.currentEpisode,
              status: e.status,
              episodesProgress: e.episodesProgress.values
                  .map(_toIsarProgress)
                  .toList(),
            ),
          )
          .toList();

      await isar.writeTxn(() async {
        await isar.isarAnimeWatchProgress.putAll(isarEntries);
      });

      await sharedPrefs.setBool('migrated_watch_progress_isar', true);
      AppLogger.success(
        'Successfully migrated ${entries.length} items to Isar',
      );
    } catch (e, st) {
      AppLogger.e('Failed to migrate watch progress', e, st);
    }
  }

  bool isAdultAnimeId(String animeId) {
    final adultIds = sharedPrefs.getStringList('adult_anime_ids') ?? [];
    return adultIds.contains(animeId);
  }

  Future<void> markAdultAnimeId(String animeId) async {
    final adultIds = (sharedPrefs.getStringList('adult_anime_ids') ?? []).toSet();
    if (!adultIds.contains(animeId)) {
      adultIds.add(animeId);
      await sharedPrefs.setStringList('adult_anime_ids', adultIds.toList());
    }
  }

  // --- Core CRUD ---

  @override
  Future<void> saveProgress(AnimeWatchProgressEntry entry) async {
    if (IncognitoService.isIncognito(entry.animeId)) {
      AppLogger.d(
        'Incognito active for anime: ${entry.animeTitle} (${entry.animeId}); skipping save.',
      );
      return;
    }
    if (entry.isAdult) {
      await markAdultAnimeId(entry.animeId);
    }
    try {
      final isarEntry = IsarAnimeWatchProgress(
        id: fastHash(entry.animeId),
        animeId: entry.animeId,
        animeTitle: entry.animeTitle,
        animeFormat: entry.animeFormat,
        animeCover: entry.animeCover,
        totalEpisodes: entry.totalEpisodes,
        lastUpdated: entry.lastUpdated,
        currentEpisode: entry.currentEpisode,
        status: entry.status,
        episodesProgress: entry.episodesProgress.values
            .map(_toIsarProgress)
            .toList(),
      );

      await isar.writeTxn(() async {
        await isar.isarAnimeWatchProgress.put(isarEntry);
      });

      // Dual-write to Hive to prevent data loss
      try {
        final box = Hive.isBoxOpen('anime_watch_progress')
            ? Hive.box<AnimeWatchProgressEntry>('anime_watch_progress')
            : await Hive.openBox<AnimeWatchProgressEntry>('anime_watch_progress');
        await box.put(entry.animeId, entry);
      } catch (_) {}

      AppLogger.d(
        'Saved progress for anime: ${entry.animeTitle} (${entry.animeId})',
      );
    } catch (e, st) {
      AppLogger.e('Failed to save anime progress', e, st);
      showAppSnackBar(
        'Save Failed',
        'Failed to automatically save watch progress.',
        type: ContentType.failure,
      );
    }
  }

  @override
  AnimeWatchProgressEntry? getProgress(String animeId) {
    final isarEntry = isar.isarAnimeWatchProgress.getSync(fastHash(animeId));
    final isAdult = isAdultAnimeId(animeId);
    if (isarEntry != null) {
      return AnimeWatchProgressEntry(
        animeId: isarEntry.animeId,
        animeTitle: isarEntry.animeTitle,
        animeFormat: isarEntry.animeFormat,
        animeCover: isarEntry.animeCover,
        totalEpisodes: isarEntry.totalEpisodes,
        lastUpdated: isarEntry.lastUpdated,
        currentEpisode: isarEntry.currentEpisode,
        status: isarEntry.status,
        isAdult: isAdult,
        episodesProgress: {
          for (var ep in isarEntry.episodesProgress)
            ep.episodeNumber: _fromIsarProgress(ep),
        },
      );
    }

    try {
      if (Hive.isBoxOpen('anime_watch_progress')) {
        final box = Hive.box<AnimeWatchProgressEntry>('anime_watch_progress');
        final entry = box.get(animeId);
        if (entry != null && isAdult && !entry.isAdult) {
          return entry.copyWith(isAdult: true);
        }
        return entry;
      }
    } catch (_) {}
    return null;
  }

  @override
  List<AnimeWatchProgressEntry> getAllProgress() {
    final isarEntries = isar.isarAnimeWatchProgress.where().findAllSync();
    if (isarEntries.isEmpty) {
      try {
        final box = Hive.isBoxOpen('anime_watch_progress')
            ? Hive.box<AnimeWatchProgressEntry>('anime_watch_progress')
            : null;
        if (box != null && box.isNotEmpty) {
          final hiveList = box.values.toList();
          migrateFromHive();
          return hiveList;
        }
      } catch (_) {}
    }

    return isarEntries.map((isarEntry) {
      final isAdult = isAdultAnimeId(isarEntry.animeId);
      return AnimeWatchProgressEntry(
        animeId: isarEntry.animeId,
        animeTitle: isarEntry.animeTitle,
        animeFormat: isarEntry.animeFormat,
        animeCover: isarEntry.animeCover,
        totalEpisodes: isarEntry.totalEpisodes,
        lastUpdated: isarEntry.lastUpdated,
        currentEpisode: isarEntry.currentEpisode,
        status: isarEntry.status,
        isAdult: isAdult,
        episodesProgress: {
          for (var ep in isarEntry.episodesProgress)
            ep.episodeNumber: _fromIsarProgress(ep),
        },
      );
    }).toList();
  }

  // --- Update Operations ---

  @override
  Future<void> updateEpisodeProgress(
    String animeId,
    EpisodeProgress episodeProgress,
  ) async {
    var entry = getProgress(animeId);
    entry ??= AnimeWatchProgressEntry(
      animeId: animeId,
      animeTitle: '',
      animeFormat: '',
      animeCover: '',
      totalEpisodes: 0,
      lastUpdated: DateTime.now(),
      currentEpisode: episodeProgress.episodeNumber,
      episodesProgress: {},
    );

    final updatedEpisodes = Map<int, EpisodeProgress>.from(
      entry.episodesProgress,
    );

    // Preserve existing thumbnail if new one is null
    final existingThumb =
        updatedEpisodes[episodeProgress.episodeNumber]?.episodeThumbnail;
    updatedEpisodes[episodeProgress.episodeNumber] = episodeProgress.copyWith(
      episodeThumbnail: episodeProgress.episodeThumbnail ?? existingThumb,
    );

    final updatedEntry = entry.copyWith(
      episodesProgress: updatedEpisodes,
      lastUpdated: DateTime.now(),
      currentEpisode: episodeProgress.episodeNumber,
    );

    await saveProgress(updatedEntry);
  }

  @override
  Future<void> markPreviousEpisodesWatched({
    required String animeId,
    required String animeTitle,
    required String animeCover,
    required String animeFormat,
    required int upToEpisodeNumber,
  }) async {
    var entry = getProgress(animeId);
    entry ??= AnimeWatchProgressEntry(
      animeId: animeId,
      animeTitle: animeTitle,
      animeFormat: animeFormat,
      animeCover: animeCover,
      totalEpisodes: 0,
      lastUpdated: DateTime.now(),
      currentEpisode: upToEpisodeNumber,
      episodesProgress: {},
    );

    final updatedEpisodes = Map<int, EpisodeProgress>.from(
      entry.episodesProgress,
    );

    for (int i = 1; i <= upToEpisodeNumber; i++) {
      final existing = updatedEpisodes[i];
      updatedEpisodes[i] = EpisodeProgress(
        episodeNumber: i,
        episodeTitle: existing?.episodeTitle ?? 'Episode $i',
        episodeThumbnail: existing?.episodeThumbnail,
        isCompleted: true,
        watchedAt: DateTime.now(),
      );
    }

    final updatedEntry = entry.copyWith(
      episodesProgress: updatedEpisodes,
      lastUpdated: DateTime.now(),
      currentEpisode: upToEpisodeNumber,
      animeTitle: animeTitle.isNotEmpty ? animeTitle : entry.animeTitle,
      animeCover: animeCover.isNotEmpty ? animeCover : entry.animeCover,
    );

    await saveProgress(updatedEntry);
  }

  // --- Deletion ---

  @override
  Future<void> deleteProgress(String animeId) async {
    await isar.writeTxn(() async {
      await isar.isarAnimeWatchProgress.delete(fastHash(animeId));
    });
    AppLogger.d('Deleted progress for anime: $animeId');
  }

  @override
  Future<void> deleteEpisodeProgress(String animeId, int episodeNumber) async {
    final entry = getProgress(animeId);
    if (entry == null) return;

    final updatedEpisodes = Map<int, EpisodeProgress>.from(
      entry.episodesProgress,
    );
    updatedEpisodes.remove(episodeNumber);

    if (updatedEpisodes.isEmpty) {
      await deleteProgress(animeId);
      return;
    }

    // Safely find highest episode number
    final newCurrentEpisode = updatedEpisodes.keys.reduce(
      (a, b) => a > b ? a : b,
    );
    final updatedEntry = entry.copyWith(
      episodesProgress: updatedEpisodes,
      lastUpdated: DateTime.now(),
      currentEpisode: newCurrentEpisode,
    );

    await saveProgress(updatedEntry);
    AppLogger.d('Deleted episode $episodeNumber progress for anime: $animeId');
  }

  @override
  Future<void> deleteMultipleProgress(List<String> animeIds) async {
    await isar.writeTxn(() async {
      await isar.isarAnimeWatchProgress.deleteAll(
        animeIds.map(fastHash).toList(),
      );
    });
    AppLogger.d('Deleted progress for ${animeIds.length} animes');
  }

  @override
  EpisodeProgress? getEpisodeProgress(String animeId, int episodeNumber) {
    return getProgress(animeId)?.episodesProgress[episodeNumber];
  }

  // --- Streams ---

  @override
  Stream<List<AnimeWatchProgressEntry>> watchAllProgress() async* {
    yield getAllProgress();
    await for (final _ in isar.isarAnimeWatchProgress.where().watch()) {
      yield getAllProgress();
    }
  }

  @override
  Stream<AnimeWatchProgressEntry?> watchProgress(String animeId) async* {
    yield getProgress(animeId);
    await for (final _
        in isar.isarAnimeWatchProgress
            .filter()
            .idEqualTo(fastHash(animeId))
            .watch()) {
      yield getProgress(animeId);
    }
  }

  // --- Private Helpers ---

  IsarEpisodeProgress _toIsarProgress(EpisodeProgress ep) {
    return IsarEpisodeProgress(
      episodeNumber: ep.episodeNumber,
      episodeTitle: ep.episodeTitle,
      episodeThumbnail: ep.episodeThumbnail,
      progressInSeconds: ep.progressInSeconds,
      durationInSeconds: ep.durationInSeconds,
      isCompleted: ep.isCompleted,
      watchedAt: ep.watchedAt,
    );
  }

  EpisodeProgress _fromIsarProgress(IsarEpisodeProgress ep) {
    return EpisodeProgress(
      episodeNumber: ep.episodeNumber,
      episodeTitle: ep.episodeTitle,
      episodeThumbnail: ep.episodeThumbnail,
      progressInSeconds: ep.progressInSeconds,
      durationInSeconds: ep.durationInSeconds,
      isCompleted: ep.isCompleted,
      watchedAt: ep.watchedAt,
    );
  }
}
