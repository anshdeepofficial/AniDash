import 'dart:async';
import 'package:flutter/services.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class AudioFocusService {
  static final AudioFocusService _instance = AudioFocusService._internal();
  factory AudioFocusService() => _instance;
  AudioFocusService._internal();

  static const MethodChannel _channel = MethodChannel('shonenx/audio_focus');

  bool isPausedByInterruption = false;

  Future<void> Function()? _onPauseRequested;
  Future<void> Function()? _onResumeRequested;
  bool _isInitialized = false;

  void initialize({
    required Future<void> Function() onPauseRequested,
    required Future<void> Function() onResumeRequested,
  }) {
    _onPauseRequested = onPauseRequested;
    _onResumeRequested = onResumeRequested;

    if (!_isInitialized) {
      _isInitialized = true;
      _channel.setMethodCallHandler(_handleMethodCall);
      AppLogger.i('[AudioFocusService] Initialized audio focus handler');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioFocusLossTransient':
        AppLogger.w('[AudioFocusService] Transient focus loss (incoming call / alarm). Pausing video...');
        isPausedByInterruption = true;
        if (_onPauseRequested != null) {
          await _onPauseRequested!();
        }
        break;

      case 'onAudioFocusGain':
        AppLogger.success('[AudioFocusService] Audio focus regained.');
        if (isPausedByInterruption) {
          isPausedByInterruption = false;
          AppLogger.i('[AudioFocusService] Call ended. Auto-resuming video playback...');
          if (_onResumeRequested != null) {
            await _onResumeRequested!();
          }
        }
        break;

      case 'onAudioFocusLoss':
        AppLogger.w('[AudioFocusService] Permanent focus loss. Pausing video...');
        isPausedByInterruption = false;
        if (_onPauseRequested != null) {
          await _onPauseRequested!();
        }
        break;

      default:
        break;
    }
  }

  Future<bool> requestAudioFocus() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestAudioFocus');
      return res ?? false;
    } catch (e) {
      AppLogger.d('[AudioFocusService] requestAudioFocus error: $e');
      return false;
    }
  }

  Future<void> abandonAudioFocus() async {
    try {
      isPausedByInterruption = false;
      await _channel.invokeMethod('abandonAudioFocus');
    } catch (e) {
      AppLogger.d('[AudioFocusService] abandonAudioFocus error: $e');
    }
  }

  void reset() {
    isPausedByInterruption = false;
    _onPauseRequested = null;
    _onResumeRequested = null;
  }
}
