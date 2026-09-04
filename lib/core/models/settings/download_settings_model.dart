import 'dart:convert';

class DownloadSettingsModel {
  final String? customDownloadPath;
  final bool useCustomPath;
  final String folderStructure;
  final int parallelDownloads;
  final int speedLimitKBps;
  final bool wifiOnly;
  final bool rememberDownloadPreferences;
  final String preferredLanguage; // 'sub', 'dub', 'hindi'
  final String preferredQuality;  // '1080p', '720p', '480p', '360p'

  DownloadSettingsModel({
    this.customDownloadPath,
    this.useCustomPath = false,
    this.folderStructure = 'Anime/Episode',
    this.parallelDownloads = 5,
    this.speedLimitKBps = 0,
    this.wifiOnly = false,
    this.rememberDownloadPreferences = false,
    this.preferredLanguage = 'dub',
    this.preferredQuality = '1080p',
  });

  DownloadSettingsModel copyWith({
    String? customDownloadPath,
    bool? useCustomPath,
    String? folderStructure,
    int? parallelDownloads,
    int? speedLimitKBps,
    bool? wifiOnly,
    bool? rememberDownloadPreferences,
    String? preferredLanguage,
    String? preferredQuality,
  }) {
    return DownloadSettingsModel(
      customDownloadPath: customDownloadPath ?? this.customDownloadPath,
      useCustomPath: useCustomPath ?? this.useCustomPath,
      folderStructure: folderStructure ?? this.folderStructure,
      parallelDownloads: parallelDownloads ?? this.parallelDownloads,
      speedLimitKBps: speedLimitKBps ?? this.speedLimitKBps,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      rememberDownloadPreferences:
          rememberDownloadPreferences ?? this.rememberDownloadPreferences,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredQuality: preferredQuality ?? this.preferredQuality,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customDownloadPath': customDownloadPath,
      'useCustomPath': useCustomPath,
      'folderStructure': folderStructure,
      'parallelDownloads': parallelDownloads,
      'speedLimitKBps': speedLimitKBps,
      'wifiOnly': wifiOnly,
      'rememberDownloadPreferences': rememberDownloadPreferences,
      'preferredLanguage': preferredLanguage,
      'preferredQuality': preferredQuality,
    };
  }

  factory DownloadSettingsModel.fromMap(Map<String, dynamic> map) {
    return DownloadSettingsModel(
      customDownloadPath: map['customDownloadPath'],
      useCustomPath: map['useCustomPath'] ?? false,
      folderStructure: map['folderStructure'] ?? 'Anime/Episode',
      parallelDownloads: map['parallelDownloads']?.toInt() ?? 5,
      speedLimitKBps: map['speedLimitKBps']?.toInt() ?? 0,
      wifiOnly: map['wifiOnly'] ?? false,
      rememberDownloadPreferences:
          map['rememberDownloadPreferences'] ?? false,
      preferredLanguage: map['preferredLanguage'] ?? 'dub',
      preferredQuality: map['preferredQuality'] ?? '1080p',
    );
  }

  String toJson() => json.encode(toMap());

  factory DownloadSettingsModel.fromJson(String source) =>
      DownloadSettingsModel.fromMap(json.decode(source));
}
