import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:ani_dash/helpers/show_subtitle_sidebar.dart';

import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';

class SettingsSheetContent extends ConsumerWidget {
  final VoidCallback onDismiss;
  const SettingsSheetContent({super.key, required this.onDismiss});

  void _showDialog(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
  }) {
    showDialog(context: context, builder: builder).then((_) {
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) onDismiss();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamData = ref.watch(episodeDataProvider);
    final streamNotifier = ref.read(episodeDataProvider.notifier);
    final playerSettings = ref.watch(playerSettingsProvider);
    final playerNotifier = ref.read(playerSettingsProvider.notifier);

    final currentQuality = streamData.selectedQualityIdx != null &&
            streamData.qualityOptions.isNotEmpty &&
            streamData.selectedQualityIdx! < streamData.qualityOptions.length
        ? streamData.qualityOptions[streamData.selectedQualityIdx!]['quality']
            ?.toString()
        : 'Auto';

    final hasSubtitles = streamData.selectedSubtitleIdx != 0;
    final currentSubLang = hasSubtitles &&
            streamData.selectedSubtitleIdx < streamData.subtitles.length
        ? streamData.subtitles[streamData.selectedSubtitleIdx].lang ?? 'On'
        : 'Off';

    final isDub = streamData.selectedServer?.isDub == true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Settings", style: Theme.of(context).textTheme.headlineSmall),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.high_quality_rounded),
                title: const Text("Video Quality"),
                trailing: Text(currentQuality ?? 'Auto'),
                onTap: () {
                  if (streamData.qualityOptions.isNotEmpty) {
                    _showDialog(
                      context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Select Quality"),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              streamData.qualityOptions.length,
                              (index) {
                                final opt = streamData.qualityOptions[index];
                                final isSelected =
                                    streamData.selectedQualityIdx == index;
                                return ListTile(
                                  title: Text(opt['quality']?.toString() ?? 'Option $index'),
                                  trailing: isSelected
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    streamNotifier.changeQuality(index);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  hasSubtitles ? Icons.closed_caption_rounded : Icons.closed_caption_off_rounded,
                ),
                title: const Text("Subtitles"),
                trailing: Text(currentSubLang),
                onTap: () {
                  if (hasSubtitles) {
                    streamNotifier.changeSubtitle(0);
                  } else if (streamData.subtitles.length > 1) {
                    final engIdx = streamData.subtitles.indexWhere(
                      (s) => s.lang?.toLowerCase().contains('eng') ?? false,
                    );
                    streamNotifier.changeSubtitle(engIdx != -1 ? engIdx : 1);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_rounded),
                title: const Text("Audio Track"),
                trailing: Text(isDub ? 'DUB' : 'SUB'),
                onTap: () => streamNotifier.toggleDubSub(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fast_forward_rounded),
                title: const Text("Auto Skip (Intro/Outro)"),
                value: playerSettings.enableAutoSkip,
                onChanged: (val) {
                  playerNotifier.updateSettings(
                    (prev) => prev.copyWith(enableAutoSkip: val),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.speedometer),
                title: const Text("Playback Speed"),
                trailing: Text(
                  "${ref.watch(playerStateProvider.select((p) => p.playbackSpeed))}x",
                ),
                onTap: () =>
                    _showDialog(context, builder: (ctx) => const SpeedDialog()),
              ),
              ListTile(
                leading: const Icon(Iconsax.crop),
                title: const Text("Video Fit"),
                trailing: Text(
                  _fitModeToString(
                    ref.watch(playerStateProvider.select((p) => p.fit)),
                  ),
                ),
                onTap: () =>
                    _showDialog(context, builder: (ctx) => const FitDialog()),
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_rounded),
                title: const Text("Subtitle Customization"),
                onTap: () {
                  Navigator.pop(context);
                  showSubtitleSettings(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeedDialog extends ConsumerStatefulWidget {
  const SpeedDialog({super.key});

  @override
  ConsumerState<SpeedDialog> createState() => _SpeedDialogState();
}

class _SpeedDialogState extends ConsumerState<SpeedDialog> {
  late double _selectedSpeed;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = ref.read(playerStateProvider).playbackSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Playback Speed"),
      content: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
            .map(
              (speed) => ChoiceChip(
                label: Text("${speed}x"),
                selected: _selectedSpeed == speed,
                onSelected: (isSelected) {
                  if (isSelected) setState(() => _selectedSpeed = speed);
                },
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            ref.read(playerStateProvider.notifier).setSpeed(_selectedSpeed);
            Navigator.pop(context);
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}

class FitDialog extends ConsumerStatefulWidget {
  const FitDialog({super.key});

  @override
  ConsumerState<FitDialog> createState() => _FitDialogState();
}

class _FitDialogState extends ConsumerState<FitDialog> {
  late BoxFit _selectedFit;
  static const fitModes = [BoxFit.contain, BoxFit.cover, BoxFit.fill];

  @override
  void initState() {
    super.initState();
    _selectedFit = ref.read(playerStateProvider).fit;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Video Fit"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fitModes
            .map(
              (fit) => RadioListTile<BoxFit>(
                title: Text(_fitModeToString(fit)),
                value: fit,
                groupValue: _selectedFit,
                onChanged: (value) {
                  if (value != null) setState(() => _selectedFit = value);
                },
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            ref.read(playerStateProvider.notifier).setFit(_selectedFit);
            Navigator.pop(context);
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}

String _fitModeToString(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'Contain';
    case BoxFit.cover:
      return 'Cover';
    case BoxFit.fill:
      return 'Fill';
    default:
      return 'Fit';
  }
}
