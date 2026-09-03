import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class VideoSnifferService {
  static Future<String?> extractVideoUrl(String pageUrl) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;
    
    AppLogger.i('Starting headless webview sniffer for: $pageUrl');

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
      onLoadResource: (controller, resource) {
        final url = resource.url.toString();
        // Check for common streaming playlist or video formats
        if (url.contains('.m3u8') || url.contains('.mp4')) {
          AppLogger.i('Video stream found: $url');
          if (!completer.isCompleted) {
            completer.complete(url);
          }
        }
      },
      onLoadStop: (controller, url) async {
        // Wait a few seconds for any delayed JS streams to load
        await Future.delayed(const Duration(seconds: 8));
        if (!completer.isCompleted) {
          AppLogger.warning('No video stream found within timeout.');
          completer.complete(null);
        }
      },
    );

    try {
      await headlessWebView.run();
    } catch (e) {
      AppLogger.e('Failed to run headless webview: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    final result = await completer.future;
    try {
      await headlessWebView.dispose();
    } catch (e) {
      // Ignore dispose errors
    }
    
    return result;
  }
}
