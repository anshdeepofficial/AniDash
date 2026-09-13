import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/models/aniskip/aniskip_result.dart';
import 'package:ani_dash/features/watch/view_model/aniskip_notifier.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:ani_dash/features/watch/view_model/player/player_ui_controller.dart';
import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';

class FloatingSkipButtonOverlay extends ConsumerStatefulWidget {
  const FloatingSkipButtonOverlay({super.key});

  @override
  ConsumerState<FloatingSkipButtonOverlay> createState() =>
      _FloatingSkipButtonOverlayState();
}

class _FloatingSkipButtonOverlayState
    extends ConsumerState<FloatingSkipButtonOverlay> {
  int? _lastEpisode;
  bool _introDismissed = false;
  bool _outroDismissed = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(playerSettingsProvider);
    // Hide the manual skip buttons completely if auto-skip is enabled or ani-skip is disabled
    if (!settings.enableAniSkip || settings.enableAutoSkip) {
      return const SizedBox.shrink();
    }

    final currentEp = ref.watch(
      episodeDataProvider.select((s) => s.selectedEpisode),
    );
    if (currentEp != _lastEpisode) {
      _lastEpisode = currentEp;
      _introDismissed = false;
      _outroDismissed = false;
    }

    final (pos, dur) = ref.watch(
      playerStateProvider.select((p) => (p.position, p.duration)),
    );
    final isControlsVisible = ref.watch(
      playerUIControllerProvider.select((s) => s.isVisible),
    );

    // Reset intro dismissal if user rewound back to the very start (< 5 seconds)
    if (pos.inSeconds < 5 && _introDismissed) {
      _introDismissed = false;
    }
    // Reset outro dismissal if user rewound back before the ending credits
    if (dur.inSeconds > 180 &&
        pos < dur - const Duration(seconds: 120) &&
        _outroDismissed) {
      _outroDismissed = false;
    }

    final skips = ref.watch(aniSkipProvider);

    // Check AniSkip matching interval
    final currentSkip = skips.firstWhere(
      (s) =>
          s.interval != null &&
          pos >= Duration(seconds: s.interval!.startTime.toInt()) &&
          pos < Duration(seconds: s.interval!.endTime.toInt()),
      orElse: () => const AniSkipResultItem(
        skipType: SkipType.unknown,
        action: '',
        episodeLength: 0,
      ),
    );

    String? label;
    VoidCallback? onSkip;

    if (currentSkip.interval != null) {
      final isOp =
          currentSkip.skipType == SkipType.op ||
          (currentSkip.skipType == SkipType.mixed &&
              currentSkip.interval!.startTime < 700);
      final isEd =
          currentSkip.skipType == SkipType.ed ||
          (currentSkip.skipType == SkipType.mixed &&
              currentSkip.interval!.startTime >= 700);

      if (isOp && !_introDismissed) {
        label = 'Skip Intro';
        onSkip = () {
          setState(() => _introDismissed = true);
          final target = Duration(
            seconds: currentSkip.interval!.endTime.toInt() + 1,
          );
          ref.read(playerStateProvider.notifier).seek(target);
          ref.read(playerUIControllerProvider.notifier).restartHideTimer();
        };
      } else if (isEd && !_outroDismissed) {
        label = 'Skip Outro';
        onSkip = () {
          setState(() => _outroDismissed = true);
          final target = Duration(
            seconds: currentSkip.interval!.endTime.toInt() + 1,
          );
          ref.read(playerStateProvider.notifier).seek(target);
          ref.read(playerUIControllerProvider.notifier).restartHideTimer();
        };
      }
    } else if (settings.showManualSkip) {
      final skipSec = settings.manualSkipDuration;
      // 1. Intro window: First 90 seconds (standard anime OP length)
      if (pos.inSeconds <= 90 && !_introDismissed) {
        label = 'Skip Intro (+${skipSec}s)';
        onSkip = () {
          setState(() => _introDismissed = true);
          final target = pos + Duration(seconds: skipSec);
          ref.read(playerStateProvider.notifier).seek(target);
          ref.read(playerUIControllerProvider.notifier).restartHideTimer();
        };
      }
      // 2. Outro window: Last 85 seconds of episode (standard anime ED window)
      else if (dur.inSeconds > 180 &&
          pos >= dur - const Duration(seconds: 85) &&
          !_outroDismissed) {
        label = 'Skip Outro (+${skipSec}s)';
        onSkip = () {
          setState(() => _outroDismissed = true);
          final target = pos + Duration(seconds: skipSec);
          ref.read(playerStateProvider.notifier).seek(target);
          ref.read(playerUIControllerProvider.notifier).restartHideTimer();
        };
      }
    }

    if (label == null || onSkip == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: isControlsVisible ? 115 : 28,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fast_forward_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
