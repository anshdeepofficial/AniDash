import 'package:ani_dash/core/models/settings/notification_sound_model.dart';

class NotificationSettingsModel {
  final bool enableNews;
  final bool enableEpisodeReleases;
  final bool enableDubReleases;
  final bool enableSubReleases;
  final bool enableContinueWatching;
  final bool enableDownloads;
  final String soundId;

  const NotificationSettingsModel({
    this.enableNews = true,
    this.enableEpisodeReleases = true,
    this.enableDubReleases = true,
    this.enableSubReleases = true,
    this.enableContinueWatching = true,
    this.enableDownloads = true,
    this.soundId = 'anidash_biwa',
  });

  NotificationSoundItem get soundItem {
    return kNotificationSounds.firstWhere(
      (s) => s.id == soundId,
      orElse: () => kNotificationSounds.first,
    );
  }

  NotificationSettingsModel copyWith({
    bool? enableNews,
    bool? enableEpisodeReleases,
    bool? enableDubReleases,
    bool? enableSubReleases,
    bool? enableContinueWatching,
    bool? enableDownloads,
    String? soundId,
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
      soundId: soundId ?? this.soundId,
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
      'soundId': soundId,
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
      soundId: json['soundId'] as String? ?? 'anidash_biwa',
    );
  }
}
