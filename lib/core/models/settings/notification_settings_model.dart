class NotificationSettingsModel {
  final bool enableNews;
  final bool enableEpisodeReleases;
  final bool enableDubReleases;
  final bool enableSubReleases;
  final bool enableContinueWatching;
  final bool enableDownloads;

  const NotificationSettingsModel({
    this.enableNews = true,
    this.enableEpisodeReleases = true,
    this.enableDubReleases = true,
    this.enableSubReleases = true,
    this.enableContinueWatching = true,
    this.enableDownloads = true,
  });

  NotificationSettingsModel copyWith({
    bool? enableNews,
    bool? enableEpisodeReleases,
    bool? enableDubReleases,
    bool? enableSubReleases,
    bool? enableContinueWatching,
    bool? enableDownloads,
  }) {
    return NotificationSettingsModel(
      enableNews: enableNews ?? this.enableNews,
      enableEpisodeReleases:
          enableEpisodeReleases ?? this.enableEpisodeReleases,
      enableDubReleases: enableDubReleases ?? this.enableDubReleases,
      enableSubReleases: enableSubReleases ?? this.enableSubReleases,
      enableContinueWatching:
          enableContinueWatching ?? this.enableContinueWatching,
      enableDownloads: enableDownloads ?? this.enableDownloads,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableNews': enableNews,
      'enableEpisodeReleases': enableEpisodeReleases,
      'enableDubReleases': enableDubReleases,
      'enableSubReleases': enableSubReleases,
      'enableContinueWatching': enableContinueWatching,
      'enableDownloads': enableDownloads,
    };
  }

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      enableNews: json['enableNews'] as bool? ?? true,
      enableEpisodeReleases: json['enableEpisodeReleases'] as bool? ?? true,
      enableDubReleases: json['enableDubReleases'] as bool? ?? true,
      enableSubReleases: json['enableSubReleases'] as bool? ?? true,
      enableContinueWatching: json['enableContinueWatching'] as bool? ?? true,
      enableDownloads: json['enableDownloads'] as bool? ?? true,
    );
  }
}
