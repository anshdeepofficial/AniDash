import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:ani_dash/helpers/anime_match_search.dart';
import 'package:ani_dash/core/repositories/watch_progress_repository.dart';

class ContinueSection extends ConsumerWidget {
  final List<AnimeWatchProgressEntry> allProgress;
  final bool isAdult;

  const ContinueSection({
    super.key,
    required this.allProgress,
    this.isAdult = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopedEntries =
        isAdult
            ? allProgress.where((e) => e.isAdult).toList()
            : List<AnimeWatchProgressEntry>.from(allProgress);
    final validEntries =
        scopedEntries.where((entry) {
          if (entry.status.toLowerCase() == 'completed') return false;
          if (entry.totalEpisodes > 0) {
            if (entry.currentEpisode > entry.totalEpisodes) return false;
            final finalEpisode = entry.episodesProgress[entry.totalEpisodes];
            if (finalEpisode?.isCompleted == true) return false;
            final duration = finalEpisode?.durationInSeconds ?? 0;
            final progress = finalEpisode?.progressInSeconds ?? 0;
            if (duration > 0 && progress / duration >= 0.85) return false;

            if (entry.currentEpisode == entry.totalEpisodes) {
              final currEp = entry.episodesProgress[entry.currentEpisode];
              if (currEp?.isCompleted == true) return false;
              final curDur = currEp?.durationInSeconds ?? 0;
              final curProg = currEp?.progressInSeconds ?? 0;
              if (curDur > 0 && curProg / curDur >= 0.85) return false;
            }
          }
          return true;
        }).toList();

    if (validEntries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemWidth = (screenWidth * 0.6).clamp(180.0, 280.0);
    final imageHeight = itemWidth * (9 / 16);
    final listHeight = imageHeight + 60.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text("Continue", style: theme.textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => context.push('/settings/watch-history'),
              icon: const Icon(Iconsax.arrow_right_3, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: validEntries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final entry = validEntries[index];
              final currentEp = entry.episodesProgress[entry.currentEpisode];

              // If current episode is completed (or watched > 85%), show next episode
              final isCurrentCompleted =
                  currentEp?.isCompleted == true ||
                  ((currentEp?.durationInSeconds ?? 0) > 0 &&
                      ((currentEp?.progressInSeconds ?? 0) /
                              currentEp!.durationInSeconds!) >=
                          0.85);

              final baseEp =
                  entry.currentEpisode > 0 ? entry.currentEpisode : 1;
              final nextEpisodeNum =
                  isCurrentCompleted &&
                          (entry.totalEpisodes == 0 ||
                              baseEp < entry.totalEpisodes)
                      ? baseEp + 1
                      : baseEp;

              final displayEp =
                  entry.episodesProgress[nextEpisodeNum] ?? currentEp;

              double progressValue = 0.0;
              if (!isCurrentCompleted && currentEp != null) {
                final p = currentEp.progressInSeconds?.toDouble() ?? 0.0;
                final d = currentEp.durationInSeconds?.toDouble() ?? 0.0;
                if (d > 0) progressValue = (p / d).clamp(0.0, 1.0);
              }

              final thumb =
                  displayEp?.episodeThumbnail ?? currentEp?.episodeThumbnail;
              Widget imageWidget;

              if (thumb != null && thumb.startsWith('http')) {
                imageWidget = CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _buildFallback(colorScheme),
                );
              } else if (thumb != null) {
                try {
                  imageWidget = Image.memory(
                    base64Decode(thumb),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildFallback(colorScheme),
                  );
                } catch (_) {
                  imageWidget = _buildFallback(colorScheme);
                }
              } else if (entry.animeCover.isNotEmpty) {
                imageWidget = Image.network(
                  entry.animeCover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildFallback(colorScheme),
                );
              } else {
                imageWidget = _buildFallback(colorScheme);
              }

              bool isLoading = false;
              return StatefulBuilder(
                builder: (context, setState) {
                  return RepaintBoundary(
                    child: SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onLongPress: () {
                          _showContinueWatchingMenu(
                            context,
                            ref,
                            entry,
                            currentEp,
                            colorScheme,
                          );
                        },
                        onTap: () async {
                          if (isLoading) return;
                          setState(() => isLoading = true);
                          await providerAnimeMatchSearch(
                            context: context,
                            ref: ref,
                            animeMedia: UniversalMedia(
                              id: entry.animeId,
                              title: UniversalTitle(
                                romaji: entry.animeTitle,
                                english: entry.animeTitle,
                                native: entry.animeTitle,
                              ),
                              coverImage: UniversalCoverImage(
                                large: entry.animeCover,
                                medium: entry.animeCover,
                              ),
                              isAdult: isAdult || entry.isAdult,
                            ),
                            startAt: nextEpisodeNum,
                            withAnimeMatch: true,
                            directAutoMatch: true,
                            fromHentaiHub: isAdult || entry.isAdult,
                          );
                          if (context.mounted) {
                            setState(() => isLoading = false);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: imageWidget),
                                    Positioned.fill(
                                      child: Center(
                                        child:
                                            isLoading
                                                ? const CircularProgressIndicator()
                                                : Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme
                                                        .primaryContainer
                                                        .withValues(alpha: 0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Iconsax.play5,
                                                    color:
                                                        colorScheme
                                                            .onPrimaryContainer,
                                                    size: 20,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'EP $nextEpisodeNum',
                                          style: TextStyle(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: LinearProgressIndicator(
                                        value: progressValue,
                                        minHeight: 3,
                                        backgroundColor: Colors.transparent,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.animeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCurrentCompleted
                                  ? (entry
                                              .episodesProgress[nextEpisodeNum]
                                              ?.episodeTitle
                                              .isNotEmpty ==
                                          true
                                      ? entry
                                          .episodesProgress[nextEpisodeNum]!
                                          .episodeTitle
                                      : 'Episode $nextEpisodeNum')
                                  : (currentEp?.episodeTitle.isNotEmpty == true
                                      ? currentEp!.episodeTitle
                                      : 'Episode ${entry.currentEpisode}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showContinueWatchingMenu(
    BuildContext context,
    WidgetRef ref,
    AnimeWatchProgressEntry entry,
    EpisodeProgress? currentEp,
    ColorScheme colorScheme,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  entry.animeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentEp != null)
                  Text(
                    currentEp.episodeTitle.isNotEmpty
                        ? currentEp.episodeTitle
                        : 'EP ${currentEp.episodeNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Divider(height: 24),
                ListTile(
                  leading: Icon(
                    Iconsax.close_circle,
                    color: theme.colorScheme.error,
                  ),
                  title: const Text('Remove from Continue Watching'),
                  subtitle: const Text('Clears your watch progress'),
                  onTap: () {
                    ref
                        .read(watchProgressRepositoryProvider)
                        .deleteProgress(entry.animeId);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Iconsax.info_circle,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('View Anime Details'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/details', extra: entry.toUniversalMedia());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallback(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Iconsax.video_play,
          size: 28,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
