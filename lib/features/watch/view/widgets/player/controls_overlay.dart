import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/features/watch/view/widgets/player/bottom_controls.dart';
import 'package:ani_dash/features/watch/view/widgets/player/center_controls.dart';
import 'package:ani_dash/features/watch/view/widgets/player/top_controls.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';

class ControlsOverlay extends ConsumerWidget {
  final bool visible;
  final bool locked;
  final VoidCallback onLockPressed;
  final VoidCallback onRestartHide;
  final VoidCallback? onEpisodesPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onQualityPressed;
  final VoidCallback onSourcePressed;
  final VoidCallback onServerPressed;
  final VoidCallback onAudioPressed;
  final VoidCallback onSubtitlePressed;
  final VoidCallback onFullScreenPressed;
  final String? localTitle;
  final bool isLocal;

  const ControlsOverlay({
    super.key,
    required this.visible,
    required this.locked,
    required this.onLockPressed,
    required this.onRestartHide,
    this.onEpisodesPressed,
    required this.onSettingsPressed,
    required this.onQualityPressed,
    required this.onSourcePressed,
    required this.onServerPressed,
    required this.onAudioPressed,
    required this.onSubtitlePressed,
    required this.onFullScreenPressed,
    this.localTitle,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locked) {
      return Stack(
        children: [
          Positioned(
            left: 32,
            right: 32,
            bottom: MediaQuery.viewPaddingOf(context).bottom.clamp(8.0, 24.0),
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: _lockedProgress(context, ref),
            ),
          ),
          AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(ignoring: !visible, child: _lockBtn()),
          ),
        ],
      );
    }
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(ignoring: !visible, child: _controls(ref)),
    );
  }

  Widget _lockedProgress(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final durationMs = state.duration.inMilliseconds;
    final positionMs = state.position.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );
    final progress = durationMs > 0 ? positionMs / durationMs : 0.0;
    final remaining =
        durationMs > 0
            ? Duration(milliseconds: durationMs - positionMs)
            : Duration.zero;
    String time(Duration value) {
      final hours = value.inHours;
      final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
      return hours > 0
          ? '$hours:$minutes:$seconds'
          : '${value.inMinutes}:$seconds';
    }

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time(state.position),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                '-${time(remaining)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockBtn() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: IconButton(
          onPressed: onLockPressed,
          icon: const Icon(Icons.lock_open, size: 32, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
      ),
    );
  }

  Widget _controls(WidgetRef ref) {
    final notifier = ref.read(playerStateProvider.notifier);
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeOut;

    return RepaintBoundary(
      child: Stack(
        children: [
          CenterControls(onInteraction: onRestartHide),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: IconButton(
                onPressed: onLockPressed,
                icon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 30,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: duration,
            curve: curve,
            top: visible ? 0 : -100,
            left: 0,
            right: 0,
            child: TopControls(
              onInteraction: onRestartHide,
              onEpisodesPressed: onEpisodesPressed,
              onSettingsPressed: onSettingsPressed,
              onQualityPressed: onQualityPressed,
              titleOverride: localTitle,
              sourceOverride: isLocal ? 'DOWNLOADED' : null,
              isLocal: isLocal,
            ),
          ),
          AnimatedPositioned(
            duration: duration,
            curve: curve,
            bottom: visible ? 0 : -120,
            left: 0,
            right: 0,
            child: BottomControls(
              onInteraction: onRestartHide,
              onLockPressed: onLockPressed,
              onEpisodePressed: onEpisodesPressed,
              onForwardPressed: () => notifier.forward(85),
              onSettingsPressed: onSettingsPressed,
              onSourcePressed: onSourcePressed,
              onSubtitlePressed: onSubtitlePressed,
              onServerPressed: onServerPressed,
              onAudioPressed: onAudioPressed,
              onFullScreenPressed: onFullScreenPressed,
              isLocal: isLocal,
            ),
          ),
        ],
      ),
    );
  }
}
