import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:ani_dash/core/utils/app_logger.dart';

final pipProvider = NotifierProvider<PiPNotifier, bool>(
  PiPNotifier.new,
);

class PiPNotifier extends Notifier<bool> {
  static const MethodChannel _androidChannel = MethodChannel('shonenx/pip');

  VideoController? _iosVideoController;
  StreamSubscription<PipEvent>? _iosPipEvents;
  StreamSubscription<int?>? _iosWidthSub;
  StreamSubscription<int?>? _iosHeightSub;
  bool _iosAttachInFlight = false;
  bool _iosAutoArmed = false;

  bool get isPreparedForBackgroundPiP =>
      Platform.isIOS && _iosVideoController != null && _iosAutoArmed;

  @override
  bool build() {
    if (Platform.isAndroid) {
      _androidChannel.setMethodCallHandler(_handleAndroidMethodCall);
      _checkInitialAndroidPiPState();
    }

    ref.onDispose(() {
      if (Platform.isAndroid) {
        _androidChannel.setMethodCallHandler(null);
      }
      unawaited(_disposeIOSBindings());
    });

    return false;
  }

  Future<void> _checkInitialAndroidPiPState() async {
    try {
      final bool? isPiP = await _androidChannel.invokeMethod<bool>('isPiP');
      if (isPiP != null) state = isPiP;
    } catch (_) {}
  }

  Future<dynamic> _handleAndroidMethodCall(MethodCall call) async {
    if (call.method == 'onPiPChanged') {
      final bool inPiP = call.arguments as bool? ?? false;
      AppLogger.i('PiP state changed: $inPiP');
      state = inPiP;
    }
  }

  /// Connects AniDash's existing media_kit video output to the native iOS
  /// sample-buffer PiP pipeline. Android intentionally keeps its existing
  /// Activity-based implementation.
  void attachIOSVideoController(VideoController controller) {
    if (!Platform.isIOS || identical(_iosVideoController, controller)) return;

    unawaited(_disposeIOSBindings(stopPiP: false));
    _iosVideoController = controller;

    _iosPipEvents = controller.pictureInPicture.events.listen(
      _handleIOSPipEvent,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.w('iOS PiP event stream failed: $error');
        state = false;
      },
    );

    _iosWidthSub = controller.player.stream.width.listen((_) {
      unawaited(_armIOSAutoPiP());
    });
    _iosHeightSub = controller.player.stream.height.listen((_) {
      unawaited(_armIOSAutoPiP());
    });

    unawaited(_armIOSAutoPiP());
  }

  Future<void> detachIOSVideoController() async {
    if (!Platform.isIOS) return;
    await _disposeIOSBindings();
  }

  Future<void> _disposeIOSBindings({bool stopPiP = true}) async {
    await _iosPipEvents?.cancel();
    await _iosWidthSub?.cancel();
    await _iosHeightSub?.cancel();
    _iosPipEvents = null;
    _iosWidthSub = null;
    _iosHeightSub = null;

    final controller = _iosVideoController;
    _iosVideoController = null;
    _iosAutoArmed = false;
    _iosAttachInFlight = false;
    state = false;

    if (stopPiP && controller != null) {
      try {
        await controller.pictureInPicture.stop();
      } catch (_) {}
    }
  }

  Future<void> _handleIOSPipEvent(PipEvent event) async {
    final controller = _iosVideoController;

    if (event is PipWillStart || event is PipDidStart) {
      state = true;
      return;
    }

    if (event is PipSetPlaying) {
      if (controller != null) {
        if (event.playing) {
          await controller.player.play();
        } else {
          await controller.player.pause();
        }
      }
      return;
    }

    if (event is PipClosed) {
      state = false;
      if (controller != null) {
        await controller.player.pause();
      }
      return;
    }

    if (event is PipDidStop) {
      state = false;
      _iosAutoArmed = false;
      // Re-arm after returning to AniDash so a later Home gesture can enter
      // PiP again without reconstructing the player.
      Future<void>.delayed(
        const Duration(milliseconds: 350),
        _armIOSAutoPiP,
      );
      return;
    }

    if (event is PipFailed) {
      AppLogger.w('iOS PiP failed: ${event.reason}');
      state = false;
    }
  }

  Future<bool> _armIOSAutoPiP({bool startImmediately = false}) async {
    if (!Platform.isIOS || _iosAttachInFlight) return false;
    final controller = _iosVideoController;
    if (controller == null) return false;

    final width = controller.player.state.width ?? 0;
    final height = controller.player.state.height ?? 0;
    if (width <= 0 || height <= 0) return false;

    if (!startImmediately && _iosAutoArmed) return true;

    _iosAttachInFlight = true;
    try {
      final supported = await controller.pictureInPicture.isSupported();
      if (!supported) return false;

      await controller.pictureInPicture.start(
        handle: await controller.player.handle,
        videoSize: Size(width.toDouble(), height.toDouble()),
        autoEnter: true,
        startImmediately: startImmediately,
      );
      _iosAutoArmed = true;
      return true;
    } catch (e, st) {
      AppLogger.e('Failed to attach iOS PiP', e, st);
      _iosAutoArmed = false;
      return false;
    } finally {
      _iosAttachInFlight = false;
    }
  }

  Future<bool> isSupported() async {
    if (Platform.isAndroid) return true;
    if (!Platform.isIOS) return false;
    final controller = _iosVideoController;
    if (controller == null) return false;
    try {
      return await controller.pictureInPicture.isSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> enterPiP() async {
    if (Platform.isAndroid) {
      try {
        final res = await _androidChannel.invokeMethod<bool>('enterPiP');
        return res ?? false;
      } catch (e) {
        AppLogger.e('Failed to enter Android PiP: $e');
        return false;
      }
    }

    if (Platform.isIOS) {
      return _armIOSAutoPiP(startImmediately: true);
    }

    return false;
  }

  Future<bool> exitPiP() async {
    if (Platform.isAndroid) {
      try {
        final res = await _androidChannel.invokeMethod<bool>('exitPiP');
        return res ?? false;
      } catch (e) {
        AppLogger.e('Failed to exit Android PiP: $e');
        return false;
      }
    }

    if (Platform.isIOS) {
      final controller = _iosVideoController;
      if (controller == null) return false;
      try {
        await controller.pictureInPicture.stop();
        state = false;
        _iosAutoArmed = false;
        return true;
      } catch (e) {
        AppLogger.e('Failed to exit iOS PiP: $e');
        return false;
      }
    }

    return false;
  }

  Future<bool> closePiP() async {
    if (Platform.isAndroid) {
      try {
        final res = await _androidChannel.invokeMethod<bool>('closePiP');
        return res ?? false;
      } catch (e) {
        AppLogger.e('Failed to close Android PiP: $e');
        return false;
      }
    }

    if (Platform.isIOS) {
      final controller = _iosVideoController;
      if (controller == null) return false;
      try {
        await controller.pictureInPicture.stop();
        await controller.player.pause();
        state = false;
        _iosAutoArmed = false;
        return true;
      } catch (e) {
        AppLogger.e('Failed to close iOS PiP: $e');
        return false;
      }
    }

    return false;
  }

  void setPiPMode(bool value) {
    state = value;
  }
}
