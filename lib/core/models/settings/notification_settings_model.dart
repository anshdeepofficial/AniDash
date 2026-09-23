class NotificationSettingsModel {
  const NotificationSettingsModel({
    this.enableNews = true,
    this.enableDubReleases = true,
    this.enableSubReleases = true,
    this.enableContinueWatching = true,
    this.enableDownloads = true,
  });

  final bool enableNews;
  final bool enableDubReleases;
  final bool enableSubReleases;
  final bool enableContinueWatching;
  final bool enableDownloads;

  NotificationSettingsModel copyWith({
    bool? enableNews,
    bool? enableDubReleases,
    bool? enableSubReleases,
    bool? enableContinueWatching,
    bool? enableDownloads,
  }) {
    return NotificationSettingsModel(
      enableNews: enableNews ?? this.enableNews,
      enableDubReleases: enableDubReleases ?? this.enableDubReleases,
      enableSubReleases: enableSubReleases ?? this.enableSubReleases,
      enableContinueWatching:
          enableContinueWatching ?? this.enableContinueWatching,
      enableDownloads: enableDownloads ?? this.enableDownloads,
    );
  }

  Map<String, dynamic> toJson() => {
    'enableNews': enableNews,
    'enableDubReleases': enableDubReleases,
    'enableSubReleases': enableSubReleases,
    'enableContinueWatching': enableContinueWatching,
    'enableDownloads': enableDownloads,
  };

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      enableNews: json['enableNews'] as bool? ?? true,
      enableDubReleases: json['enableDubReleases'] as bool? ?? true,
      enableSubReleases: json['enableSubReleases'] as bool? ?? true,
      enableContinueWatching: json['enableContinueWatching'] as bool? ?? true,
      enableDownloads: json['enableDownloads'] as bool? ?? true,
    );
  }
}
