import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';
import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/features/watch/view_model/next_episode_prompt_provider.dart';

class NextEpisodePromptOverlay extends ConsumerWidget {
  const NextEpisodePromptOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(nextEpisodePromptProvider);
    if (!isVisible) return const SizedBox.shrink();

    final currentEp = ref.watch(
      episodeDataProvider.select((s) => s.selectedEpisode),
    );
    if (currentEp == null) return const SizedBox.shrink();

    final nextEpNum = currentEp + 1;
    final epList = ref.watch(episodeListProvider);
    final nextEp = epList.episodes.firstWhereOrNull((e) => e.number == nextEpNum);
    if (nextEp == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 80,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 70,
                    height: 50,
                    color: colorScheme.surfaceContainerHighest,
                    child: (nextEp.thumbnail != null && nextEp.thumbnail!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: nextEp.thumbnail!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Icon(
                              Icons.play_circle_outline,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.play_circle_outline,
                            color: colorScheme.primary,
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Info & Action
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Up Next: Ep $nextEpNum',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nextEp.title != null && nextEp.title!.isNotEmpty)
                        Text(
                          nextEp.title!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 28,
                        child: FilledButton.icon(
                          onPressed: () {
                            ref.read(nextEpisodePromptProvider.notifier).dismiss();
                            ref
                                .read(episodeDataProvider.notifier)
                                .changeEpisode(null, by: 1);
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text(
                            'Play Now',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dismiss Button
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    ref.read(nextEpisodePromptProvider.notifier).dismiss();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
