import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/helpers/ui.dart';
import 'package:ani_dash/core/repositories/watch_progress_repository.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:ani_dash/features/downloads/model/download_item.dart';
import 'package:ani_dash/features/downloads/model/download_status.dart';
import 'package:ani_dash/features/downloads/view_model/downloads_notifier.dart';
import 'package:ani_dash/features/watch/view/widgets/player/shonenx_video_player.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';

class LocalPlayerScreen extends ConsumerStatefulWidget {
  final DownloadItem item;

  const LocalPlayerScreen({super.key, required this.item});

  @override
  ConsumerState<LocalPlayerScreen> createState() => _LocalPlayerScreenState();
}

class _LocalPlayerScreenState extends ConsumerState<LocalPlayerScreen> {
  late Duration _startAt;
  int _lastSavedSecond = -1;

  @override
  void initState() {
    super.initState();
    final entry = _matchingEntry();
    final saved = entry?.episodesProgress[widget.item.episodeNumber];
    _startAt = Duration(seconds: saved?.progressInSeconds ?? 0);
    UIHelper.enableImmersiveMode();
    UIHelper.forceLandscape();
  }

  AnimeWatchProgressEntry? _matchingEntry() {
    final title = widget.item.animeTitle.trim().toLowerCase();
    final matches =
        ref
            .read(watchProgressRepositoryProvider)
            .getAllProgress()
            .where((entry) => entry.animeTitle.trim().toLowerCase() == title)
            .toList();
    if (matches.isEmpty) return null;
    return matches.firstWhere(
      (entry) => !entry.animeId.startsWith('offline:'),
      orElse: () => matches.first,
    );
  }

  Future<void> _saveProgress(
    Duration position,
    Duration duration, {
    bool force = false,
  }) async {
    if (duration.inSeconds <= 0 || position.inSeconds <= 0) return;
    if (!force &&
        _lastSavedSecond >= 0 &&
        (position.inSeconds - _lastSavedSecond).abs() < 5) {
      return;
    }
    _lastSavedSecond = position.inSeconds;

    final repository = ref.read(watchProgressRepositoryProvider);
    final existing = _matchingEntry();
    final downloadedEpisodeCount = ref
        .read(downloadsProvider)
        .downloads
        .where(
          (item) =>
              item.animeTitle.trim().toLowerCase() ==
              widget.item.animeTitle.trim().toLowerCase(),
        )
        .fold<int>(
          widget.item.episodeNumber,
          (maximum, item) =>
              item.episodeNumber > maximum ? item.episodeNumber : maximum,
        );
    final mediaId =
        existing?.animeId ??
        'offline:${widget.item.animeTitle.trim().toLowerCase()}';
    final episode = EpisodeProgress(
      episodeNumber: widget.item.episodeNumber,
      episodeTitle: widget.item.episodeTitle,
      episodeThumbnail: widget.item.thumbnail,
      progressInSeconds: position.inSeconds,
      durationInSeconds: duration.inSeconds,
      isCompleted: position.inSeconds / duration.inSeconds >= 0.90,
      watchedAt: DateTime.now(),
    );
    final episodes = Map<int, EpisodeProgress>.from(
      existing?.episodesProgress ?? const {},
    )..[widget.item.episodeNumber] = episode;
    await repository.saveProgress(
      (existing ??
              AnimeWatchProgressEntry(
                animeId: mediaId,
                animeTitle: widget.item.animeTitle,
                animeCover: widget.item.thumbnail,
                totalEpisodes: downloadedEpisodeCount,
                isAdult: widget.item.isAdult,
              ))
          .copyWith(
            episodesProgress: episodes,
            currentEpisode: widget.item.episodeNumber,
            totalEpisodes: existing?.totalEpisodes ?? downloadedEpisodeCount,
            lastUpdated: DateTime.now(),
          ),
    );
  }

  Future<void> _showDownloadedEpisodes() async {
    final title = widget.item.animeTitle.trim().toLowerCase();
    final episodes =
        ref
            .read(downloadsProvider)
            .downloads
            .where(
              (item) =>
                  item.state == DownloadStatus.downloaded &&
                  item.animeTitle.trim().toLowerCase() == title,
            )
            .toList()
          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder:
          (sheetContext) => SafeArea(
            child: ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (_, index) {
                final episode = episodes[index];
                return ListTile(
                  selected: episode.filePath == widget.item.filePath,
                  leading: CircleAvatar(
                    child: Text('${episode.episodeNumber}'),
                  ),
                  title: Text(episode.episodeTitle),
                  subtitle: Text(episode.audioLanguage),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (episode.filePath == widget.item.filePath) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => LocalPlayerScreen(item: episode),
                      ),
                    );
                  },
                );
              },
            ),
          ),
    );
  }

  @override
  void dispose() {
    final state = ref.read(playerStateProvider);
    unawaited(_saveProgress(state.position, state.duration));
    UIHelper.forcePortrait();
    UIHelper.exitImmersiveMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerStateProvider, (previous, next) {
      unawaited(_saveProgress(next.position, next.duration));
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final playerState = ref.read(playerStateProvider);
        await _saveProgress(
          playerState.position,
          playerState.duration,
          force: true,
        );
        await UIHelper.forcePortrait();
        await UIHelper.exitImmersiveMode();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AniDashVideoPlayer(
          onEpisodesPressed: _showDownloadedEpisodes,
          localFilePath: widget.item.filePath,
          localTitle: '${widget.item.animeTitle} - ${widget.item.episodeTitle}',
          localStartAt: _startAt,
        ),
      ),
    );
  }
}
