// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';

@immutable
class SourceState {
  // Extension Lists
  final List<Source> installedAnimeExtensions;
  final List<Source> installedMangaExtensions;
  final List<Source> installedNovelExtensions;
  final List<Source> installedAdultAnimeExtensions;
  final List<Source> installedAdultMangaExtensions;

  // Fetched Extension Lists
  final List<Source> fetchedAnimeExtensions;
  final List<Source> fetchedMangaExtensions;
  final List<Source> fetchedNovelExtensions;

  // Active Sources
  final Source? activeAnimeSource;
  final Source? activeMangaSource;
  final Source? activeNovelSource;
  final Source? activeAdultAnimeSource;

  // Other State
  final String lastUpdatedSourceType; // 'ANIME', 'MANGA', 'NOVEL'
  final String activeAnimeRepo;
  final String activeMangaRepo;
  final String activeNovelRepo;
  final bool isLoading;

  const SourceState({
    this.installedAnimeExtensions = const [],
    this.installedMangaExtensions = const [],
    this.installedNovelExtensions = const [],
    this.installedAdultAnimeExtensions = const [],
    this.installedAdultMangaExtensions = const [],
    this.fetchedAnimeExtensions = const [],
    this.fetchedMangaExtensions = const [],
    this.fetchedNovelExtensions = const [],
    this.activeAnimeSource,
    this.activeMangaSource,
    this.activeNovelSource,
    this.activeAdultAnimeSource,
    this.lastUpdatedSourceType = '',
    this.activeAnimeRepo = '',
    this.activeMangaRepo = '',
    this.activeNovelRepo = '',
    this.isLoading = true,
  });

  SourceState copyWith({
    List<Source>? installedAnimeExtensions,
    List<Source>? installedMangaExtensions,
    List<Source>? installedNovelExtensions,
    List<Source>? installedAdultAnimeExtensions,
    List<Source>? installedAdultMangaExtensions,
    List<Source>? fetchedAnimeExtensions,
    List<Source>? fetchedMangaExtensions,
    List<Source>? fetchedNovelExtensions,
    Source? activeAnimeSource,
    Source? activeMangaSource,
    Source? activeNovelSource,
    Source? activeAdultAnimeSource,
    String? lastUpdatedSourceType,
    String? activeAnimeRepo,
    String? activeMangaRepo,
    String? activeNovelRepo,
    bool? isLoading,
  }) {
    return SourceState(
      installedAnimeExtensions:
          installedAnimeExtensions ?? this.installedAnimeExtensions,
      installedMangaExtensions:
          installedMangaExtensions ?? this.installedMangaExtensions,
      installedNovelExtensions:
          installedNovelExtensions ?? this.installedNovelExtensions,
      installedAdultAnimeExtensions:
          installedAdultAnimeExtensions ?? this.installedAdultAnimeExtensions,
      installedAdultMangaExtensions:
          installedAdultMangaExtensions ?? this.installedAdultMangaExtensions,
      fetchedAnimeExtensions:
          fetchedAnimeExtensions ?? this.fetchedAnimeExtensions,
      fetchedMangaExtensions:
          fetchedMangaExtensions ?? this.fetchedMangaExtensions,
      fetchedNovelExtensions:
          fetchedNovelExtensions ?? this.fetchedNovelExtensions,
      activeAnimeSource: activeAnimeSource ?? this.activeAnimeSource,
      activeMangaSource: activeMangaSource ?? this.activeMangaSource,
      activeNovelSource: activeNovelSource ?? this.activeNovelSource,
      activeAdultAnimeSource:
          activeAdultAnimeSource ?? this.activeAdultAnimeSource,
      lastUpdatedSourceType:
          lastUpdatedSourceType ?? this.lastUpdatedSourceType,
      activeAnimeRepo: activeAnimeRepo ?? this.activeAnimeRepo,
      activeMangaRepo: activeMangaRepo ?? this.activeMangaRepo,
      activeNovelRepo: activeNovelRepo ?? this.activeNovelRepo,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
