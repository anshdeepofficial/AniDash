import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    );
  }
}

@riverpod
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late final Player _player;
  late final VideoController videoController;
  final List<StreamSubscription> _subs = [];
  String? _lastUrl;
  Map<String, String>? _lastHeaders;
  Duration? _pendingSeekTarget;
  Timer? _seekTimeout;
  Timer? _startupTimer;

  Player get player => _player;

  @override
  PlayerState build() {
    final settings = ref.read(playerSettingsProvider);
    final mpvSettings = settings.mpvSettings;
    final vo = mpvSettings['vo'];
    final bufferSize = ref.read(
      playerSettingsProvider.select((s) => s.bufferSize),
    );
    final effectiveBufferBytes = (bufferSize.toInt() * 1024 * 1024).clamp(
      128 * 1024 * 1024,
      256 * 1024 * 1024,
    );
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: effectiveBufferBytes,
        logLevel: MPVLogLevel.warn,
        vo: vo,
      ),
    );

    // Apply ultra-fast stream cache defaults with ~100 seconds forward buffer preservation
    final fastProperties = <String, String>{
      'hwdec': 'auto-safe',
      'cache': 'yes',
      'demuxer-seekable-cache': 'yes',
      'demuxer-max-bytes': '104857600',
      'demuxer-max-back-bytes': '33554432',
      'cache-secs': '120',
      'demuxer-readahead-secs': '100',
      'cache-pause': 'yes',
      'cache-pause-wait': '2',
      'demuxer-lavf-hacks': 'yes',
      'network-timeout': '20',
      'force-seekable': 'yes',
      'hr-seek': 'yes',
      'hr-seek-framedrop': 'no',
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
  }) async {
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
      await platform.setProperty('user-agent', effectiveHeaders['User-Agent']!);
      await platform.setProperty('referrer', effectiveHeaders['Referer'] ?? '');
      final forwardedHeaders = effectiveHeaders.entries
          .where((entry) => entry.key.toLowerCase() != 'user-agent')
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(',');
      await platform.setProperty('http-header-fields', forwardedHeaders);
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
    await _player.stop();
    state = PlayerState.initial();
  }

  Future<void> seek(Duration pos) async {
    final needsNetwork = pos > state.buffer + const Duration(seconds: 1);
    _pendingSeekTarget = pos;
    state = state.copyWith(
      position: pos,
      isSeeking: needsNetwork,
    );
    if (needsNetwork) {
      _seekTimeout?.cancel();
      _seekTimeout = Timer(const Duration(seconds: 8), () {
        _pendingSeekTarget = null;
        state = state.copyWith(isSeeking: false);
      });
    }
    try {
      await _player.seek(pos);
    } finally {
      if (!needsNetwork) state = state.copyWith(isSeeking: false);
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
}
