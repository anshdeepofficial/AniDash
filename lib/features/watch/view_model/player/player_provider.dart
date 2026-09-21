import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

part 'player_provider.g.dart';

@immutable
class PlayerState {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool isPlaying;
  final bool isBuffering;
  final bool isSeeking;
  final bool isOpening;
  final String? playbackError;
  final double playbackSpeed;
  final List<String> subtitle;
  final BoxFit fit;
  final double subtitleDelay;

  const PlayerState({
    required this.position,
    required this.duration,
    required this.buffer,
    required this.isPlaying,
    required this.isBuffering,
    required this.isSeeking,
    required this.isOpening,
    this.playbackError,
    required this.playbackSpeed,
    required this.subtitle,
    required this.fit,
    this.subtitleDelay = 0.0,
  });

  factory PlayerState.initial() => const PlayerState(
    position: Duration.zero,
    duration: Duration.zero,
    buffer: Duration.zero,
    isPlaying: false,
    isBuffering: false,
    isSeeking: false,
    isOpening: false,
    playbackSpeed: 1.0,
    subtitle: [],
    fit: BoxFit.contain,
    subtitleDelay: 0.0,
  );

  PlayerState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? isPlaying,
    bool? isBuffering,
    bool? isSeeking,
    bool? isOpening,
    String? playbackError,
    bool clearPlaybackError = false,
    double? playbackSpeed,
    List<String>? subtitle,
    BoxFit? fit,
    double? subtitleDelay,
  }) {
    return PlayerState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isSeeking: isSeeking ?? this.isSeeking,
      isOpening: isOpening ?? this.isOpening,
      playbackError:
          clearPlaybackError ? null : (playbackError ?? this.playbackError),
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      subtitle: subtitle ?? this.subtitle,
      fit: fit ?? this.fit,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
    );
  }
}

@Riverpod(keepAlive: true)
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late final Player _player;
  late final VideoController videoController;
  final List<StreamSubscription> _subs = [];
  String? _lastUrl;
  Map<String, String>? _lastHeaders;
  Duration? _pendingSeekTarget;
  Timer? _seekTimeout;
  Timer? _startupTimer;
  String? _activeMediaId;
  int? _activeEpisode;

  Player get player => _player;
  String? get activeMediaId => _activeMediaId;
  int? get activeEpisode => _activeEpisode;

  void setActiveSession(String? mediaId, int? episode) {
    _activeMediaId = mediaId;
    _activeEpisode = episode;
  }

  bool isCurrentEpisodeLoaded({
    required String? mediaId,
    required int? episode,
  }) {
    if (mediaId == null || episode == null) return false;
    return _activeMediaId == mediaId &&
        _activeEpisode == episode &&
        _lastUrl != null &&
        state.playbackError == null &&
        !_player.state.completed &&
        _player.state.duration > Duration.zero;
  }

  @override
  PlayerState build() {
    final settings = ref.read(playerSettingsProvider);
    final mpvSettings = settings.mpvSettings;
    final vo = mpvSettings['vo'];
    final bufferSize = ref.read(
      playerSettingsProvider.select((s) => s.bufferSize),
    );
    final effectiveBufferBytes = (bufferSize.toInt() * 1024 * 1024).clamp(
      32 * 1024 * 1024,
      128 * 1024 * 1024,
    );
    final backBufferBytes = (effectiveBufferBytes ~/ 4).clamp(
      8 * 1024 * 1024,
      32 * 1024 * 1024,
    );
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: effectiveBufferBytes,
        logLevel: MPVLogLevel.warn,
        vo: vo,
      ),
    );

    // Highly optimized, rock-solid buffering for smooth continuous playback on any connection
    final fastProperties = <String, String>{
      'hwdec': 'auto-safe',
      'cache': 'yes',
      'demuxer-seekable-cache': 'yes',
      'demuxer-max-bytes': effectiveBufferBytes.toString(),
      'demuxer-max-back-bytes': backBufferBytes.toString(),
      'cache-secs': '180', // 180s forward cache window
      'demuxer-readahead-secs': '60', // 60s continuous forward readahead
      'cache-pause': 'yes', // Gracefully pause on buffer underrun to keep audio/video in sync
      'cache-pause-wait': '2', // Buffer 2 seconds before resuming, preventing rapid stutter loops
      'cache-pause-initial': 'yes', // Ensure 2s healthy initial buffer before playing frame 0
      'stream-lavf-o':
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5', // Auto-reconnect on cellular/Wi-Fi switches
      'network-timeout':
          '20', // 20s network timeout prevents premature drops
      'demuxer-lavf-probesize': '2097152', // 2MB probe for reliable HLS & multi-track detection
      'demuxer-lavf-buffersize': '2097152', // 2MB socket buffer for smooth throughput
      'demuxer-lavf-analyzeduration': '1.5', // 1.5s analyze duration for accurate timestamps
      'force-seekable': 'yes',
      'hr-seek':
          'default', // Precise seek if in cache, instant keyframe if over network
      'correct-pts': 'yes',
      'vd-lavc-show-all': 'no',
      'vd-lavc-dr': 'no', // Safe rendering on Android
      'vd-lavc-fast': 'yes', // Fast decoding optimizations
      'video-sync': 'audio',
      // hls-bitrate omitted: enables mpv adaptive bitrate (ABR) streaming.
      // Automatically scales up to 1080p on fast Wi-Fi and smoothly adapts without freezing on mobile data.
    };

    final platform = _player.platform as dynamic;
    for (final entry in fastProperties.entries) {
      try {
        platform.setProperty(entry.key, entry.value);
      } catch (_) {}
    }

    // Apply user custom MPV settings
    for (final entry in mpvSettings.entries) {
      if (entry.key == 'vo') continue;
      try {
        platform.setProperty(entry.key, entry.value);
      } catch (_) {}
    }

    videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _attachListeners();

    ref.onDispose(_dispose);

    return PlayerState.initial();
  }

  void _attachListeners() {
    final stream = _player.stream;

    _subs.add(
      stream.position.listen((pos) {
        if (pos > Duration.zero) {
          _startupTimer?.cancel();
          _startupTimer = null;
        }
        final target = _pendingSeekTarget;
        final landed =
            target != null &&
            (pos - target).abs() <= const Duration(seconds: 2);
        if (landed) {
          _pendingSeekTarget = null;
          _seekTimeout?.cancel();
        }
        state = state.copyWith(
          position: pos,
          isSeeking: landed ? false : null,
          isOpening: pos > Duration.zero ? false : null,
        );
      }),
    );

    _subs.add(
      stream.duration.listen((dur) {
        if (dur > Duration.zero) {
          _startupTimer?.cancel();
          _startupTimer = null;
        }
        state = state.copyWith(
          duration: dur,
          isOpening: dur > Duration.zero ? false : null,
        );
      }),
    );

    _subs.add(
      stream.buffer.listen((buf) => state = state.copyWith(buffer: buf)),
    );

    _subs.add(
      stream.buffering.listen(
        (buf) => state = state.copyWith(isBuffering: buf),
      ),
    );

    _subs.add(
      stream.playing.listen((play) {
        if (play) {
          _startupTimer?.cancel();
          _startupTimer = null;
        }
        state = state.copyWith(
          isPlaying: play,
          isOpening: play ? false : null,
        );
      }),
    );

    _subs.add(
      stream.rate.listen((rate) => state = state.copyWith(playbackSpeed: rate)),
    );

    _subs.add(
      stream.subtitle.listen((subs) => state = state.copyWith(subtitle: subs)),
    );

    _subs.add(
      stream.error.listen((error) {
        AppLogger.w('Player stream warning/error: $error');
      }),
    );
  }

  void _dispose() {
    _seekTimeout?.cancel();
    _startupTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
  }

  Future<void> open(
    String url,
    Duration? startAt, {
    Map<String, String>? headers,
    String? mediaId,
    int? episode,
  }) async {
    if (mediaId != null) _activeMediaId = mediaId;
    if (episode != null) _activeEpisode = episode;
    final effectiveHeaders = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      ...?headers,
    };
    if (effectiveHeaders['Referer']?.isNotEmpty != true) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.scheme.startsWith('http')) {
        effectiveHeaders['Referer'] = '${uri.scheme}://${uri.host}/';
      }
    }
    _lastUrl = url;
    _lastHeaders = effectiveHeaders;
    state = state.copyWith(
      isOpening: true,
      clearPlaybackError: true,
      position: Duration.zero,
      duration: Duration.zero,
    );
    _startupTimer?.cancel();
    _startupTimer = Timer(const Duration(seconds: 25), () {
      if (state.isOpening) {
        state = state.copyWith(
          isOpening: false,
          playbackError: 'Video startup timed out. Tap Retry to try again.',
        );
      }
    });
    try {
      final platform = _player.platform as dynamic;
      final ua = effectiveHeaders.entries
              .firstWhereOrNull(
                (entry) => entry.key.toLowerCase() == 'user-agent',
              )
              ?.value ??
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      final ref = effectiveHeaders.entries
              .firstWhereOrNull((entry) => entry.key.toLowerCase() == 'referer')
              ?.value ??
          '';
      await platform.setProperty('user-agent', ua);
      await platform.setProperty('referrer', ref);
      final forwardedHeaders = effectiveHeaders.entries
          .where(
            (entry) =>
                entry.key.toLowerCase() != 'user-agent' &&
                entry.key.toLowerCase() != 'referer',
          )
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(',');
      if (forwardedHeaders.isNotEmpty) {
        await platform.setProperty('http-header-fields', forwardedHeaders);
      }
    } catch (_) {}
    await _player.open(
      Media(url, httpHeaders: effectiveHeaders, start: startAt),
      play: true,
    );
  }

  Future<void> retry() async {
    final url = _lastUrl;
    if (url == null) return;
    await open(url, _player.state.position, headers: _lastHeaders);
  }

  Future<void> togglePlay() async {
    _player.state.playing ? await _player.pause() : await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    _seekTimeout?.cancel();
    _startupTimer?.cancel();
    _pendingSeekTarget = null;
    _lastUrl = null;
    _lastHeaders = null;
    _activeMediaId = null;
    _activeEpisode = null;
    await _player.stop();
    state = PlayerState.initial();
  }

  Future<void> seek(Duration pos) async {
    _pendingSeekTarget = pos;
    state = state.copyWith(position: pos);
    try {
      await _player.seek(pos);
    } catch (e) {
      AppLogger.w('Player seek error: $e');
    }
  }

  void seekRelative(int seconds) {
    final p =
        (_pendingSeekTarget ?? _player.state.position) +
        Duration(seconds: seconds);
    seek(p);
  }

  void forward(int seconds) {
    final p =
        (_pendingSeekTarget ?? _player.state.position) +
        Duration(seconds: seconds);
    seek(p);
  }

  void rewind(int seconds) {
    final p =
        (_pendingSeekTarget ?? _player.state.position) -
        Duration(seconds: seconds);
    seek(p < Duration.zero ? Duration.zero : p);
  }

  Future<void> setSpeed(double speed) => _player.setRate(speed);

  void setFit(BoxFit fit) => state = state.copyWith(fit: fit);

  Future<void> setSubtitle(SubtitleTrack track) =>
      _player.setSubtitleTrack(track);

  void volumeUp() =>
      _player.setVolume((_player.state.volume + 10).clamp(0, 100));

  void volumeDown() =>
      _player.setVolume((_player.state.volume - 10).clamp(0, 100));

  void toggleMute() => _player.setVolume(_player.state.volume == 0 ? 100 : 0);

  Future<void> setSubtitleDelay(double seconds) async {
    try {
      final platform = _player.platform as dynamic;
      await platform.setProperty('sub-delay', seconds.toString());
      state = state.copyWith(subtitleDelay: seconds);
      AppLogger.i('Subtitle delay set to: ${seconds}s');
    } catch (e) {
      AppLogger.e('Failed to set subtitle delay: $e');
    }
  }

  Future<void> adjustSubtitleDelay(double deltaSeconds) async {
    final newDelay = ((state.subtitleDelay + deltaSeconds) * 10).round() / 10.0;
    await setSubtitleDelay(newDelay.clamp(-10.0, 10.0));
  }
}
