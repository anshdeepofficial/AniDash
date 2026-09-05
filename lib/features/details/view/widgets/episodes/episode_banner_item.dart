import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:ani_dash/features/downloads/model/download_item.dart';
import 'package:ani_dash/features/downloads/model/download_status.dart';

class EpisodeBannerItem extends StatelessWidget {
  final EpisodeDataModel episode;
  final int index;
  final bool isWatched;
  final double watchProgress;
  final DownloadItem? download;
  final EpisodeProgress? episodeProgress;
  final String fallbackCover;
  final VoidCallback onTap;
  final VoidCallback onMoreOptions;
  final VoidCallback? onDownload;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const EpisodeBannerItem({
    super.key,
    required this.episode,
    required this.index,
    required this.isWatched,
    required this.watchProgress,
    this.download,
    this.episodeProgress,
    required this.fallbackCover,
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
    final episodeNumber = episode.number ?? index + 1;
    final thumbnail = episodeProgress?.episodeThumbnail;
    final fallbackUrl = episode.thumbnail ?? fallbackCover;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isSelected ? 2.0 : 1.0,
              ),
              color: theme.colorScheme.surfaceContainer,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail image
                      if (thumbnail != null)
                        thumbnail.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: thumbnail,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    _buildFallbackImage(theme),
                              )
                            : Image.memory(
                                base64Decode(thumbnail),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _buildFallbackImage(theme),
                              )
                      else if (fallbackUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: fallbackUrl,
                          fit: BoxFit.cover,
                          httpHeaders: {
                            "Referer": fallbackUrl.split('#').last,
                            "User-Agent":
                                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
                          },
                          errorWidget: (_, _, _) => _buildFallbackImage(theme),
                        )
                      else
                        _buildFallbackImage(theme),

                      // Gradient overlay for contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),

                      // Center Play Button
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),

                      // Top-left badges: Selection / EP badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Row(
                          children: [
                            if (isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isWatched
                                    ? Colors.black.withValues(alpha: 0.7)
                                    : theme.colorScheme.primary.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isWatched) ...[
                                    const Icon(
                                      Icons.check_rounded,
                                      color: Colors.greenAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'EP $episodeNumber',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Top-right controls / badges
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            if (episode.isFiller == true)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade800,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'FILLER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (!isSelectionMode) ...[
                              if (onDownload != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    tooltip: 'Download',
                                    onPressed: onDownload,
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: 'More options',
                                  onPressed: onMoreOptions,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Bottom title & download status overlay
                      Positioned(
                        bottom: 8,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              episode.title ?? 'Episode $episodeNumber',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            if (download != null) ...[
                              const SizedBox(height: 4),
                              _buildDownloadBadge(theme, download!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Watch Progress Indicator
                if (watchProgress > 0)
                  LinearProgressIndicator(
                    value: watchProgress,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                    color: isWatched
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.primary,
                    minHeight: 3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.movie_filter_rounded,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildDownloadBadge(ThemeData theme, DownloadItem download) {
    String text;
    Color color;
    IconData icon;

    switch (download.state) {
      case DownloadStatus.downloading:
        final progress = download.progress;
        text = 'Downloading $progress%';
        color = Colors.blueAccent;
        icon = Icons.downloading;
        break;
      case DownloadStatus.downloaded:
        text = 'Downloaded';
        color = Colors.greenAccent;
        icon = Icons.check_circle_outline;
        break;
      case DownloadStatus.failed:
        text = 'Failed';
        color = Colors.redAccent;
        icon = Icons.error_outline;
        break;
      case DownloadStatus.paused:
        text = 'Paused';
        color = Colors.orangeAccent;
        icon = Icons.pause_circle_outline;
        break;
      default:
        text = 'Queued';
        color = Colors.white70;
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
