import 'package:flutter/material.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:ani_dash/features/downloads/model/download_item.dart';
import 'package:ani_dash/features/downloads/model/download_status.dart';

class EpisodeCompactItem extends StatelessWidget {
  final EpisodeDataModel episode;
  final int index;
  final bool isWatched;
  final double watchProgress;
  final DownloadItem? download;
  final EpisodeProgress? episodeProgress;
  final Function() onTap;
  final Function() onMoreOptions;
  final VoidCallback? onDownload;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const EpisodeCompactItem({
    super.key,
    required this.episode,
    required this.index,
    required this.isWatched,
    required this.watchProgress,
    this.download,
    this.episodeProgress,
    required this.onTap,
    required this.onMoreOptions,
    this.onDownload,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          tileColor:
              episode.isMixed == true
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : (episode.isFiller == true
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : null),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Icon(
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color:
                        isSelected
                            ? theme.colorScheme.primary
                            : theme.hintColor,
                  ),
                ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    '${episode.number ?? index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color:
                          isWatched
                              ? theme.hintColor
                              : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            episode.title ?? 'Episode ${episode.number ?? index + 1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isWatched ? theme.hintColor : null),
          ),
          subtitle:
              (download != null || episode.isFiller == true || episode.isMixed == true)
                  ? Row(
                    children: [
                      if (episode.isMixed == true)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'MIXED',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        )
                      else if (episode.isFiller == true)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.10),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FILLER',
                              style: TextStyle(
                                color: theme.colorScheme.primary.withValues(alpha: 0.85),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      if (download != null)
                        _buildDownloadStatus(theme, download!),
                    ],
                  )
                  : null,
          trailing:
              isSelectionMode
                  ? null
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onDownload != null)
                        IconButton(
                          icon: const Icon(Icons.download_rounded, size: 20),
                          tooltip: 'Download',
                          onPressed: onDownload,
                        ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        tooltip: 'More options',
                        onPressed: onMoreOptions,
                      ),
                    ],
                  ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
        if (watchProgress > 0 && !isWatched)
          LinearProgressIndicator(
            value: watchProgress,
            backgroundColor: Colors.transparent,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            minHeight: 1,
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildDownloadStatus(ThemeData theme, DownloadItem download) {
    if (download.state == DownloadStatus.downloading) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: download.progressPercentage,
        ),
      );
    } else if (download.state == DownloadStatus.downloaded) {
      return Icon(
        Icons.download_done_rounded,
        size: 14,
        color: theme.colorScheme.primary,
      );
    } else {
      return Icon(
        Icons.downloading,
        size: 14,
        color: theme.colorScheme.tertiary,
      );
    }
  }
}
