import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screenshot/screenshot.dart';

import 'package:ani_dash/core/models/aniskip/aniskip_result.dart';
import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/core/repositories/watch_progress_repository.dart';
import 'package:ani_dash/core/services/audio_focus_service.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/features/watch/view_model/aniskip_notifier.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';
import 'package:ani_dash/features/watch/view_model/episode_stream_provider.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:ani_dash/features/watch/view_model/watch_progress_notifier.dart';
import 'package:ani_dash/features/watch/view_model/watch_sync_notifier.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';
import 'package:ani_dash/shared/providers/settings/sync_settings_notifier.dart';
import 'package:ani_dash/features/watch/view_model/next_episode_prompt_provider.dart';

part 'watch_controller.g.dart';

@riverpod
class WatchController extends _$WatchController with WidgetsBindingObserver {
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<String>? _playbackActionSubscription;
  int? _lastAniSkipEpisode;
  bool _isDisposed = false;
  bool _isPlayerReady = false;

  String? _mediaId, _animeName, _animeFormat, _animeCover;
  int? _malId;
  int _pos = 0, _dur = 0, _totalEps = 0;
  int? _epNum;
  String? _epTitle, _epThumb;

  int _lastSavedPos = -1;
  bool _trackingTriggered = false;
  bool _hasAutoAdvanced = false;
  bool _hasAutoSkippedIntro = false;
  bool _fromHentaiHub = false;
  bool _prefetchTriggered = false;
  bool _nextPromptTriggered = false;
  bool _wasPlayingBeforeLock = false;

  @override
  void build() {
    WidgetsBinding.instance.addObserver(this);

    _playbackActionSubscription = NotificationService().onPlaybackAction.listen(
      (action) {
        if (_isDisposed) return;
        if (action == 'play_pause') {
          ref
              .read(playerStateProvider.notifier)
              .videoController
              .player
              .playOrPause();
        } else if (action == 'prev') {
          ref.read(episodeDataProvider.notifier).changeEpisode(null, by: -1);
        } else if (action == 'next') {
          ref.read(episodeDataProvider.notifier).changeEpisode(null, by: 1);
        }
      },
    );

    ref.onDispose(() {
      _isDisposed = true;
      _completedSubscription?.cancel();
      _playbackActionSubscription?.cancel();
      NotificationService().hidePlaybackNotification();
      WidgetsBinding.instance.removeObserver(this);
      AudioFocusService().abandonAudioFocus();
      AudioFocusService().reset();
      _triggerSave();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final isPlaying = ref.read(playerStateProvider).isPlaying;
      if (isPlaying) {
        _wasPlayingBeforeLock = true;
        // Pause safely before hardware rendering surface detaches to keep MPV memory cache intact
        ref.read(playerStateProvider.notifier).pause();
      }
      _triggerSave();
    } else if (state == AppLifecycleState.resumed) {
      if (AudioFocusService().isPausedByInterruption) {
        // App returned to foreground after call interruption
        AudioFocusService().requestAudioFocus().then((granted) {
          if (granted && AudioFocusService().isPausedByInterruption) {
            AudioFocusService().isPausedByInterruption = false;
            ref.read(playerStateProvider.notifier).play();
          }
        });
      } else if (_wasPlayingBeforeLock) {
        _wasPlayingBeforeLock = false;
        // Cleanly resume from existing buffer without re-fetching stream from network
        ref.read(playerStateProvider.notifier).play();
      }
    }
  }

  void setScreenshotController(ScreenshotController controller) {
    ref
        .read(watchProgressProvider.notifier)
        .setScreenshotController(controller);
  }

  Future<void> initialize({
    required String animeName,
    required String? animeId,
    required List<EpisodeDataModel> episodes,
    required int initialEpisode,
    required String mediaId,
    required String? animeFormat,
    required String animeCover,
    int? malId,
    bool fromHentaiHub = false,
  }) async {
    if (_isDisposed) return;

    _mediaId = mediaId;
    _animeName = animeName;
    _animeFormat = animeFormat;
    _animeCover = animeCover;
    _totalEps = episodes.length;
    _fromHentaiHub = fromHentaiHub;
    _malId = malId;

    await ref
        .read(episodeListProvider.notifier)
        .fetchEpisodes(
          animeTitle: animeName,
          animeId: animeId,
          animeCover: animeCover,
          episodes: episodes,
          force: false,
          isAdult: fromHentaiHub,
        );

    AudioFocusService().initialize(
      onPauseRequested: () async {
        if (_isDisposed) return;
        await ref.read(playerStateProvider.notifier).pause();
      },
      onResumeRequested: () async {
        if (_isDisposed) return;
        await ref.read(playerStateProvider.notifier).play();
      },
    );

    await _initEpisode(mediaId, initialEpisode);
    _attachPlaybackListeners(mediaId, animeName, episodes);
  }

  Future<void> _initEpisode(String? mediaId, int initialEpisode) async {
    if (mediaId == null) return;

    _isPlayerReady = false;
    _epNum = initialEpisode;

    // Immediately update currentEpisode in repository so Continue Watching is updated on tap
    ref
        .read(watchProgressRepositoryProvider)
        .updateCurrentEpisode(mediaId, initialEpisode);

    Duration startAt = Duration.zero;
    final saved = ref
        .read(watchProgressRepositoryProvider)
        .getEpisodeProgress(mediaId, initialEpisode);
    final savedSeconds = saved?.progressInSeconds ?? 0;
    final savedDuration = saved?.durationInSeconds ?? 0;
    if (savedSeconds > 0 &&
        !((saved?.isCompleted ?? false) ||
            (savedDuration > 0 && savedSeconds >= savedDuration - 10))) {
      startAt = Duration(seconds: savedSeconds);
      AppLogger.i('Resuming episode $initialEpisode at ${startAt.inSeconds}s');
    }

    // Restore saved playback speed if customized
    final savedSpeed = ref.read(playerSettingsProvider).defaultPlaybackSpeed;
    if (savedSpeed != 1.0) {
      ref.read(playerStateProvider.notifier).setSpeed(savedSpeed);
    }

    final playerSettings = ref.read(playerSettingsProvider);
    if (playerSettings.enableAniSkip) {
      // Non-blocking: fetch skip times in background asynchronously without blocking stream loading
      ref
          .read(aniSkipProvider.notifier)
          .fetchSkipTimes(
            mediaId: mediaId,
            animeTitle: _animeName ?? '',
            episodeNumber: initialEpisode,
            episodeLength: 0,
            malId: _malId,
          );
    }

    await ref
        .read(episodeDataProvider.notifier)
        .loadEpisode(ep: initialEpisode, startAt: startAt);
  }

  void _attachPlaybackListeners(
    String mediaId,
    String animeName,
    List<EpisodeDataModel> episodes,
  ) {
    void triggerAutoAdvance() {
      if (_isDisposed || _hasAutoAdvanced || !_isPlayerReady) return;

      // VLC Mode: Halt playback if "Stop after this episode" is enabled
      if (ref.read(playerSettingsProvider).stopAfterCurrentEpisode) {
        AppLogger.i('Stop After This Episode active: Halting auto-advance.');
        ref.read(playerSettingsProvider.notifier).updateSettings(
          (s) => s.copyWith(stopAfterCurrentEpisode: false),
        );
        ref.read(playerStateProvider.notifier).pause();
        return;
      }

      final epList = ref.read(episodeListProvider).episodes;
      final effectiveTotal = _totalEps > 0 ? _totalEps : epList.length;
      if (effectiveTotal <= 1) return;
      _hasAutoAdvanced = true;
      var target = (_epNum ?? 0) + 1;
      if (target > effectiveTotal) return;
      if (ref.read(playerSettingsProvider).skipFillerEpisodes) {
        while (target <= effectiveTotal) {
          EpisodeDataModel? episode;
          for (final item in epList) {
            if (item.number == target) {
              episode = item;
              break;
            }
          }
          if (episode?.isFiller != true) break;
          target++;
        }
      }
      if (target > effectiveTotal) return;
      AppLogger.i('Auto-advancing to episode $target');
      ref.read(episodeDataProvider.notifier).changeEpisode(target);
    }

    _completedSubscription?.cancel();
    _completedSubscription = ref
        .read(playerStateProvider.notifier)
        .videoController
        .player
        .stream
        .completed
        .distinct()
        .listen((completed) {
          if (!completed) {
            _hasAutoAdvanced = false;
            return;
          }
          if (_isPlayerReady &&
              _dur > 30 &&
              _pos >= _dur - 2 &&
              !_hasAutoAdvanced &&
              !_isDisposed) {
            triggerAutoAdvance();
          }
        });

    ref.listen(playerStateProvider, (prev, next) {
      if (_isDisposed) return;

      _pos = next.position.inSeconds;
      _dur = next.duration.inSeconds;

      // Fetch skip ranges as soon as the manifest duration is known. This lets
      // auto-skip seek before the opening frames have to begin rendering.
      if (_dur > 30) _checkAniSkip(mediaId, animeName, next.duration);

      if (next.isPlaying && !(prev?.isPlaying ?? false)) {
        AudioFocusService().requestAudioFocus();
      }

      if (!_isPlayerReady) {
        if (_dur == 0 || next.position.inSeconds == 0) return;
        _isPlayerReady = true;
      }

      _checkAutoSkip(next.position);
      if (_dur > 30 && _pos >= _dur - 1) triggerAutoAdvance();

      // Flow optimizations: 85% pre-fetch & 95% next episode prompt
      if (_dur > 60) {
        final progressRatio = _pos / _dur;

        // 85% Trigger: Pre-fetch next episode stream in background
        if (!_prefetchTriggered && progressRatio >= 0.85) {
          _prefetchTriggered = true;
          ref.read(episodeDataProvider.notifier).prefetchNextEpisode();
        }

        // 95% Trigger: Show floating Next Episode prompt
        if (!_nextPromptTriggered && progressRatio >= 0.95) {
          _nextPromptTriggered = true;
          final settings = ref.read(playerSettingsProvider);
          if (settings.showNextEpisodePrompt) {
            ref.read(nextEpisodePromptProvider.notifier).show();
          }
        }
      }

      final syncPercentage = ref.read(syncSettingsProvider).syncPercentage;
      if (!_trackingTriggered &&
          _dur > 0 &&
          (_pos / _dur * 100) >= syncPercentage) {
        _trackingTriggered = true;
        if ((_epNum ?? 0) > 0) {
          ref
              .read(watchSyncProvider.notifier)
              .handleTrackingUpdate(mediaId: mediaId, episodeNum: _epNum!);
        }
      }

      _handlePeriodicSave();
    });

    ref.listen(aniSkipProvider, (previous, next) {
      if (_isDisposed ||
          !ref.read(playerSettingsProvider).enableAutoSkip ||
          next.isEmpty) {
        return;
      }
      final position = ref.read(playerStateProvider).position;
      _checkAutoSkip(position);
    });

    ref.listen(episodeDataProvider.select((p) => p.selectedEpisode), (
      prev,
      next,
    ) {
      if (prev != null && prev != next && _epNum == prev) {
        saveProgressManual(takeScreenshot: true);
      }

      if (next != null) {
        _hasAutoSkippedIntro = false;
        _lastAniSkipEpisode = null;
        _epNum = next;
        _pos = 0;
        _dur = 0;
        _trackingTriggered = false;
        _prefetchTriggered = false;
        _nextPromptTriggered = false;
        _isPlayerReady = false;
        ref.read(nextEpisodePromptProvider.notifier).dismiss();
        ref.read(watchProgressProvider.notifier).resetLastSavedPosition();

        try {
          final epInfo = episodes.firstWhere((e) => e.number == next);
          _epTitle = epInfo.title;
          _epThumb = epInfo.thumbnail;
        } catch (_) {}
      }
    });
  }

  Future<void> _handlePeriodicSave() async {
    if (_lastSavedPos == -1) _lastSavedPos = _pos;

    if ((_pos - _lastSavedPos).abs() >= 5) {
      _lastSavedPos = _pos;
      _triggerSave(takeScreenshot: false);
    }
  }

  Future<void> _triggerSave({bool takeScreenshot = false}) async {
    if (_mediaId == null || _epNum == null) return;

    final newThumb = await ref
        .read(watchProgressProvider.notifier)
        .saveProgress(
          mediaId: _mediaId!,
          animeName: _animeName!,
          animeFormat: _animeFormat,
          animeCover: _animeCover!,
          totalEps: _totalEps,
          epNum: _epNum!,
          epTitle: _epTitle,
          epThumb: _epThumb,
          pos: _pos,
          dur: _dur,
          takeScreenshot: takeScreenshot,
          isAdult: _fromHentaiHub,
        );

    if (newThumb != null) _epThumb = newThumb;
  }

  Future<void> saveProgressManual({bool takeScreenshot = false}) async {
    if (_isDisposed) return;
    await _triggerSave(takeScreenshot: takeScreenshot);
  }

  void _checkAniSkip(String mediaId, String animeName, Duration duration) {
    if (!ref.read(playerSettingsProvider).enableAniSkip) {
      ref.read(aniSkipProvider.notifier).clear();
      return;
    }

    final epNum = _epNum;
    if (epNum == null) return;

    final currentSkips = ref.read(aniSkipProvider);
    final hasEd = currentSkips.any((s) => s.skipType == SkipType.ed);
    // If we already fetched for this episode and have both OP & ED, skip re-fetch
    if (epNum == _lastAniSkipEpisode && hasEd) return;

    _lastAniSkipEpisode = epNum;
    ref
        .read(aniSkipProvider.notifier)
        .fetchSkipTimes(
          mediaId: mediaId,
          animeTitle: animeName,
          episodeNumber: epNum,
          episodeLength: duration.inSeconds,
        );
  }

  void _checkAutoSkip(Duration position) {
    if (!ref.read(playerSettingsProvider).enableAutoSkip) return;

    final skips = ref.read(aniSkipProvider);
    if (skips.isEmpty) return;

    for (final skip in skips) {
      if (skip.interval == null) continue;
      final isIntro =
          skip.skipType == SkipType.op || skip.skipType == SkipType.mixed;
      if (isIntro && _hasAutoSkippedIntro) continue;

      final start = Duration(seconds: skip.interval!.startTime.toInt());
      final end = Duration(seconds: skip.interval!.endTime.toInt() + 1);

      final validType =
          skip.skipType == SkipType.op ||
          skip.skipType == SkipType.ed ||
          skip.skipType == SkipType.mixed;
      final length = end - start;
      final validTiming =
          start >= Duration.zero &&
          end > start &&
          end <= Duration(seconds: _dur + 3) &&
          length <= const Duration(minutes: 5) &&
          length.inSeconds <= (_dur * 0.25);

      if (validType && validTiming && position >= start && position < end) {
        if (isIntro) _hasAutoSkippedIntro = true;
        ref.read(playerStateProvider.notifier).seek(end);
        return;
      }
    }
  }
}
