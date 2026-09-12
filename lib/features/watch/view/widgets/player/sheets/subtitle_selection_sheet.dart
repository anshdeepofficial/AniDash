import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';

class SubtitleSelectionSheet extends ConsumerWidget {
  final VoidCallback onLocalFilePressed;

  const SubtitleSelectionSheet({super.key, required this.onLocalFilePressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(episodeDataProvider);
    final existingSubtitles = data.subtitles;
    final selectedIndex = data.selectedSubtitleIdx;
    final delay = ref.watch(playerStateProvider.select((s) => s.subtitleDelay));

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Subtitles', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Subtitle Delay Offset',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      delay == 0
                          ? 'Synced (0.0s)'
                          : '${delay > 0 ? "+" : ""}${delay.toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            delay == 0
                                ? null
                                : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 32),
                      ),
                      onPressed:
                          () => ref
                              .read(playerStateProvider.notifier)
                              .adjustSubtitleDelay(-0.5),
                      child: const Text('-0.5s', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 32),
                      ),
                      onPressed:
                          () => ref
                              .read(playerStateProvider.notifier)
                              .adjustSubtitleDelay(-0.1),
                      child: const Text('-0.1s', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 32),
                      ),
                      onPressed:
                          delay == 0
                              ? null
                              : () => ref
                                  .read(playerStateProvider.notifier)
                                  .setSubtitleDelay(0.0),
                      child: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 32),
                      ),
                      onPressed:
                          () => ref
                              .read(playerStateProvider.notifier)
                              .adjustSubtitleDelay(0.1),
                      child: const Text('+0.1s', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 32),
                      ),
                      onPressed:
                          () => ref
                              .read(playerStateProvider.notifier)
                              .adjustSubtitleDelay(0.5),
                      child: const Text('+0.5s', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Iconsax.folder_open),
            title: const Text('Import Local File'),
            onTap: onLocalFilePressed,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: existingSubtitles.length,
              itemBuilder: (context, index) {
                final sub = existingSubtitles[index];
                final isSelected = index == selectedIndex;

                return ListTile(
                  title: Text(sub.lang ?? 'Unknown'),
                  trailing: isSelected
                      ? Icon(
                          Iconsax.tick_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () {
                    ref
                        .read(episodeDataProvider.notifier)
                        .changeSubtitle(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
