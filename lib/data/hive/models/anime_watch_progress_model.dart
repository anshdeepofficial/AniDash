import 'package:ani_dash/core/models/universal/universal_media.dart';

class AnimeWatchProgressEntry {
  final String animeId;
  final String animeTitle;
  final String? animeFormat;
  final String animeCover;
  final int totalEpisodes;
  final Map<int, EpisodeProgress> episodesProgress;
  final DateTime? lastUpdated;
  final int currentEpisode;
  final String status;
  final bool isAdult;

  AnimeWatchProgressEntry({
    required this.animeId,
    required this.animeTitle,
    this.animeFormat,
    required this.animeCover,
    required this.totalEpisodes,
    this.episodesProgress = const {},
    this.lastUpdated,
    this.currentEpisode = 1,
    this.status = 'watching',
    this.isAdult = false,
  });

  DateTime get latestWatchTime {
    var latest = lastUpdated ?? DateTime(0);
    for (final episode in episodesProgress.values) {
      final watchedAt = episode.watchedAt;
      if (watchedAt != null && watchedAt.isAfter(latest)) latest = watchedAt;
    }
    return latest;
  }

  bool get hasAnyWatchProgress {
    if (episodesProgress.isEmpty) return false;
    return episodesProgress.values.any(
      (ep) =>
          ep.isCompleted ||
          (ep.progressInSeconds != null && ep.progressInSeconds! > 0),
    );
  }

  bool get isCompletedOrFinished {
    if (status.toLowerCase() == 'completed') return true;

    if (totalEpisodes > 0) {
      if (currentEpisode > totalEpisodes) return true;

      final finalEp = episodesProgress[totalEpisodes];
      if (finalEp?.isCompleted == true) return true;
      final finalDur = finalEp?.durationInSeconds ?? 0;
      final finalProg = finalEp?.progressInSeconds ?? 0;
      if (finalDur > 0 && finalProg / finalDur >= 0.90) return true;

      if (currentEpisode == totalEpisodes) {
        final curEp = episodesProgress[currentEpisode];
        if (curEp?.isCompleted == true) return true;
        final curDur = curEp?.durationInSeconds ?? 0;
        final curProg = curEp?.progressInSeconds ?? 0;
        if (curDur > 0 && curProg / curDur >= 0.90) return true;
      }

      bool allCompleted = true;
      for (int i = 1; i <= totalEpisodes; i++) {
        final ep = episodesProgress[i];
        if (ep == null) {
          allCompleted = false;
          break;
        }
        final dur = ep.durationInSeconds ?? 0;
        final prog = ep.progressInSeconds ?? 0;
        final finished = ep.isCompleted || (dur > 0 && prog / dur >= 0.90);
        if (!finished) {
          allCompleted = false;
          break;
        }
      }
      if (allCompleted) return true;
    } else if (episodesProgress.isNotEmpty) {
      final highestEp = episodesProgress.keys.reduce((a, b) => a > b ? a : b);
      final ep = episodesProgress[highestEp];
      if (ep != null) {
        final dur = ep.durationInSeconds ?? 0;
        final prog = ep.progressInSeconds ?? 0;
        final isFinished = ep.isCompleted || (dur > 0 && prog / dur >= 0.90);
        if (isFinished && status.toLowerCase() == 'completed') {
          return true;
        }
      }
    }
    return false;
  }

  AnimeWatchProgressEntry copyWith({
    String? animeId,
    String? animeTitle,
    String? animeFormat,
    String? animeCover,
    int? totalEpisodes,
    Map<int, EpisodeProgress>? episodesProgress,
    DateTime? lastUpdated,
    int? currentEpisode,
    String? status,
    bool? isAdult,
  }) {
    return AnimeWatchProgressEntry(
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      animeFormat: animeFormat ?? this.animeFormat,
      animeCover: animeCover ?? this.animeCover,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      episodesProgress: episodesProgress ?? this.episodesProgress,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      status: status ?? this.status,
      isAdult: isAdult ?? this.isAdult,
    );
  }

  UniversalMedia toUniversalMedia() {
    return UniversalMedia(
      id: animeId,
      title: UniversalTitle(
        native: animeTitle,
        romaji: animeTitle,
        english: animeTitle,
      ),
      format: animeFormat,
      coverImage: UniversalCoverImage(large: animeCover, medium: animeCover),
      episodes: totalEpisodes,
      status: status,
      isAdult: isAdult,
      startDate: UniversalFuzzyDate(
        year: DateTime.now().year,
        month: DateTime.now().month,
        day: DateTime.now().day,
      ),
      endDate: UniversalFuzzyDate(
        year: DateTime.now().year,
        month: DateTime.now().month,
        day: DateTime.now().day,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'animeId': animeId,
      'animeTitle': animeTitle,
      'animeFormat': animeFormat,
      'animeCover': animeCover,
      'totalEpisodes': totalEpisodes,
      'episodesProgress': episodesProgress.map(
        (k, v) => MapEntry(k.toString(), v.toMap()),
      ),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'currentEpisode': currentEpisode,
      'status': status,
      'isAdult': isAdult,
    };
  }

  factory AnimeWatchProgressEntry.fromMap(Map<String, dynamic> map) {
    return AnimeWatchProgressEntry(
      animeId: map['animeId'] ?? '',
      animeTitle: map['animeTitle'] ?? '',
      animeFormat: map['animeFormat'] ?? '',
      animeCover: map['animeCover'] ?? '',
      totalEpisodes: map['totalEpisodes']?.toInt() ?? 0,
      episodesProgress:
          (map['episodesProgress'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              int.parse(k),
              EpisodeProgress.fromMap(Map<String, dynamic>.from(v)),
            ),
          ) ??
          {},
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'])
          : null,
      currentEpisode: map['currentEpisode']?.toInt() ?? 1,
      status: map['status'] ?? 'watching',
      isAdult: map['isAdult'] ?? false,
    );
  }
}

class EpisodeProgress {
  final int episodeNumber;
  final String episodeTitle;
  final String? episodeThumbnail;
  final int? progressInSeconds;
  final int? durationInSeconds;
  final bool isCompleted;
  final DateTime? watchedAt;

  EpisodeProgress({
    required this.episodeNumber,
    required this.episodeTitle,
    required this.episodeThumbnail,
    this.progressInSeconds,
    this.durationInSeconds,
    this.isCompleted = false,
    this.watchedAt,
  });

  EpisodeProgress copyWith({
    int? episodeNumber,
    String? episodeTitle,
    String? episodeThumbnail,
    int? progressInSeconds,
    int? durationInSeconds,
    bool? isCompleted,
    DateTime? watchedAt,
  }) {
    return EpisodeProgress(
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      episodeThumbnail: episodeThumbnail ?? this.episodeThumbnail,
      progressInSeconds: progressInSeconds ?? this.progressInSeconds,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      watchedAt: watchedAt ?? this.watchedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'episodeThumbnail': episodeThumbnail,
      'progressInSeconds': progressInSeconds,
      'durationInSeconds': durationInSeconds,
      'isCompleted': isCompleted,
      'watchedAt': watchedAt?.toIso8601String(),
    };
  }

  factory EpisodeProgress.fromMap(Map<String, dynamic> map) {
    return EpisodeProgress(
      episodeNumber: map['episodeNumber']?.toInt() ?? 0,
      episodeTitle: map['episodeTitle'] ?? '',
      episodeThumbnail: map['episodeThumbnail'],
      progressInSeconds: map['progressInSeconds']?.toInt(),
      durationInSeconds: map['durationInSeconds']?.toInt(),
      isCompleted: map['isCompleted'] ?? false,
      watchedAt: map['watchedAt'] != null
          ? DateTime.tryParse(map['watchedAt'])
          : null,
    );
  }
}
