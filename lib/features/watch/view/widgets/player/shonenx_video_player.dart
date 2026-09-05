import 'dart:async';
import 'dart:io';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screenshot/screenshot.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/features/watch/view/widgets/player/controls_overlay.dart';
import 'package:ani_dash/features/watch/view/widgets/player/player_gesture_handler.dart';
import 'package:ani_dash/features/watch/view/widgets/player/seek_indicator.dart';
import 'package:ani_dash/features/watch/view/widgets/player/sheets/generic_selection_sheet.dart';
import 'package:ani_dash/features/watch/view/widgets/player/sheets/settings_sheet.dart';
import 'package:ani_dash/features/watch/view/widgets/player/sheets/subtitle_selection_sheet.dart';
import 'package:ani_dash/features/watch/view/widgets/player/speed_indicator_overlay.dart';
import 'package:ani_dash/features/watch/view/widgets/player/subtitle_overlay.dart';
import 'package:ani_dash/features/watch/view/widgets/player/volume_brightness_overlay.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';
import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:ani_dash/features/watch/view_model/player/player_ui_controller.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';
import 'package:ani_dash/features/watch/view/widgets/player/vlc_seek_overlay.dart';
import 'package:ani_dash/features/watch/view/widgets/player/fetching_progress_badge.dart';
import 'package:ani_dash/features/watch/view/widgets/player/next_episode_prompt_overlay.dart';
import 'package:ani_dash/helpers/ui.dart';
import 'package:window_manager/window_manager.dart';

class AniDashVideoPlayer extends ConsumerStatefulWidget {
  final VoidCallback? onEpisodesPressed;
  final VoidCallback? onPanelCloseRequest;
  final ScreenshotController? screenshotController;
  final String? localFilePath;
  final String? localTitle;

  const AniDashVideoPlayer({
    super.key,
    this.onEpisodesPressed,
    this.onPanelCloseRequest,
    this.screenshotController,
    this.localFilePath,
    this.localTitle,
  });

  @override
  ConsumerState<AniDashVideoPlayer> createState() => _AniDashVideoPlayerState();
}

class _AniDashVideoPlayerState extends ConsumerState<AniDashVideoPlayer> {
  final FocusNode _focusNode = FocusNode();

  // Local state for complex interactions that don't need to be global/persisted
  bool _isChangingVolume = false;
  bool _isChangingBrightness = false;
  bool _isDragLeft = false;
  bool _isSpeeding = false;
  double _lastSpeed = 1.0;
  Timer? _volumeOverlayTimer;

  bool _isDraggingSeek = false;
  Duration _dragStartPos = Duration.zero;
  Duration _dragTargetPos = Duration.zero;
  Duration _dragDiff = Duration.zero;
  bool _isDragSeekForward = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      FlutterVolumeController.updateShowSystemUI(false);
      UIHelper.enableVolumeInterception();
      UIHelper.setVolumeKeyHandler(
        onVolumeUp: () => _handleHardwareVolumeKey(true),
        onVolumeDown: () => _handleHardwareVolumeKey(false),
      );
    }
    // Restart auto-hide timer on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        ref.read(playerUIControllerProvider.notifier).restartHideTimer();
        final path = widget.localFilePath;
        if (path != null) {
          ref.read(playerStateProvider.notifier).open(path, Duration.zero);
        }
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _volumeOverlayTimer?.cancel();
    if (Platform.isAndroid || Platform.isIOS) {
      UIHelper.disableVolumeInterception();
      UIHelper.removeVolumeKeyHandler();
      FlutterVolumeController.updateShowSystemUI(true);
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      windowManager.setFullScreen(false);
    }
    super.dispose();
  }

  void _handleHardwareVolumeKey(bool isUp) {
    if (!mounted) return;
    if (ref.read(playerUIControllerProvider).isLocked) return;

    final controller = ref.read(playerUIControllerProvider.notifier);
    final state = ref.read(playerUIControllerProvider);

    const step = 0.05; // 5% per press
    double newV = (state.volume + (isUp ? step : -step)).clamp(0.0, 2.0);

    setState(() {
      _isChangingVolume = true;
    });

    controller.setVolume(newV);

    if (newV > 1.0) {
      final gain = (newV * 100);
      ref
          .read(playerStateProvider.notifier)
          .videoController
          .player
          .setVolume(gain);
    } else {
      ref
          .read(playerStateProvider.notifier)
          .videoController
          .player
          .setVolume(100.0);
    }

    _volumeOverlayTimer?.cancel();
    _volumeOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isChangingVolume = false;
        });
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (ref.read(playerUIControllerProvider).isLocked) return;
    final w = MediaQuery.of(context).size.width;
    _isDragLeft = details.globalPosition.dx < w / 2;

    setState(() {
      if (_isDragLeft) {
        _isChangingBrightness = true;
      } else {
        _isChangingVolume = true;
      }
    });

    // Hide controls while dragging
    ref
        .read(playerUIControllerProvider.notifier)
        .toggleVisibility(override: false);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) async {
    if (ref.read(playerUIControllerProvider).isLocked) return;
    final delta = -details.primaryDelta! / 300;

    final controller = ref.read(playerUIControllerProvider.notifier);
    final state = ref.read(playerUIControllerProvider);

    if (_isDragLeft) {
      double newB = (state.brightness + delta).clamp(0.0, 1.0);
      controller.setBrightness(newB);
    } else {
      double newV = (state.volume + delta).clamp(0.0, 2.0);

      // Update system/player volume
      controller.setVolume(newV);

      // Update actual player gain if needed (boost up to 200%)
      if (newV > 1.0) {
        final gain = (newV * 100);
        ref
            .read(playerStateProvider.notifier)
            .videoController
            .player
            .setVolume(gain);
      } else {
        ref
            .read(playerStateProvider.notifier)
            .videoController
            .player
            .setVolume(100.0);
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isChangingBrightness = false;
      _isChangingVolume = false;
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (ref.read(playerUIControllerProvider).isLocked) return;
    final playerState = ref.read(playerStateProvider);
    _dragStartPos = playerState.position;
    _dragTargetPos = playerState.position;
    _dragDiff = Duration.zero;
    setState(() {
      _isDraggingSeek = true;
    });
    ref
        .read(playerUIControllerProvider.notifier)
        .toggleVisibility(override: false);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingSeek) return;
    final w = MediaQuery.of(context).size.width;
    final playerState = ref.read(playerStateProvider);
    final total = playerState.duration;

    final deltaSec = (details.primaryDelta! / w) * 120;
    final currentTargetSec = _dragTargetPos.inMilliseconds / 1000.0 + deltaSec;
    final clampedSec = currentTargetSec.clamp(
      0.0,
      total.inSeconds > 0 ? total.inSeconds.toDouble() : 3600.0,
    );

    final newTarget = Duration(milliseconds: (clampedSec * 1000).toInt());
    final diff = Duration(
      milliseconds: newTarget.inMilliseconds - _dragStartPos.inMilliseconds,
    );

    setState(() {
      _dragTargetPos = newTarget;
      _dragDiff = diff;
      _isDragSeekForward = diff.inMilliseconds >= 0;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDraggingSeek) return;
    setState(() {
      _isDraggingSeek = false;
    });
    ref.read(playerStateProvider.notifier).seek(_dragTargetPos);
  }

  void _onDoubleTap(bool forward) {
    if (ref.read(playerUIControllerProvider).isLocked) return;

    final notifier = ref.read(playerStateProvider.notifier);
    final settings = ref.read(playerSettingsProvider);
    final jump = settings.seekDuration;

    forward ? notifier.forward(jump) : notifier.rewind(jump);

    ref
        .read(playerUIControllerProvider.notifier)
        .showSeekIndicator(forward, jump);
  }

  void _onLongPressStart() {
    if (ref.read(playerUIControllerProvider).isLocked) return;
    ref
        .read(playerUIControllerProvider.notifier)
        .toggleVisibility(override: false);

    setState(() {
      _isSpeeding = true;
      _lastSpeed = 2.0;
    });
    ref.read(playerStateProvider.notifier).setSpeed(2.0);
  }

  void _onLongPressUpdate(double diff) {
    if (_isSpeeding) {
      double newRate = 2.0 + (diff / 50.0);
      newRate = (newRate * 4).round() / 4;
      newRate = newRate.clamp(0.25, 4.0);

      if (newRate != _lastSpeed) {
        setState(() => _lastSpeed = newRate);
        ref.read(playerStateProvider.notifier).setSpeed(newRate);
      }
    }
  }

  void _onLongPressEnd() {
    if (_isSpeeding) {
      setState(() => _isSpeeding = false);
      ref.read(playerStateProvider.notifier).setSpeed(1.0);
    }
  }

  // --- Sheet/Dialog Logic ---

  Future<void> _sheet(Widget child) async {
    final controller = ref.read(playerUIControllerProvider.notifier);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(240),
      builder: (_) => child,
    );
    controller.restartHideTimer();
  }

  void _openSettings() => _sheet(
    SettingsSheetContent(
      onDismiss: () {
        ref.read(playerUIControllerProvider.notifier).restartHideTimer();
      },
    ),
  );

  void _openQuality() {
    final data = ref.read(episodeDataProvider);
    final notifier = ref.read(episodeDataProvider.notifier);

    _sheet(
      GenericSelectionSheet<Map<String, dynamic>>(
        title: 'Quality',
        items: data.qualityOptions,
        selectedIndex: data.selectedQualityIdx ?? -1,
        displayBuilder: (e) => e['quality'],
        onItemSelected: (i) {
          notifier.changeQuality(i);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openSource() {
    final data = ref.read(episodeDataProvider);
    final notifier = ref.read(episodeDataProvider.notifier);

    _sheet(
      GenericSelectionSheet<Source>(
        title: 'Source',
        items: data.sources,
        selectedIndex: data.selectedSourceIdx ?? -1,
        displayBuilder: (e) => e.quality ?? '',
        onItemSelected: (i) {
          notifier.changeSource(i);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openServer() {
    final data = ref.read(episodeDataProvider);
    if (data.servers.isEmpty) return;

    final selectedIdx = data.servers.indexWhere(
      (s) =>
          s.id == data.selectedServer?.id &&
          s.isDub == data.selectedServer?.isDub,
    );

    _sheet(
      GenericSelectionSheet<String>(
        title: 'Server',
        items:
            data.servers
                .map(
                  (e) =>
                      '${(e.id ?? 'Server').toUpperCase()}${e.name?.isNotEmpty == true && e.name != e.id ? ' (${e.name})' : ''} [${e.isDub ? 'DUB' : 'SUB'}]',
                )
                .toList(),
        selectedIndex: selectedIdx != -1 ? selectedIdx : 0,
        displayBuilder: (e) => e,
        onItemSelected: (i) {
          ref.read(episodeDataProvider.notifier).changeServer(data.servers[i]);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _toggleFullScreen() async {
    UIHelper.handleToggleFullscreen();
  }

  void _openSubtitle() {
    _sheet(SubtitleSelectionSheet(onLocalFilePressed: _pickLocalSubtitle));
  }

  Future<void> _pickLocalSubtitle() async {
    final notifier = ref.read(episodeDataProvider.notifier);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await notifier.addLocalSubtitle(file);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded: ${result.files.single.name}')),
        );
      }
    } catch (e) {
      AppLogger.e('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerStateProvider.notifier);
    final state = ref.watch(playerStateProvider);
    final uiState = ref.watch(playerUIControllerProvider);
    final uiController = ref.watch(playerUIControllerProvider.notifier);

    final episodeStreamState = ref.watch(
      episodeDataProvider.select((e) => e.states),
    );
    final episodesLoading = ref.watch(
      episodeListProvider.select((e) => e.isLoading),
    );
    final isBusy =
        state.isBuffering ||
        episodesLoading ||
        episodeStreamState.contains(EpisodeStreamState.SOURCE_LOADING) ||
        episodeStreamState.contains(EpisodeStreamState.SERVER_LOADING) ||
        episodeStreamState.contains(EpisodeStreamState.QUALITY_LOADING);

    Widget videoView = Video(
      controller: notifier.videoController,
      fit: state.fit,
      wakelock: true,
      filterQuality: kDebugMode ? FilterQuality.none : FilterQuality.low,
      controls: NoVideoControls,
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        visible: false,
      ),
    );

    if (widget.screenshotController != null) {
      videoView = Screenshot(
        controller: widget.screenshotController!,
        child: videoView,
      );
    }

    return MouseRegion(
      cursor:
          !uiState.isVisible
              ? SystemMouseCursors.none
              : SystemMouseCursors.click,
      onHover: (_) => uiController.toggleVisibility(override: true),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): notifier.togglePlay,
          const SingleActivator(LogicalKeyboardKey.keyK): notifier.togglePlay,
          const SingleActivator(LogicalKeyboardKey.keyL):
              uiController.toggleLock,
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              () => notifier.rewind(10),
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              () => notifier.forward(10),
          const SingleActivator(LogicalKeyboardKey.keyM): notifier.toggleMute,
          const SingleActivator(LogicalKeyboardKey.f11): _toggleFullScreen,
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullScreen,
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Layer
              videoView,

              // Gesture Layer (Background)
              Positioned.fill(
                child: PlayerGestureHandler(
                  onTap: () {
                    widget.onPanelCloseRequest?.call();
                    uiController.toggleVisibility();
                  },
                  onDoubleTap: _onDoubleTap,
                  onLongPressStart: _onLongPressStart,
                  onLongPressUpdate: _onLongPressUpdate,
                  onLongPressEnd: _onLongPressEnd,
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onEpisodesPressed: widget.onEpisodesPressed,
                  child: Container(color: Colors.transparent),
                ),
              ),

              // Controls & UI Layer (Foreground)
              ControlsOverlay(
                visible: uiState.isVisible,
                locked: uiState.isLocked,
                onLockPressed: uiController.toggleLock,
                onRestartHide: uiController.restartHideTimer,
                onEpisodesPressed: widget.onEpisodesPressed,
                onSettingsPressed: _openSettings,
                onQualityPressed: _openQuality,
                onSourcePressed: _openSource,
                onServerPressed: _openServer,
                onSubtitlePressed: _openSubtitle,
                onFullScreenPressed: _toggleFullScreen,
                localTitle: widget.localTitle,
                isLocal: widget.localFilePath != null,
              ),

              // Standalone Loading Indicator when controls are hidden
              if (isBusy && !uiState.isVisible)
                const Center(
                  child: IgnorePointer(
                    child: FetchingProgressBadge(isEpisode: false),
                  ),
                ),

              // VLC-style Horizontal Swipe Seek Indicator
              if (_isDraggingSeek)
                VlcSeekOverlay(
                  targetPosition: _dragTargetPos,
                  totalDuration: ref.read(playerStateProvider).duration,
                  diffDuration: _dragDiff,
                  isForward: _isDragSeekForward,
                ),

              // Seek Indicator (Dynamic)
              if (uiState.seekAmount != 0)
                Positioned.fill(
                  child: Align(
                    alignment:
                        uiState.isSeekForward
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: SeekIndicatorOverlay(
                      isForward: uiState.isSeekForward,
                      seconds: uiState.seekAmount.abs(),
                    ),
                  ),
                ),

              // Speed Indicator
              if (_isSpeeding) SpeedIndicatorOverlay(currentSpeed: _lastSpeed),

              // Volume/Brightness Overlays
              if (_isChangingBrightness)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: VolumeBrightnessOverlay(
                      isVolume: false,
                      value: uiState.brightness,
                    ),
                  ),
                ),
              if (_isChangingVolume)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: VolumeBrightnessOverlay(
                      isVolume: true,
                      value: uiState.volume,
                    ),
                  ),
                ),

              // Subtitles
              Positioned(
                left: 8,
                right: 8,
                bottom: uiState.isVisible ? 90 : 20,
                child: const SubtitleOverlay(),
              ),

              // Floating Next Episode Recommendation Prompt (at 95% progress)
              const NextEpisodePromptOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
