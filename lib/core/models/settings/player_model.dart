import 'dart:convert';

class PlayerModel {
  final String defaultQuality;
  final bool enableAniSkip;
  final bool enableAutoSkip;
  final bool skipFillerEpisodes;
  final String preferredAudioLanguage; // 'sub', 'dub', 'hindi'
  final String? preferredHindiProvider; // null or 'auto', or provider ID like 'animesalt'
  final String hindiFallbackAudio; // 'dub', 'sub', 'ask' (default: 'dub')
  final int seekDuration;
  final int autoHideDuration;
  final int lockAutoHideDuration;
  final bool showNextPrevButtons;
  final bool prefetchNextEpisode;
  final bool showNextEpisodePrompt;
  final double bufferSize;
  final bool stopAfterCurrentEpisode;
  final double defaultPlaybackSpeed;
  final Map<String, String> mpvSettings;
  final bool showManualSkip;
  final int manualSkipDuration;

  PlayerModel({
    this.defaultQuality = 'Auto',
    this.enableAniSkip = true,
    this.enableAutoSkip = false,
    this.skipFillerEpisodes = false,
    bool? preferDub,
    String? preferredAudioLanguage,
    this.preferredHindiProvider,
    this.hindiFallbackAudio = 'dub',
    this.bufferSize = 32,
    this.seekDuration = 10,
    this.autoHideDuration = 5,
    this.lockAutoHideDuration = 3,
    this.showNextPrevButtons = true,
    this.prefetchNextEpisode = true,
    this.showNextEpisodePrompt = true,
    this.stopAfterCurrentEpisode = false,
    this.defaultPlaybackSpeed = 1.0,
    this.mpvSettings = const {},
    this.showManualSkip = true,
    this.manualSkipDuration = 85,
  }) : preferredAudioLanguage = preferredAudioLanguage ??
            (preferDub != null ? (preferDub ? 'dub' : 'sub') : 'dub');

  /// 100% backward-compatible getter for existing code paths
  bool get preferDub => preferredAudioLanguage == 'dub';

  PlayerModel copyWith({
    String? defaultQuality,
    bool? enableAniSkip,
    bool? enableAutoSkip,
    bool? skipFillerEpisodes,
    bool? preferDub,
    String? preferredAudioLanguage,
    String? preferredHindiProvider,
    String? hindiFallbackAudio,
    int? seekDuration,
    int? autoHideDuration,
    int? lockAutoHideDuration,
    double? bufferSize,
    bool? showNextPrevButtons,
    bool? prefetchNextEpisode,
    bool? showNextEpisodePrompt,
    bool? stopAfterCurrentEpisode,
    double? defaultPlaybackSpeed,
    Map<String, String>? mpvSettings,
    bool? showManualSkip,
    int? manualSkipDuration,
  }) {
    final newAudioLang = preferredAudioLanguage ??
        (preferDub != null
            ? (preferDub ? 'dub' : 'sub')
            : this.preferredAudioLanguage);

    return PlayerModel(
      defaultQuality: defaultQuality ?? this.defaultQuality,
      enableAniSkip: enableAniSkip ?? this.enableAniSkip,
      enableAutoSkip: enableAutoSkip ?? this.enableAutoSkip,
      skipFillerEpisodes: skipFillerEpisodes ?? this.skipFillerEpisodes,
      preferredAudioLanguage: newAudioLang,
      preferredHindiProvider:
          preferredHindiProvider ?? this.preferredHindiProvider,
      hindiFallbackAudio: hindiFallbackAudio ?? this.hindiFallbackAudio,
      seekDuration: seekDuration ?? this.seekDuration,
      autoHideDuration: autoHideDuration ?? this.autoHideDuration,
      lockAutoHideDuration: lockAutoHideDuration ?? this.lockAutoHideDuration,
      bufferSize: bufferSize ?? this.bufferSize,
      showNextPrevButtons: showNextPrevButtons ?? this.showNextPrevButtons,
      prefetchNextEpisode: prefetchNextEpisode ?? this.prefetchNextEpisode,
      showNextEpisodePrompt:
          showNextEpisodePrompt ?? this.showNextEpisodePrompt,
      stopAfterCurrentEpisode:
          stopAfterCurrentEpisode ?? this.stopAfterCurrentEpisode,
      defaultPlaybackSpeed:
          defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      mpvSettings: mpvSettings ?? this.mpvSettings,
      showManualSkip: showManualSkip ?? this.showManualSkip,
      manualSkipDuration: manualSkipDuration ?? this.manualSkipDuration,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultQuality': defaultQuality,
      'enableAniSkip': enableAniSkip,
      'enableAutoSkip': enableAutoSkip,
      'skipFillerEpisodes': skipFillerEpisodes,
      'preferDub': preferDub,
      'preferredAudioLanguage': preferredAudioLanguage,
      'preferredHindiProvider': preferredHindiProvider,
      'hindiFallbackAudio': hindiFallbackAudio,
      'seekDuration': seekDuration,
      'bufferSize': bufferSize,
      'autoHideDuration': autoHideDuration,
      'lockAutoHideDuration': lockAutoHideDuration,
      'showNextPrevButtons': showNextPrevButtons,
      'prefetchNextEpisode': prefetchNextEpisode,
      'showNextEpisodePrompt': showNextEpisodePrompt,
      'stopAfterCurrentEpisode': stopAfterCurrentEpisode,
      'defaultPlaybackSpeed': defaultPlaybackSpeed,
      'mpvSettings': mpvSettings,
      'showManualSkip': showManualSkip,
      'manualSkipDuration': manualSkipDuration,
    };
  }

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    final rawPrefLang = map['preferredAudioLanguage'] as String?;
    final rawPreferDub = map['preferDub'] as bool?;
    final audioLang = rawPrefLang ??
        (rawPreferDub != null ? (rawPreferDub ? 'dub' : 'sub') : 'dub');

    return PlayerModel(
      defaultQuality: map['defaultQuality'] ?? 'Auto',
      enableAniSkip: map['enableAniSkip'] ?? true,
      enableAutoSkip: map['enableAutoSkip'] ?? false,
      skipFillerEpisodes: map['skipFillerEpisodes'] ?? false,
      preferredAudioLanguage: audioLang,
      preferredHindiProvider: map['preferredHindiProvider'] as String?,
      hindiFallbackAudio: map['hindiFallbackAudio'] as String? ?? 'dub',
      seekDuration: map['seekDuration'] ?? 10,
      autoHideDuration: map['autoHideDuration'] ?? 5,
      lockAutoHideDuration: map['lockAutoHideDuration'] ?? 3,
      bufferSize: (map['bufferSize'] as num?)?.toDouble() ?? 32.0,
      showNextPrevButtons: map['showNextPrevButtons'] ?? true,
      prefetchNextEpisode: map['prefetchNextEpisode'] ?? true,
      showNextEpisodePrompt: map['showNextEpisodePrompt'] ?? true,
      stopAfterCurrentEpisode: map['stopAfterCurrentEpisode'] ?? false,
      defaultPlaybackSpeed:
          (map['defaultPlaybackSpeed'] as num?)?.toDouble() ?? 1.0,
      mpvSettings: Map<String, String>.from(map['mpvSettings'] ?? {}),
      showManualSkip: map['showManualSkip'] ?? true,
      manualSkipDuration: map['manualSkipDuration'] ?? 85,
    );
  }

  String toJson() => json.encode(toMap());

  factory PlayerModel.fromJson(String source) =>
      PlayerModel.fromMap(json.decode(source));
}
