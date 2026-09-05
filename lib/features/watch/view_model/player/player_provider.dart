import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';

part 'player_provider.g.dart';

@immutable
class PlayerState {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool isPlaying;
  final bool isBuffering;
  final bool isSeeking;
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
  int _recoveryAttempts = 0;
  bool _isRecovering = false;
  Duration? _pendingSeekTarget;
  Timer? _seekTimeout;

  Player get player => _player;

  @override
  PlayerState build() {
    final settings = ref.read(playerSettingsProvider);
    final mpvSettings = settings.mpvSettings;
    final vo = mpvSettings['vo'];
    final bufferSize = ref.read(
      playerSettingsProvider.select((s) => s.bufferSize),
    );
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize.toInt() * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
        vo: vo,
      ),
    );

    // Apply optimized fast-seeking and stream cache defaults
    final fastProperties = <String, String>{
      'cache': 'yes',
      'cache-pause': 'yes',
      'cache-pause-wait': '1',
      'demuxer-lavf-o':
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
      'demuxer-max-bytes':
          '${(bufferSize.toInt() * 1024 * 1024).clamp(32 * 1024 * 1024, 128 * 1024 * 1024)}',
      'demuxer-readahead-secs': '10',
      'hr-seek': 'default',
      'hr-seek-framedrop': 'yes',
      'force-seekable': 'yes',
      'network-timeout': '10',
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
      configuration: VideoControllerConfiguration(
        androidAttachSurfaceAfterVideoParameters:
            Platform.isAndroid ? true : null,
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
        if (_player.state.duration > Duration.zero) {
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
          );
          if (_recoveryAttempts > 0 && pos.inSeconds % 30 == 0) {
            _recoveryAttempts = 0;
          }
        }
      }),
    );

    _subs.add(
      stream.duration.listen((dur) => state = state.copyWith(duration: dur)),
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
      stream.playing.listen((play) => state = state.copyWith(isPlaying: play)),
    );

    _subs.add(
      stream.rate.listen((rate) => state = state.copyWith(playbackSpeed: rate)),
    );

    _subs.add(
      stream.subtitle.listen((subs) => state = state.copyWith(subtitle: subs)),
    );

    _subs.add(stream.error.listen((_) => _recoverPlayback()));
  }

  Future<void> _recoverPlayback() async {
    final url = _lastUrl;
    if (url == null || _isRecovering || _recoveryAttempts >= 2) return;
    _isRecovering = true;
    _recoveryAttempts++;
    final resumeAt = _player.state.position;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _player.open(
        Media(url, httpHeaders: _lastHeaders, start: resumeAt),
        play: true,
      );
      if (resumeAt > Duration.zero) await _player.seek(resumeAt);
    } catch (_) {
      // A second fatal error may retry once more through the error stream.
    } finally {
      _isRecovering = false;
    }
  }

  void _dispose() {
    _seekTimeout?.cancel();
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
    _recoveryAttempts = 0;
    try {
      final platform = _player.platform as dynamic;
      await platform.setProperty('user-agent', effectiveHeaders['User-Agent']!);
      await platform.setProperty('referrer', effectiveHeaders['Referer'] ?? '');
    } catch (_) {}
    await _player.open(
      Media(url, httpHeaders: effectiveHeaders, start: startAt),
      play: true,
    );

    if (startAt == null || startAt == Duration.zero) return;

    try {
      if (_player.state.duration == Duration.zero) {
        await _player.stream.duration
            .firstWhere((duration) => duration > Duration.zero)
            .timeout(const Duration(seconds: 10));
      }
      if ((_player.state.position - startAt).inSeconds.abs() > 3) {
        await _player.seek(startAt);
      }
    } catch (_) {
      await _player.seek(startAt);
    }
  }

  Future<void> togglePlay() async {
    _player.state.playing ? await _player.pause() : await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> seek(Duration pos) async {
    final needsNetwork = pos > state.buffer + const Duration(seconds: 1);
    if (needsNetwork) {
      _pendingSeekTarget = pos;
      state = state.copyWith(isSeeking: true);
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
