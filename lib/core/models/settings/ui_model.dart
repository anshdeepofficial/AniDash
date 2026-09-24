import 'dart:convert';

import 'package:ani_dash/shared/ui/cards/anime/anime_card_mode.dart';
import 'package:ani_dash/shared/ui/cards/spotlight/spotlight_card_mode.dart';

class UiSettings {
  final AnimeCardMode cardStyle;
  final SpotlightCardMode spotlightCardStyle;
  final bool immersiveMode;
  final String episodeViewMode;
  final double scale;
  final bool showBrowseNav;
  final bool showMangaNav;
  final bool showDownloadsNav;
  final bool showWatchlistNav;

  UiSettings({
    this.cardStyle = AnimeCardMode.defaults,
    this.immersiveMode = false,
    this.spotlightCardStyle = SpotlightCardMode.defaults,
    this.episodeViewMode = 'list',
    this.scale = 1.0,
    this.showBrowseNav = true,
    this.showMangaNav = true,
    this.showDownloadsNav = true,
    this.showWatchlistNav = true,
  });

  UiSettings copyWith({
    AnimeCardMode? cardStyle,
    bool? immersiveMode,
    SpotlightCardMode? spotlightCardStyle,
    String? episodeViewMode,
    double? scale,
    bool? showBrowseNav,
    bool? showMangaNav,
    bool? showDownloadsNav,
    bool? showWatchlistNav,
  }) {
    return UiSettings(
      cardStyle: cardStyle ?? this.cardStyle,
      immersiveMode: immersiveMode ?? this.immersiveMode,
      spotlightCardStyle: spotlightCardStyle ?? this.spotlightCardStyle,
      episodeViewMode: episodeViewMode ?? this.episodeViewMode,
      scale: scale ?? this.scale,
      showBrowseNav: showBrowseNav ?? this.showBrowseNav,
      showMangaNav: showMangaNav ?? this.showMangaNav,
      showDownloadsNav: showDownloadsNav ?? this.showDownloadsNav,
      showWatchlistNav: showWatchlistNav ?? this.showWatchlistNav,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cardStyle': cardStyle.index,
      'immersiveMode': immersiveMode,
      'spotlightCardStyle': spotlightCardStyle.index,
      'episodeViewMode': episodeViewMode,
      'scale': scale,
      'showBrowseNav': showBrowseNav,
      'showMangaNav': showMangaNav,
      'showDownloadsNav': showDownloadsNav,
      'showWatchlistNav': showWatchlistNav,
    };
  }

  factory UiSettings.fromMap(Map<String, dynamic> map) {
    return UiSettings(
      cardStyle: AnimeCardMode.values[map['cardStyle'] ?? 0],
      immersiveMode: map['immersiveMode'] ?? false,
      spotlightCardStyle:
          SpotlightCardMode.values[map['spotlightCardStyle'] ?? 0],
      episodeViewMode: map['episodeViewMode'] ?? 'list',
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      showBrowseNav: map['showBrowseNav'] ?? true,
      showMangaNav: map['showMangaNav'] ?? true,
      showDownloadsNav: map['showDownloadsNav'] ?? true,
      showWatchlistNav: map['showWatchlistNav'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory UiSettings.fromJson(String source) =>
      UiSettings.fromMap(json.decode(source));
}
