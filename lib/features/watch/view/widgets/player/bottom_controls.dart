import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ani_dash/core/models/aniskip/aniskip_result.dart';
import 'package:ani_dash/core/utils/formatter.dart';
import 'package:ani_dash/features/watch/view_model/aniskip_notifier.dart';
import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:ani_dash/helpers/show_subtitle_sidebar.dart';
import 'package:ani_dash/main.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';

class BottomControls extends ConsumerStatefulWidget {
  final VoidCallback onInteraction;
  final VoidCallback onLockPressed;
  final VoidCallback onSourcePressed;
  final VoidCallback onSubtitlePressed;
  final VoidCallback onServerPressed;
  final VoidCallback onForwardPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback? onEpisodePressed;
  final VoidCallback? onFullScreenPressed;
  final bool isLocal;

  const BottomControls({
    super.key,
    required this.onInteraction,
    required this.onLockPressed,
    required this.onSourcePressed,
    required this.onSubtitlePressed,
    required this.onServerPressed,
    required this.onForwardPressed,
    required this.onSettingsPressed,
    required this.onFullScreenPressed,
    this.onEpisodePressed,
    this.isLocal = false,
  });

  @override
  ConsumerState<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends ConsumerState<BottomControls> {
  static const _remainingTimePreference = 'player_show_remaining_time';
  double? _draggedValue;
  double _dragPositionX = 0.0;
  bool _showRemainingTime = false;

  @override
  void initState() {
    super.initState();
    _showRemainingTime = sharedPrefs.getBool(_remainingTimePreference) ?? false;
  }

  // VoidCallback _wrap(VoidCallback? cb) {
  //   return () {
  //     cb?.call();
  //     widget.onInteraction();
  //   };
  // }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeInsets = MediaQuery.viewPaddingOf(context);
    final maxSide = math.max(safeInsets.left, safeInsets.right);
    final sidePadding = (maxSide > 0 ? maxSide : 16.0) + 8.0;
    // final settings = ref.watch(playerSettingsProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.black87, Colors.transparent],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            0,
            sidePadding,
            safeInsets.bottom.clamp(8.0, 24.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildAniSkip(scheme),
                  ],
                ),
              ),

              _buildEdgeScrubber(context, scheme),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimeDisplay(),

                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.isLocal)
                              _FlatTextBtn(
                                text: ref.watch(
                                  episodeDataProvider.select(
                                    (s) =>
                                        s.selectedServer?.isDub == true
                                            ? 'DUB'
                                            : 'SUB',
                                  ),
                                ),
                                onTap:
                                    () =>
                                        ref
                                            .read(episodeDataProvider.notifier)
                                            .toggleDubSub(),
                                isAccent: true,
                                scheme: scheme,
                              ),
                            if (!widget.isLocal)
                              _ToolbarIcon(
                                icon: Icons.subtitles_rounded,
                                onTap: widget.onSubtitlePressed,
                                onHold: () => showSubtitleSettings(context),
                              ),
                            _ToolbarIcon(
                              icon: Icons.fullscreen_rounded,
                              onTap: widget.onFullScreenPressed,
                            ),
                            _ToolbarIcon(
                              icon: Icons.settings_rounded,
                              onTap: widget.onSettingsPressed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeScrubber(BuildContext context, ColorScheme scheme) {
    final (pos, dur, buf) = ref.watch(
      playerStateProvider.select((p) => (p.position, p.duration, p.buffer)),
    );
    final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
    final value = (_draggedValue ?? pos.inMilliseconds.toDouble()).clamp(
      0,
      max,
    );
    final buffer = buf.inMilliseconds.toDouble().clamp(0, max);
    final isDragging = _draggedValue != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) => widget.onInteraction(),
          onHorizontalDragUpdate: (details) {
            final percent = (details.localPosition.dx / constraints.maxWidth)
                .clamp(0.0, 1.0);
            setState(() {
              _draggedValue = percent * max;
              _dragPositionX = details.localPosition.dx;
            });
            widget.onInteraction();
          },
          onHorizontalDragEnd: (details) {
            if (_draggedValue != null) {
              ref
                  .read(playerStateProvider.notifier)
                  .seek(Duration(milliseconds: _draggedValue!.round()));
              setState(() => _draggedValue = null);
              widget.onInteraction();
            }
          },
          onTapDown: (details) {
            final percent = (details.localPosition.dx / constraints.maxWidth)
                .clamp(0.0, 1.0);
            ref
                .read(playerStateProvider.notifier)
                .seek(Duration(milliseconds: (percent * max).round()));
            widget.onInteraction();
          },
          child: SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: isDragging ? 7 : 4,
                  width: double.infinity,
                  color: Colors.white24,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      FractionallySizedBox(
                        widthFactor: buffer / max,
                        child: Container(color: Colors.white38),
                      ),
                      FractionallySizedBox(
                        widthFactor: value / max,
                        child: Container(color: scheme.primary),
                      ),
                      ..._buildHighlights(scheme, max, constraints.maxWidth),
                    ],
                  ),
                ),
                if (isDragging)
                  Positioned(
                    left: (value / max) * constraints.maxWidth - 6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isDragging)
                  Positioned(
                    left: (_dragPositionX - 25).clamp(
                      10.0,
                      constraints.maxWidth - 50.0,
                    ),
                    top: -20,
                    child: Text(
                      formatDuration(Duration(milliseconds: value.round())),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildHighlights(
    ColorScheme scheme,
    double total,
    double maxWidth,
  ) {
    final skips = ref.watch(aniSkipProvider);
    if (skips.isEmpty || total < 30000) return [];

    return skips.map((skip) {
      if (skip.interval == null) return const SizedBox.shrink();
      final start = skip.interval!.startTime * 1000;
      final end = skip.interval!.endTime * 1000;
      final segLength = end - start;
      if (start < 0 || end <= start || end > total + 3000) {
        return const SizedBox.shrink();
      }
      // Ensure segment length is sensible (e.g. between 5s and 200s, max 35% of episode)
      if (segLength < 5000 || segLength > 200000 || segLength > total * 0.35) {
        return const SizedBox.shrink();
      }

      final clampedStart = start.clamp(0, total);
      final clampedEnd = end.clamp(0, total);
      if (clampedEnd <= clampedStart) return const SizedBox.shrink();

      final isOp =
          skip.skipType == SkipType.op ||
          (skip.skipType == SkipType.mixed && clampedStart < total * 0.5);
      final isEd =
          skip.skipType == SkipType.ed ||
          (skip.skipType == SkipType.mixed && clampedStart >= total * 0.5) ||
          (!isOp && clampedStart >= total * 0.6);

      final highlightColor = Color.lerp(scheme.primary, Colors.black, 0.45)!;

      final startRatio = start / total;
      final endRatio = end / total;
      final width = (endRatio - startRatio) * maxWidth;
      final displayWidth = width.clamp(6.0, maxWidth);

      final label = isOp ? 'INTRO' : (isEd ? 'OUTRO' : 'SKIP');

      return Positioned(
        left: startRatio * maxWidth,
        width: displayWidth,
        top: -2,
        bottom: -2,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: highlightColor.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(2),
              ),
              child:
                  width >= 34
                      ? Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                        ),
                      )
                      : null,
            ),
            // Floating badge above the bar for narrow segments (e.g. short Outro)
            if (width < 34)
              Positioned(
                top: -14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  // Widget _buildPlayPauseButton(ColorScheme scheme) {
  //   final isPlaying = ref.watch(playerStateProvider.select((p) => p.isPlaying));
  //   return Material(
  //     color: Colors.transparent,
  //     child: InkWell(
  //       onTap: _wrap(ref.read(playerStateProvider.notifier).togglePlay),
  //       borderRadius: BorderRadius.circular(30),
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //         child: Icon(
  //           isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
  //           color: Colors.white,
  //           size: 36,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTimeDisplay() {
    final (pos, dur) = ref.watch(
      playerStateProvider.select((p) => (p.position, p.duration)),
    );

    final remaining = dur > pos ? dur - pos : Duration.zero;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _showRemainingTime = !_showRemainingTime);
        sharedPrefs.setBool(_remainingTimePreference, _showRemainingTime);
        widget.onInteraction();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatDuration(pos),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: '  /  ',
                style: TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text:
                    _showRemainingTime
                        ? '-${formatDuration(remaining)}'
                        : formatDuration(dur),
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 0.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildAniSkip(ColorScheme scheme) {
    final skips = ref.watch(aniSkipProvider);
    final settings = ref.watch(playerSettingsProvider);
    if (!settings.enableAniSkip) {
      return const SizedBox.shrink();
    }

    final pos = ref.watch(playerStateProvider.select((p) => p.position));
    final dur = ref.watch(playerStateProvider.select((p) => p.duration));

    final currentSkip = skips.firstWhere(
      (s) =>
          s.interval != null &&
          pos >= Duration(seconds: s.interval!.startTime.toInt()) &&
          pos < Duration(seconds: s.interval!.endTime.toInt()),
      orElse:
          () => const AniSkipResultItem(
            skipType: SkipType.unknown,
            action: '',
            episodeLength: 0,
          ),
    );

    if (currentSkip.interval == null) {
      if (settings.showManualSkip) {
        final skipSec = settings.manualSkipDuration;
        // 1. Intro window: First 150 seconds (2.5 mins)
        if (pos.inSeconds <= 150) {
          return _FlatActionBtn(
            text: 'Skip Intro (+${skipSec}s)',
            icon: Icons.fast_forward_rounded,
            onTap: () {
              final target = pos + Duration(seconds: skipSec);
              ref.read(playerStateProvider.notifier).seek(target);
              widget.onInteraction();
            },
            color: Color.lerp(scheme.primary, Colors.black, 0.45)!,
            textColor: Colors.white,
          );
        }
        // 2. Outro window: Last 150 seconds of episode
        else if (dur.inSeconds > 180 &&
            pos >= dur - const Duration(seconds: 150)) {
          return _FlatActionBtn(
            text: 'Skip Outro (+${skipSec}s)',
            icon: Icons.fast_forward_rounded,
            onTap: () {
              final target = pos + Duration(seconds: skipSec);
              ref.read(playerStateProvider.notifier).seek(target);
              widget.onInteraction();
            },
            color: Color.lerp(scheme.primary, Colors.black, 0.45)!,
            textColor: Colors.white,
          );
        }
      }
      return const SizedBox.shrink();
    }

    final isOp =
        currentSkip.skipType == SkipType.op ||
        (currentSkip.skipType == SkipType.mixed &&
            currentSkip.interval!.startTime < 700);
    final skipLabel = isOp ? 'INTRO' : 'OUTRO';
    final skipColor = Color.lerp(scheme.primary, Colors.black, 0.45)!;

    return _FlatActionBtn(
      text: 'Skip $skipLabel',
      icon: Icons.fast_forward_rounded,
      onTap: () {
        ref
            .read(playerStateProvider.notifier)
            .seek(Duration(seconds: currentSkip.interval!.endTime.toInt() + 1));
        widget.onInteraction();
      },
      color: skipColor,
      textColor: Colors.white,
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onHold;

  const _ToolbarIcon({required this.icon, this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _FlatTextBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isAccent;
  final ColorScheme? scheme;

  const _FlatTextBtn({
    required this.text,
    required this.onTap,
    this.isAccent = false,
    this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color:
            isAccent
                ? scheme?.primary.withValues(alpha: 0.15)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              text,
              style: TextStyle(
                color: isAccent ? scheme?.primary : Colors.white70,
                fontSize: 12,
                fontWeight: isAccent ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlatActionBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  const _FlatActionBtn({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
