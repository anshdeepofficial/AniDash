import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ani_dash/core/network/http_client.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}

class UpdateService {
  final UniversalHttpClient _httpClient = UniversalHttpClient.instance;

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('https://api.github.com/repos/anshdeepofficial/AniDash/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String;
        final releaseNotes = data['body'] as String;
        final publishedAt = DateTime.parse(data['published_at']);
        
        final assets = data['assets'] as List;
        if (assets.isEmpty) return null;
        
        final apkAsset = assets.firstWhere(
          (asset) => asset['name'].toString().endsWith('.apk'),
          orElse: () => assets[0],
        );
        final downloadUrl = apkAsset['browser_download_url'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        final cleanTagName = tagName.replaceAll('v', '');
        
        if (_isNewerVersion(currentVersion, cleanTagName)) {
          return UpdateInfo(
            version: cleanTagName,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            publishedAt: publishedAt,
          );
        }
      }
    } catch (e) {
      AppLogger.e('Error checking for update: $e');
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  Future<void> downloadAndInstallUpdate(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/update.apk';
      
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        
        final packageInfo = await PackageInfo.fromPlatform();
        await InstallPlugin.install(savePath);
      }
    } catch (e) {
      AppLogger.e('Error downloading/installing update: $e');
    }
  }
}
