import 'dart:convert';

class PlayerModel {
  final String defaultQuality;
  final bool enableAniSkip;
  final bool enableAutoSkip;
  final bool preferDub;
  final int seekDuration;
  final int autoHideDuration;
  final int lockAutoHideDuration;
  final bool showNextPrevButtons;
  final bool prefetchNextEpisode;
  final bool showNextEpisodePrompt;
  final double bufferSize;
  final Map<String, String> mpvSettings;

  PlayerModel({
    this.defaultQuality = 'Auto',
    this.enableAniSkip = true,
    this.enableAutoSkip = false,
    this.preferDub = true,
    this.bufferSize = 32,
    this.seekDuration = 10,
    this.autoHideDuration = 5,
    this.lockAutoHideDuration = 3,
    this.showNextPrevButtons = true,
    this.prefetchNextEpisode = true,
    this.showNextEpisodePrompt = true,
    this.mpvSettings = const {},
  });

  PlayerModel copyWith({
    String? defaultQuality,
    bool? enableAniSkip,
    bool? enableAutoSkip,
    bool? preferDub,
    int? seekDuration,
    int? autoHideDuration,
    int? lockAutoHideDuration,
    double? bufferSize,
    bool? showNextPrevButtons,
    bool? prefetchNextEpisode,
    bool? showNextEpisodePrompt,
    Map<String, String>? mpvSettings,
  }) {
    return PlayerModel(
      defaultQuality: defaultQuality ?? this.defaultQuality,
      enableAniSkip: enableAniSkip ?? this.enableAniSkip,
      enableAutoSkip: enableAutoSkip ?? this.enableAutoSkip,
      preferDub: preferDub ?? this.preferDub,
      seekDuration: seekDuration ?? this.seekDuration,
      autoHideDuration: autoHideDuration ?? this.autoHideDuration,
      lockAutoHideDuration: lockAutoHideDuration ?? this.lockAutoHideDuration,
      bufferSize: bufferSize ?? this.bufferSize,
      showNextPrevButtons: showNextPrevButtons ?? this.showNextPrevButtons,
      prefetchNextEpisode: prefetchNextEpisode ?? this.prefetchNextEpisode,
      showNextEpisodePrompt:
          showNextEpisodePrompt ?? this.showNextEpisodePrompt,
      mpvSettings: mpvSettings ?? this.mpvSettings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultQuality': defaultQuality,
      'enableAniSkip': enableAniSkip,
      'enableAutoSkip': enableAutoSkip,
      'preferDub': preferDub,
      'seekDuration': seekDuration,
      'bufferSize': bufferSize,
      'autoHideDuration': autoHideDuration,
      'lockAutoHideDuration': lockAutoHideDuration,
      'showNextPrevButtons': showNextPrevButtons,
      'prefetchNextEpisode': prefetchNextEpisode,
      'showNextEpisodePrompt': showNextEpisodePrompt,
      'mpvSettings': mpvSettings,
    };
  }

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    return PlayerModel(
      defaultQuality: map['defaultQuality'] ?? 'Auto',
      enableAniSkip: map['enableAniSkip'] ?? true,
      enableAutoSkip: map['enableAutoSkip'] ?? false,
      preferDub: map['preferDub'] ?? true,
      seekDuration: map['seekDuration'] ?? 10,
      autoHideDuration: map['autoHideDuration'] ?? 5,
      lockAutoHideDuration: map['lockAutoHideDuration'] ?? 3,
      bufferSize: map['bufferSize'] ?? 32,
      showNextPrevButtons: map['showNextPrevButtons'] ?? true,
      prefetchNextEpisode: map['prefetchNextEpisode'] ?? true,
      showNextEpisodePrompt: map['showNextEpisodePrompt'] ?? true,
      mpvSettings: Map<String, String>.from(map['mpvSettings'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory PlayerModel.fromJson(String source) =>
      PlayerModel.fromMap(json.decode(source));
}
