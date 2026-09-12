import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

final pipProvider = NotifierProvider<PiPNotifier, bool>(
  PiPNotifier.new,
);

class PiPNotifier extends Notifier<bool> {
  static const MethodChannel _channel = MethodChannel('shonenx/pip');

  @override
  bool build() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleMethodCall);
      _checkInitialPiPState();
    }
    return false;
  }

  Future<void> _checkInitialPiPState() async {
    try {
      final bool? isPiP = await _channel.invokeMethod<bool>('isPiP');
      if (isPiP != null) {
        state = isPiP;
      }
    } catch (_) {}
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPiPChanged') {
      final bool inPiP = call.arguments as bool? ?? false;
      AppLogger.i('PiP state changed: $inPiP');
      state = inPiP;
    }
  }

  Future<bool> enterPiP() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('enterPiP');
      return res ?? false;
    } catch (e) {
      AppLogger.e('Failed to enter PiP: $e');
      return false;
    }
  }

  Future<bool> exitPiP() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('exitPiP');
      return res ?? false;
    } catch (e) {
      AppLogger.e('Failed to exit PiP: $e');
      return false;
    }
  }

  Future<bool> closePiP() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('closePiP');
      return res ?? false;
    } catch (e) {
      AppLogger.e('Failed to close PiP: $e');
      return false;
    }
  }

  void setPiPMode(bool value) {
    state = value;
  }
}
