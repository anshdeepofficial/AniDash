import 'dart:io';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class UIHelper {
  static const _orientationChannel = MethodChannel('shonenx/orientation');
  static const _volumeChannel = MethodChannel('shonenx/volume');
  static bool _isFullscreen = false;
  static bool get _isDesktop => !Platform.isAndroid && !Platform.isIOS;

  /// Enable intercepting physical volume buttons to suppress system UI
  static Future<void> enableVolumeInterception() async {
    if (Platform.isAndroid) {
      try {
        await _volumeChannel.invokeMethod('enableIntercept');
      } catch (_) {}
    }
  }

  /// Disable intercepting physical volume buttons
  static Future<void> disableVolumeInterception() async {
    if (Platform.isAndroid) {
      try {
        await _volumeChannel.invokeMethod('disableIntercept');
      } catch (_) {}
    }
  }

  /// Set handler for hardware volume buttons
  static void setVolumeKeyHandler({
    required VoidCallback onVolumeUp,
    required VoidCallback onVolumeDown,
  }) {
    if (Platform.isAndroid) {
      _volumeChannel.setMethodCallHandler((call) async {
        if (call.method == 'volumeUp') {
          onVolumeUp();
        } else if (call.method == 'volumeDown') {
          onVolumeDown();
        }
      });
    }
  }

  /// Clear handler for hardware volume buttons
  static void removeVolumeKeyHandler() {
    if (Platform.isAndroid) {
      _volumeChannel.setMethodCallHandler(null);
    }
  }

  /// Toggle fullscreen mode (cross-platform)
  static Future<void> handleToggleFullscreen({
    VoidCallback? beforeCallback,
    VoidCallback? afterCallback,
  }) async {
    if (beforeCallback != null) beforeCallback();

    if (_isFullscreen) {
      _isDesktop
          ? await windowManager.setFullScreen(false)
          : await exitImmersiveMode();
      _isFullscreen = false;
    } else {
      _isDesktop
          ? await windowManager.setFullScreen(true)
          : await enableImmersiveMode();
      _isFullscreen = true;
    }

    if (afterCallback != null) afterCallback();
  }

  static DeviceOrientation _currentLandscape = DeviceOrientation.landscapeLeft;

  /// Force landscape orientation (mobile only)
  static Future<void> forceLandscape() async {
    if (Platform.isAndroid) {
      try {
        await _orientationChannel.invokeMethod('sensorLandscape');
      } on PlatformException {
        // Fall through
      }
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// Toggle / flip between landscape orientations
  static Future<void> toggleLandscape() async {
    if (Platform.isAndroid) {
      try {
        await _orientationChannel.invokeMethod('toggleLandscape');
      } catch (_) {}
    }

    if (_currentLandscape == DeviceOrientation.landscapeLeft) {
      _currentLandscape = DeviceOrientation.landscapeRight;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _currentLandscape = DeviceOrientation.landscapeLeft;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
    }

    // Allow sensor to freely follow both landscape sides after toggle
    Future.delayed(const Duration(milliseconds: 600), () {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  /// Force portrait orientation (mobile only)
  static Future<void> forcePortrait() async {
    if (Platform.isAndroid) {
      try {
        await _orientationChannel.invokeMethod('portrait');
      } on PlatformException {
        // Fall through to Flutter's orientation API.
      }
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else if (Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// Enable auto-rotate (allow all orientations)
  static Future<void> enableAutoRotate() async {
    if (!_isDesktop) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// Reset orientation to allow all (alias for enableAutoRotate)
  static Future<void> resetOrientation() => enableAutoRotate();

  /// Enable immersive mode (hide system UI)
  static Future<void> enableImmersiveMode() async {
    if (!_isDesktop) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _isFullscreen = true;
    }
  }

  /// Exit immersive mode (show system UI)
  static Future<void> exitImmersiveMode() async {
    if (!_isDesktop) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _isFullscreen = false;
    }
  }

  /// Hide only status bar
  static Future<void> hideStatusBarOnly() async {
    if (!_isDesktop) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom],
      );
      _isFullscreen = true;
    }
  }

  /// Hide only navigation bar
  static Future<void> hideNavigationBarOnly() async {
    if (!_isDesktop) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
      _isFullscreen = true;
    }
  }

  /// Show all system overlays
  static Future<void> showAllOverlays() async {
    if (!_isDesktop) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      _isFullscreen = true;
    }
  }
}
