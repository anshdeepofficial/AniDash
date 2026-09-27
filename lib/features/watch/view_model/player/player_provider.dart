import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/utils/stream_headers.dart';

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
  Timer? _stallWatchdog;
  Duration _stallWatchdogLastPos = Duration.zero;
  String? _activeMediaId;
  int? _activeEpisode;
  Duration _lastStablePosition = Duration.zero;
  bool _isStallRecovering = false;

  Player get player => _player;
  String? get activeMediaId => _activeMediaId;
  int? get activeEpisode => _activeEpisode;
  Duration get lastStablePosition => _lastStablePosition;

  void setActiveSession(String? mediaId, int? episode) {
    if (_activeMediaId != mediaId || _activeEpisode != episode) {
      _lastStablePosition = Duration.zero;
    }
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

    // Rock-solid v1.15.6 buffer config — restored after v1.15.7 regression.
    // cache-pause + cache-pause-wait prevent the 1-2s play→stall→play loop:
    // MPV pauses itself on buffer underrun, waits for 2s of data, then resumes cleanly.
    final fastProperties = <String, String>{
      'hwdec': 'auto-safe',

      // ── Cache / buffer sizing ─────────────────────────────────────────────
      'cache': 'yes',
      'cache-secs': '180',              // 3-minute forward cache window
      'demuxer-seekable-cache': 'yes',
      'demuxer-max-bytes': effectiveBufferBytes.toString(),
      'demuxer-max-back-bytes': backBufferBytes.toString(),
      'demuxer-readahead-secs': '60',   // 60s continuous forward readahead

      // ── Critical: pause-on-underrun safeguards ────────────────────────────
      'cache-pause': 'yes',             // Pause when buffer runs dry (prevents rapid stutter)
      'cache-pause-wait': '2',          // Buffer ≥2s before resuming
      'cache-pause-initial': 'yes',     // Ensure healthy initial buffer before first frame

      // ── Network ───────────────────────────────────────────────────────────
      'stream-lavf-o':
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
      'network-timeout': '20',          // 20s prevents premature CDN drops

      // ── FFmpeg demuxer / HLS probe ────────────────────────────────────────
      'demuxer-lavf-probesize': '2097152',       // 2MB probe for reliable HLS & multi-track
      'demuxer-lavf-buffersize': '2097152',      // 2MB socket read buffer for smooth throughput
      'demuxer-lavf-analyzeduration': '1.5',     // 1.5s for accurate timestamp detection

      // ── Seeking & sync ────────────────────────────────────────────────────
      'force-seekable': 'yes',
      'hr-seek': 'default',             // Precise seek if in cache, keyframe if over network
      'hr-seek-framedrop': 'yes',
      'correct-pts': 'yes',
      'video-sync': 'audio',            // Audio-locked sync; prevents A/V drift on slow segments
      'vd-lavc-fast': 'yes',
      'video-sync': 'audio',
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
          _lastStablePosition = pos;
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
      stream.buffering.listen((buf) {
        state = state.copyWith(isBuffering: buf);
        if (buf) {
          // Start stall watchdog: if we're still buffering after 8s
          // and position hasn't advanced, the stream is truly stalled.
          _stallWatchdogLastPos = _player.state.position;
          _stallWatchdog ??= Timer(const Duration(seconds: 8), () {
            _stallWatchdog = null;
            if (!state.isBuffering) return; // recovered on its own
            if (_isStallRecovering) return;  // already recovering
            final currentPos = _player.state.position;
            // Only fire if position genuinely hasn't advanced (not just slow seeking)
            final posAdvanced = (currentPos - _stallWatchdogLastPos).abs() >
                const Duration(milliseconds: 500);
            if (!posAdvanced && state.isBuffering) {
              AppLogger.w(
                'Stall watchdog fired: buffering >8s, pos unchanged. '
                'Notifying for alternate stream recovery at ${currentPos.inSeconds}s',
              );
              _isStallRecovering = true;
              _onStall?.call(currentPos);
            }
          });
        } else {
          // Buffer recovered — cancel watchdog
          _stallWatchdog?.cancel();
          _stallWatchdog = null;
          _isStallRecovering = false;
        }
      }),
    );

    _subs.add(
      stream.playing.listen((play) {
        if (play) {
          _startupTimer?.cancel();
          _startupTimer = null;
          // Clear stall state when playback actually resumes
          _stallWatchdog?.cancel();
          _stallWatchdog = null;
          _isStallRecovering = false;
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

  // Callback set by episode_stream_provider to receive stall notifications
  void Function(Duration position)? _onStall;

  void setStallCallback(void Function(Duration position)? callback) {
    _onStall = callback;
  }

  void _dispose() {
    _seekTimeout?.cancel();
    _startupTimer?.cancel();
    _stallWatchdog?.cancel();
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
    final isSameSession = (mediaId != null &&
            episode != null &&
            mediaId == _activeMediaId &&
            episode == _activeEpisode) ||
        (mediaId == null && episode == null && _activeMediaId != null);

    // If startAt is explicitly provided, use it. Otherwise, if reopening the same media & episode,
    // preserve the last stable playback position so we don't restart from beginning on stream recovery/reload.
    final effectiveStartAt = (startAt != null && startAt > Duration.zero)
        ? startAt
        : (isSameSession && _lastStablePosition > Duration.zero
            ? _lastStablePosition
            : null);

    if (mediaId != null) _activeMediaId = mediaId;
    if (episode != null) _activeEpisode = episode;
    if (!isSameSession && effectiveStartAt != null) {
      _lastStablePosition = effectiveStartAt;
    }

    final effectiveHeaders = normalizeStreamHeaders(url, headers);
    _lastUrl = url;
    _lastHeaders = effectiveHeaders;
    state = state.copyWith(
      isOpening: true,
      clearPlaybackError: true,
      position: effectiveStartAt ?? (isSameSession ? _lastStablePosition : Duration.zero),
      duration: isSameSession ? state.duration : Duration.zero,
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
      // ── Step 1: UA and Referer via MPV dedicated properties ───────────────
      final ua = effectiveHeaders.entries
              .firstWhereOrNull(
                (entry) => entry.key.toLowerCase() == 'user-agent',
              )
              ?.value ??
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      final refValue = effectiveHeaders.entries
              .firstWhereOrNull((entry) => entry.key.toLowerCase() == 'referer')
              ?.value ??
          '';
      await platform.setProperty('user-agent', ua);
      if (refValue.isNotEmpty) {
        await platform.setProperty('referrer', refValue);
      }

      // ── Step 2: http-header-fields WITHOUT UA / Referer / Origin ─────────
      // Sending these in http-header-fields on top of the dedicated properties
      // causes duplicate headers that break HLS auth on many CDNs.
      const dedicatedHeaders = {'user-agent', 'referer', 'origin'};
      final forwardedHeaders = effectiveHeaders.entries
          .where((e) => !dedicatedHeaders.contains(e.key.toLowerCase()))
          .map((e) => '${e.key}: ${e.value}')
          .join(',');
      if (forwardedHeaders.isNotEmpty) {
        await platform.setProperty('http-header-fields', forwardedHeaders);
      }

      // ── Step 3: Adaptive speed probe — tune MPV for network conditions ───
      // We fetch 8 KB from the stream URL and time it — on fast WiFi/5G this
      // completes in <50ms (invisible to user). On slow 2G/3G it takes ~500ms
      // but gives us reliable data to choose the right buffering profile.
      // Retries to the same URL skip the probe and reuse the last measurement.
      try {
        final isRetry = url == _lastUrl && _lastSpeedKbps > 0;
        final speedKbps = isRetry
            ? _lastSpeedKbps
            : await _measureSpeedKbps(
                url,
                effectiveHeaders,
                sampleBytes: 8 * 1024,  // 8 KB — <50ms on fast, ~500ms on slow
                timeoutMs: 2000,        // 2s cap to never slow down fast users
              );
        if (!isRetry) _lastSpeedKbps = speedKbps;
        AppLogger.d('Speed probe: ${speedKbps.round()} KB/s${isRetry ? ' (cached)' : ''}');

        if (speedKbps >= 500) {
          // ── Fast (WiFi / 5G): play instantly, tiny probe, no initial pause ─
          await platform.setProperty('cache-pause-initial', 'no');
          await platform.setProperty('cache-pause-wait', '1');
          await platform.setProperty('demuxer-lavf-probesize', '524288');   // 512 KB
          await platform.setProperty('demuxer-lavf-analyzeduration', '0.5');// 0.5s
          await platform.setProperty('demuxer-readahead-secs', '60');
          await platform.setProperty('network-timeout', '15');
        } else if (speedKbps >= 150) {
          // ── Medium (4G / good 3G): 2s initial buffer, 1MB probe ───────────
          await platform.setProperty('cache-pause-initial', 'yes');
          await platform.setProperty('cache-pause-wait', '2');
          await platform.setProperty('demuxer-lavf-probesize', '1048576');  // 1 MB
          await platform.setProperty('demuxer-lavf-analyzeduration', '1.0');
          await platform.setProperty('demuxer-readahead-secs', '60');
          await platform.setProperty('network-timeout', '20');
        } else {
          // ── Slow (2G / weak 3G): 4s initial buffer, 2MB probe, 90s window ─
          await platform.setProperty('cache-pause-initial', 'yes');
          await platform.setProperty('cache-pause-wait', '4');
          await platform.setProperty('demuxer-lavf-probesize', '2097152');  // 2 MB
          await platform.setProperty('demuxer-lavf-analyzeduration', '2.0');
          await platform.setProperty('demuxer-readahead-secs', '90');
          await platform.setProperty('network-timeout', '30');
          await platform.setProperty('cache-secs', '240'); // 4-minute window on slow
        }
      } catch (_) {
        // Probe failed — safe defaults from build() remain in effect
      }
    } catch (_) {}
    await _player.open(
      Media(url, httpHeaders: effectiveHeaders, start: effectiveStartAt),
      play: true,
    );
  }

  /// Quick download speed probe — fetches [sampleBytes] from [url] and returns
  /// approximate throughput in KB/s. Never throws; returns 0.0 on any error.
  Future<double> _measureSpeedKbps(
    String url,
    Map<String, String> headers, {
    required int sampleBytes,
    required int timeoutMs,
  }) async {
    try {
      final uri = Uri.parse(url);
      // Only probe HTTP(S) streams — skip local files / rtmp / etc.
      if (!uri.scheme.startsWith('http')) return 9999.0; // assume fast

      // Use Dart's HttpClient for a raw byte count without Flutter overhead
      final httpClient = HttpClient()
        ..connectionTimeout = Duration(milliseconds: timeoutMs)
        ..idleTimeout = Duration(milliseconds: timeoutMs);
      final request = await httpClient.getUrl(uri).timeout(
        Duration(milliseconds: timeoutMs),
      );
      headers.forEach((k, v) => request.headers.set(k, v));
      request.headers.set('Range', 'bytes=0-${sampleBytes - 1}');

      final sw = Stopwatch()..start();
      final response = await request.close().timeout(
        Duration(milliseconds: timeoutMs),
      );

      int received = 0;
      await for (final chunk in response.timeout(
        Duration(milliseconds: timeoutMs),
      )) {
        received += chunk.length;
        if (received >= sampleBytes) break;
      }
      sw.stop();
      httpClient.close(force: true);

      if (sw.elapsedMilliseconds <= 0 || received <= 0) return 0.0;
      return received / sw.elapsedMilliseconds; // bytes/ms = KB/s
    } catch (_) {
      return 0.0; // on failure treat as slow (conservative)
    }
  }

  double _lastSpeedKbps = 0.0;

  Future<void> retry() async {
    final url = _lastUrl;
    if (url == null) return;
    final currentPos = _player.state.position;
    final pos = currentPos > Duration.zero
        ? currentPos
        : (_lastStablePosition > Duration.zero ? _lastStablePosition : null);
    await open(
      url,
      pos,
      headers: _lastHeaders,
      mediaId: _activeMediaId,
      episode: _activeEpisode,
    );
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
    _lastStablePosition = Duration.zero;
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
