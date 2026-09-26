// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:ani_dash/features/downloads/model/download_item.dart';
import 'package:ani_dash/features/downloads/model/download_status.dart';
import 'package:ani_dash/features/downloads/view_model/downloads_notifier.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart'
    hide Source;
import 'package:flutter/material.dart';
import 'package:ani_dash/router/router_config.dart';
import 'package:media_kit/media_kit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:ani_dash/core/models/anime/episode_model.dart';
import 'package:ani_dash/core/models/anime/server_model.dart';
import 'package:ani_dash/core/models/anime/source_model.dart';
import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:ani_dash/features/watch/view_model/aniskip_notifier.dart';
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/features/watch/view/widgets/download_source_selector.dart';
import 'package:ani_dash/core/registery/sources/anime/justanime.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';
import 'package:ani_dash/shared/providers/settings/download_settings_notifier.dart';
import 'package:ani_dash/core/models/settings/experimental_model.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'package:ani_dash/features/watch/view_model/next_episode_prompt_provider.dart';
import 'package:ani_dash/core/utils/extractors.dart' as extractor;
import 'package:ani_dash/helpers/matcher.dart';

part 'episode_stream_provider.g.dart';

enum EpisodeStreamState {
  SOURCE_LOADING,
  SUBTITLE_LOADING,
  SERVER_LOADING,
  QUALITY_LOADING,
}

class _CachedSourceEntry {
  final BaseSourcesModel data;
  final DateTime timestamp;

  _CachedSourceEntry(this.data) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 30);
}

final Map<String, _CachedSourceEntry> _sourceCache = {};
final Map<String, List<ServerData>> _serverListCache = {};
final Map<String, String> _animeSearchMatchCache = {};
final Map<String, List<EpisodeDataModel>> _animeEpisodesCache = {};

class _PlaybackTiming {
  final int episode;
  final Stopwatch totalStopwatch = Stopwatch()..start();
  int? mappingMs;
  int? streamResolveMs;
  int? playerOpenMs;

  _PlaybackTiming({required this.episode});

  void logSummary({String? server, String? provider}) {
    totalStopwatch.stop();
    AppLogger.d(
      '[PlaybackTiming] Ep $episode (${provider ?? "unknown"}${server != null ? " / $server" : ""}) | '
      'Mapping: ${mappingMs ?? 0}ms | '
      'Stream: ${streamResolveMs ?? 0}ms | '
      'Player Open: ${playerOpenMs ?? 0}ms | '
      'Total: ${totalStopwatch.elapsedMilliseconds}ms',
    );
  }
}

@immutable
class EpisodeDataState {
  final Map<String, String>? headers;
  final List<Source> sources;
  final List<Subtitle> subtitles;
  final List<Map<String, dynamic>> qualityOptions;
  final List<ServerData> servers;
  final int? selectedQualityIdx;
  final int? selectedSourceIdx;
  final int? selectedEpisode;
  final int selectedSubtitleIdx;
  final ServerData? selectedServer;
  final Set<EpisodeStreamState> states;
  final String? error;
  final String? languageNotice;

  const EpisodeDataState({
    this.headers,
    this.sources = const [],
    this.subtitles = const [],
    this.qualityOptions = const [],
    this.servers = const [],
    this.selectedQualityIdx,
    this.selectedSourceIdx,
    this.selectedEpisode,
    this.selectedSubtitleIdx = 0,
    this.selectedServer,
    this.states = const {},
    this.error,
    this.languageNotice,
  });

  bool get isLoading => states.isNotEmpty;

  EpisodeDataState copyWith({
    Map<String, String>? headers,
    List<Source>? sources,
    List<Subtitle>? subtitles,
    List<Map<String, dynamic>>? qualityOptions,
    List<ServerData>? servers,
    int? selectedQualityIdx,
    int? selectedSourceIdx,
    int? selectedEpisode,
    int? selectedSubtitleIdx,
    ServerData? selectedServer,
    EpisodeStreamState? addState,
    EpisodeStreamState? removeState,
    String? error,
    String? languageNotice,
    bool clearError = false,
    bool clearLanguageNotice = false,
  }) {
    final newStates = Set<EpisodeStreamState>.from(states);
    if (removeState != null) newStates.remove(removeState);
    if (addState != null) newStates.add(addState);

    return EpisodeDataState(
      headers: headers ?? this.headers,
      sources: sources ?? this.sources,
      subtitles: subtitles ?? this.subtitles,
      qualityOptions: qualityOptions ?? this.qualityOptions,
      servers: servers ?? this.servers,
      selectedQualityIdx: selectedQualityIdx ?? this.selectedQualityIdx,
      selectedSourceIdx: selectedSourceIdx ?? this.selectedSourceIdx,
      selectedEpisode: selectedEpisode ?? this.selectedEpisode,
      selectedSubtitleIdx: selectedSubtitleIdx ?? this.selectedSubtitleIdx,
      selectedServer: selectedServer ?? this.selectedServer,
      states: newStates,
      error: clearError ? null : (error ?? this.error),
      languageNotice:
          clearLanguageNotice ? null : (languageNotice ?? this.languageNotice),
    );
  }
}

@Riverpod(keepAlive: true)
class EpisodeData extends _$EpisodeData {
  int _loadGeneration = 0;
  EpisodeListState get _epList => ref.read(episodeListProvider);
  ExperimentalFeaturesModel get _exp => ref.read(experimentalProvider);
  AnimeProvider? get _provider => ref.read(selectedAnimeProvider);
  SourceNotifier get _srcNotifier => ref.read(sourceProvider.notifier);
  PlayerStateNotifier get _player => ref.read(playerStateProvider.notifier);

  bool get _isNativeProvider {
    final key = ref.read(selectedProviderKeyProvider);
    if (key == null || key.isEmpty) return false;
    return ref.read(animeSourceRegistryProvider).has(key);
  }

  AnimeProvider? get _effectiveProvider {
    final registry = ref.read(animeSourceRegistryProvider);
    final currentKey = ref.read(selectedProviderKeyProvider)?.toLowerCase();
    if (_provider?.providerName == 'justanime' || currentKey == 'justanime') {
      return registry.get('justanime') ?? JustAnimeProvider();
    }
    return _provider;
  }

  String get _justAnimeId {
    if (_epList.mediaId != null && int.tryParse(_epList.mediaId!) != null) {
      return _epList.mediaId!;
    }
    if (int.tryParse(_epList.animeId ?? '') != null) {
      return _epList.animeId!;
    }
    return _epList.mediaId ?? _epList.animeId ?? '';
  }

  @override
  EpisodeDataState build() => const EpisodeDataState();

  Future<void> loadEpisode({
    required int ep,
    bool play = true,
    Duration? startAt,
    String? mediaId,
  }) async {
    if (!_isValidEp(ep)) {
      AppLogger.fail('Invalid episode requested: $ep');
      return;
    }

    final generation = ++_loadGeneration;
    _player.setActiveSession(mediaId ?? _epList.animeId, ep);

    AppLogger.section('Loading Episode $ep');
    final playerSettings = ref.read(playerSettingsProvider);
    final preferDub = playerSettings.preferDub;
    ServerData? currentServer = state.selectedServer;

    if (currentServer != null && currentServer.isDub != preferDub) {
      final matching =
          state.servers.firstWhereOrNull(
            (s) =>
                s.isDub == preferDub &&
                (s.id == currentServer?.id || s.name == currentServer?.name),
          ) ??
          state.servers.firstWhereOrNull((s) => s.isDub == preferDub);
      currentServer = matching ?? currentServer.copyWith(isDub: preferDub);
    } else if (currentServer == null && state.servers.isNotEmpty) {
      currentServer = state.servers.firstWhereOrNull(
        (s) => s.isDub == preferDub,
      );
    }

    state = state.copyWith(
      selectedEpisode: ep,
      selectedServer: currentServer,
      addState: play ? EpisodeStreamState.SOURCE_LOADING : null,
      clearError: true,
      clearLanguageNotice: true,
    );

    // Server lists are useful for manual switching, but they must not hold the
    // first frame hostage. Discover servers concurrently in background.
    _fetchServers(ep, generation);

    if (play) {
      await _playCurrent(startAt ?? Duration.zero, generation: generation);
    }
  }

  Future<void> changeEpisode(
    int? ep, {
    Duration? startAt,
    int by = 0,
    bool force = false,
  }) async {
    final currentEp = state.selectedEpisode ?? 1;
    final target = by != 0 ? currentEp + by : ep;
    if (target == null || !_isValidEp(target)) return;

    // Stop playback after current episode when requested.
    if (!force &&
        target > currentEp &&
        ref.read(playerSettingsProvider).stopAfterCurrentEpisode) {
      AppLogger.i(
        'Stop After This Episode active: Halting changeEpisode to $target.',
      );
      ref
          .read(playerSettingsProvider.notifier)
          .updateSettings((s) => s.copyWith(stopAfterCurrentEpisode: false));
      ref.read(playerStateProvider.notifier).pause();
      ref.read(nextEpisodePromptProvider.notifier).dismiss();
      return;
    }

    AppLogger.i('Changing to episode: $target');
    await loadEpisode(ep: target, play: true, startAt: startAt);
  }

  void clearEpisodeCache({String? mediaId, int? episodeNumber}) {
    final targetMediaId = mediaId ?? _epList.animeId ?? _epList.mediaId;
    if (targetMediaId == null && episodeNumber == null) {
      _sourceCache.clear();
      _serverListCache.clear();
      _animeSearchMatchCache.clear();
      _animeEpisodesCache.clear();
    } else if (targetMediaId != null && episodeNumber != null) {
      _sourceCache.removeWhere(
        (k, _) => k.startsWith('${targetMediaId}_$episodeNumber'),
      );
      _serverListCache.remove('${targetMediaId}_$episodeNumber');
    } else if (targetMediaId != null) {
      _sourceCache.removeWhere((k, _) => k.startsWith('${targetMediaId}_'));
      _serverListCache.removeWhere((k, _) => k.startsWith('${targetMediaId}_'));
    }
    _prefetchedEpNum = null;
    _prefetchedSourceData = null;
    JustAnimeProvider.clearCache(
      animeId: targetMediaId,
      episode: episodeNumber,
    );
    AppLogger.i(
      'Cleared episode stream cache for $targetMediaId Ep $episodeNumber',
    );
  }

  int? _prefetchedEpNum;
  BaseSourcesModel? _prefetchedSourceData;
  bool _isPrefetching = false;

  Future<void> prefetchNextEpisode() async {
    final currentEp = state.selectedEpisode;
    if (currentEp == null || _isPrefetching) return;
    final nextEpNum = currentEp + 1;
    if (!_isValidEp(nextEpNum)) return;
    if (_prefetchedEpNum == nextEpNum && _prefetchedSourceData != null) return;

    final settings = ref.read(playerSettingsProvider);
    if (!settings.prefetchNextEpisode) return;

    _isPrefetching = true;
    try {
      AppLogger.i('⚡ Background pre-fetching stream for Episode $nextEpNum');
      final epModel = _epList.getEpisode(nextEpNum);
      if (epModel == null) return;

      final data = await _fetchSourceData(
        epModel,
        server: state.selectedServer,
      ).timeout(const Duration(seconds: 15));

      if (data != null && data.sources.isNotEmpty) {
        _prefetchedEpNum = nextEpNum;
        _prefetchedSourceData = data;
        AppLogger.success(
          '⚡ Successfully pre-fetched Episode $nextEpNum stream ready for instant play!',
        );
      }
    } catch (e) {
      AppLogger.w('Background prefetch failed: $e');
    } finally {
      _isPrefetching = false;
    }
  }

  Future<void> changeServer(ServerData server) async {
    final generation = ++_loadGeneration;
    AppLogger.infoPair('Changing Server', server.name ?? server.id);
    ref
        .read(playerSettingsProvider.notifier)
        .updateSettings((s) => s.copyWith(preferDub: server.isDub));
    state = state.copyWith(selectedServer: server);
    await _playCurrent(
      ref.read(playerStateProvider).position,
      generation: generation,
    );
  }

  Future<void> switchAudioLanguage(String language) async {
    final generation = ++_loadGeneration;
    ref
        .read(playerSettingsProvider.notifier)
        .setPreferredAudioLanguage(language);

    final isDub = language == 'dub';
    final current = state.selectedServer;
    ServerData? alt = state.servers.firstWhereOrNull(
      (s) =>
          s.isDub == isDub && (s.id == current?.id || s.name == current?.name),
    );
    alt ??= state.servers.firstWhereOrNull((s) => s.isDub == isDub);
    alt ??=
        (current != null)
            ? current.copyWith(isDub: isDub)
            : ServerData(id: 'default', name: 'Default', isDub: isDub);

    AppLogger.i('Switching audio track to: ${isDub ? "DUB" : "SUB"}');
    state = state.copyWith(selectedServer: alt);
    await _playCurrent(
      ref.read(playerStateProvider).position,
      generation: generation,
    );
  }

  Future<void> toggleDubSub() async {
    final currentPref = ref.read(playerSettingsProvider).preferredAudioLanguage;
    final next = currentPref == 'dub' ? 'sub' : 'dub';
    await switchAudioLanguage(next);
  }

  Future<void> changeSource(int idx) async {
    if (idx < 0 || idx >= state.sources.length) return;
    AppLogger.infoPair('Changing Source Index', idx);
    await _loadSourceStream(
      idx,
      startAt: ref.read(playerStateProvider).position,
    );
  }

  Future<void> changeQuality(int idx) async {
    if (idx < 0 || idx >= state.qualityOptions.length) return;

    final url = state.qualityOptions[idx]['url'] as String?;
    if (url == null) return;

    AppLogger.infoPair(
      'Changing Quality',
      state.qualityOptions[idx]['quality'],
    );
    state = state.copyWith(selectedQualityIdx: idx);
    _player.open(
      url,
      ref.read(playerStateProvider).position,
      headers: state.headers,
      mediaId: _epList.animeId,
      episode: state.selectedEpisode,
    );
  }

  Future<void> changeSubtitle(int idx) async {
    state = state.copyWith(
      addState: EpisodeStreamState.SUBTITLE_LOADING,
      clearError: true,
    );

    if (idx <= 0 || idx >= state.subtitles.length) {
      AppLogger.d('Disabling Subtitles');
      await _player.setSubtitle(SubtitleTrack.no());
      state = state.copyWith(
        selectedSubtitleIdx: 0,
        removeState: EpisodeStreamState.SUBTITLE_LOADING,
      );
      return;
    }

    final sub = state.subtitles[idx];
    AppLogger.infoPair('Applying Subtitle', sub.lang);

    if (sub.url != null) await _player.setSubtitle(SubtitleTrack.uri(sub.url!));

    state = state.copyWith(
      selectedSubtitleIdx: idx,
      removeState: EpisodeStreamState.SUBTITLE_LOADING,
    );
  }

  Future<void> addLocalSubtitle(File file) async {
    AppLogger.i('Adding local subtitle: ${file.path}');
    final sub = Subtitle(
      url: 'file://${file.path}',
      lang: 'Local: ${file.path.split('/').last}',
    );

    state = state.copyWith(subtitles: [...state.subtitles, sub]);
    await changeSubtitle(state.subtitles.length - 1);
  }

  Future<void> downloadEpisode(BuildContext context, int epNum) async {
    final link = ref.keepAlive();
    try {
      if (!_isValidEp(epNum) || _epList.animeId == null) return;

      final ep = _epList.episodes.firstWhereOrNull((i) => i.number == epNum);
      if (ep == null) return;

      final dlSettings = ref.read(downloadSettingsProvider);
      if (dlSettings.rememberDownloadPreferences) {
        await _directDownloadSingle(
          context,
          ep,
          dlSettings.preferredLanguage,
          dlSettings.preferredQuality,
        );
        return;
      }

      AppLogger.section('Initializing Download for Ep $epNum');

      List<ServerData> servers = [];
      _showLoading(context);
      try {
        servers = await _getRawServers(
          ep,
        ).timeout(const Duration(seconds: 10), onTimeout: () => <ServerData>[]);
      } catch (e) {
        AppLogger.w('Failed to get raw servers: $e');
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!context.mounted) return;

      ServerData? selected;
      if (servers.isNotEmpty) {
        selected =
            servers.length == 1
                ? servers.first
                : await _showServerSheet(context, servers);
        if (selected == null || !context.mounted) return;
      }

      if (!context.mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder:
            (sheetContext) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              child: DownloadSourceSelector(
                animeTitle: _epList.animeTitle ?? 'Unknown',
                animeCover: _epList.animeCover,
                episode: ep,
                episodeCount: 1,
                server: selected,
                fetchSources: () => _fetchSourceData(ep, server: selected),
              ),
            ),
      );
    } catch (e, st) {
      AppLogger.e('Download initialization failed', e, st);
      if (context.mounted) {
        _showSnack(context, "Download failed: $e");
      }
    } finally {
      link.close();
    }
  }

  Future<void> _directDownloadSingle(
    BuildContext context,
    EpisodeDataModel ep,
    String language,
    String quality,
  ) async {
    final epNum = ep.number ?? 0;
    final animeTitle = _epList.animeTitle ?? 'Unknown';

    try {
      _showLoading(context);
      BaseSourcesModel? data;
      ServerData? preferredServer;
      try {
        if (_isNativeProvider) {
          final servers = await _getRawServers(ep).timeout(
            const Duration(seconds: 12),
            onTimeout: () => <ServerData>[],
          );
          preferredServer = servers.firstWhereOrNull(
            (server) => language == 'dub' ? server.isDub : !server.isDub,
          );
          preferredServer ??= ServerData(
            name: 'Default',
            id: 'default',
            isDub: language == 'dub',
          );
        }
        data = await _fetchSourceData(ep, server: preferredServer);
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!context.mounted) return;

      if (data == null || data.sources.isEmpty) {
        return _showSnack(
          context,
          "No download sources available for Ep $epNum",
        );
      }

      Source? matchedSource;
      if (language == 'dub') {
        matchedSource = data.sources.firstWhereOrNull((s) => s.isDub);
        matchedSource ??=
            preferredServer?.isDub == true ? data.sources.firstOrNull : null;
      } else {
        matchedSource = data.sources.firstWhereOrNull((s) => !s.isDub);
      }
      if (matchedSource == null && language == 'dub') {
        return _showSnack(
          context,
          'DUB could not be verified. Check the connection and retry.',
        );
      }
      matchedSource ??= data.sources.firstOrNull;

      if (matchedSource == null ||
          matchedSource.url == null ||
          matchedSource.url!.isEmpty) {
        return _showSnack(context, "Could not find stream for Ep $epNum");
      }

      String downloadUrl = matchedSource.url!;
      final isM3U8 = matchedSource.isM3U8 || downloadUrl.contains('.m3u8');

      if (isM3U8) {
        try {
          final extracted = await extractor
              .extractQualities(
                matchedSource.url!,
                matchedSource.headers ?? {},
                true,
              )
              .timeout(const Duration(seconds: 6));

          final target = extracted.firstWhereOrNull(
            (q) => (q['quality'] as String).contains(quality),
          );
          if (target != null &&
              target['url'] != null &&
              (target['url'] as String).isNotEmpty) {
            downloadUrl = target['url'] as String;
          }
        } catch (_) {}
      }

      final ext = isM3U8 ? 'ts' : 'mp4';
      final sanitizedTitle = animeTitle.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final qualityName = quality.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '${sanitizedTitle}_EP${epNum}_$qualityName.$ext';

      final animeCover = _epList.animeCover ?? '';
      final thumb =
          (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
              ? ep.thumbnail!
              : animeCover;

      final item = DownloadItem(
        animeTitle: animeTitle,
        episodeTitle: ep.title ?? 'Episode $epNum',
        episodeNumber: epNum,
        thumbnail: thumb,
        state: DownloadStatus.queued,
        progress: 0,
        downloadUrl: downloadUrl,
        quality: quality,
        filePath: fileName,
        subtitles: data.tracks.map((s) => jsonEncode(s.toJson())).toList(),
        contentType: isM3U8 ? 'application/vnd.apple.mpegurl' : null,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          ...?matchedSource.headers,
        },
        isAdult: _epList.isAdult,
        audioLanguage: language == 'dub' ? 'English DUB' : 'Japanese SUB',
      );

      await ref.read(downloadsProvider.notifier).addDownload(item);
      if (context.mounted) {
        _showSnack(
          context,
          "Download queued for Ep $epNum ($quality)",
          showDownloadsAction: true,
          downloadId: item.id,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, "Download failed: $e");
      }
    }
  }

  Future<void> downloadBatchEpisodes(
    BuildContext context,
    List<int> epNums, {
    String? preferredLanguage,
    String? preferredQuality,
  }) async {
    final epModels =
        _epList.episodes
            .where((e) => e.number != null && epNums.contains(e.number))
            .toList()
          ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));

    if (epModels.isEmpty) return;

    final animeTitle = _epList.animeTitle ?? 'Unknown';
    final dlSettings = ref.read(downloadSettingsProvider);
    final targetLang = preferredLanguage ?? dlSettings.preferredLanguage;
    final targetQuality = preferredQuality ?? dlSettings.preferredQuality;
    int queuedCount = 0;

    for (final ep in epModels) {
      try {
        final epNum = ep.number!;
        ServerData? preferredServer;
        if (_isNativeProvider) {
          final servers = await _getRawServers(ep).timeout(
            const Duration(seconds: 12),
            onTimeout: () => <ServerData>[],
          );
          preferredServer = servers.firstWhereOrNull(
            (server) => targetLang == 'dub' ? server.isDub : !server.isDub,
          );
          preferredServer ??= ServerData(
            name: 'Default',
            id: 'default',
            isDub: targetLang == 'dub',
          );
        }
        final data = await _fetchSourceData(ep, server: preferredServer);
        if (data == null || data.sources.isEmpty) {
          AppLogger.w('Batch download: No sources for Ep $epNum');
          continue;
        }

        Source? source;
        if (targetLang == 'dub') {
          source = data.sources.firstWhereOrNull((s) => s.isDub);
          source ??=
              preferredServer?.isDub == true ? data.sources.firstOrNull : null;
        } else {
          source = data.sources.firstWhereOrNull((s) => !s.isDub);
        }
        if (source == null && targetLang == 'dub') {
          AppLogger.w('Batch download: DUB not verified for Ep $epNum');
          continue;
        }
        source ??= data.sources.firstOrNull;

        if (source == null || source.url == null || source.url!.isEmpty) {
          continue;
        }

        String downloadUrl = source.url!;
        final isM3U8 = source.isM3U8 || downloadUrl.contains('.m3u8');

        if (isM3U8) {
          try {
            final extracted = await extractor
                .extractQualities(source.url!, source.headers ?? {}, true)
                .timeout(const Duration(seconds: 5));

            final target = extracted.firstWhereOrNull(
              (q) => (q['quality'] as String).contains(targetQuality),
            );
            if (target != null &&
                target['url'] != null &&
                (target['url'] as String).isNotEmpty) {
              downloadUrl = target['url'] as String;
            }
          } catch (_) {}
        }

        final ext = isM3U8 ? 'ts' : 'mp4';
        final sanitizedTitle = animeTitle.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
        final qualityName = targetQuality.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
        final fileName = '${sanitizedTitle}_EP${epNum}_$qualityName.$ext';

        final animeCover = _epList.animeCover ?? '';
        final thumb =
            (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
                ? ep.thumbnail!
                : animeCover;

        final item = DownloadItem(
          animeTitle: animeTitle,
          episodeTitle: ep.title ?? 'Episode $epNum',
          episodeNumber: epNum,
          thumbnail: thumb,
          state: DownloadStatus.queued,
          progress: 0,
          downloadUrl: downloadUrl,
          quality: targetQuality,
          filePath: fileName,
          subtitles: data.tracks.map((s) => jsonEncode(s.toJson())).toList(),
          contentType: isM3U8 ? 'application/vnd.apple.mpegurl' : null,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            ...?source.headers,
          },
          isAdult: _epList.isAdult,
          audioLanguage: targetLang == 'dub' ? 'English DUB' : 'Japanese SUB',
        );

        await ref.read(downloadsProvider.notifier).addDownload(item);
        queuedCount++;
      } catch (e) {
        AppLogger.e('Error batch downloading Ep ${ep.number}', e);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Queued $queuedCount of ${epModels.length} episodes ($targetLang, $targetQuality)',
          ),
          backgroundColor:
              queuedCount > 0 ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View Downloads',
            textColor: Colors.white,
            onPressed: () => routerConfig.go('/downloads'),
          ),
        ),
      );
    }
  }

  void reset() {
    _loadGeneration++;
    state = const EpisodeDataState();
  }

  bool _isValidEp(int ep) {
    if (_epList.episodes.isEmpty) {
      // Allow episode 1 for movies/single-episode media
      return ep == 1;
    }
    return _epList.episodes.any((i) => i.number == ep) ||
        (ep == 1 && _epList.episodes.isEmpty);
  }

  Future<List<ServerData>> _getRawServers(EpisodeDataModel ep) async {
    final provider = _effectiveProvider;
    final activeExt =
        ref.read(sourceProvider).activeAnimeSource?.name?.toLowerCase() ?? '';
    final isJustAnime =
        provider?.providerName == 'justanime' ||
        activeExt.contains('justanime');

    if (!_isNativeProvider && _exp.useExtensions && !isJustAnime) {
      return [];
    }

    final effectiveId = isJustAnime
        ? _justAnimeId
        : ((int.tryParse(_epList.animeId ?? '') != null)
            ? _epList.animeId
            : (_epList.mediaId ?? _epList.animeId));

    return (await provider?.getSupportedServers(
          metadata: {'id': effectiveId, 'epNumber': ep.number, 'epId': ep.id},
        ))?.flatten() ??
        [];
  }

  Future<void> _fetchServers(int epNum, [int? generation]) async {

    final cacheKey =
        '${_epList.mediaId ?? _epList.animeId ?? "unknown"}_$epNum';
    final cached = _serverListCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      final preferDub = ref.read(playerSettingsProvider).preferDub;
      final currentServer = state.selectedServer;
      ServerData? selected;
      if (currentServer != null) {
        selected = cached.firstWhereOrNull(
          (s) =>
              (s.id == currentServer.id || s.name == currentServer.name) &&
              s.isDub == currentServer.isDub,
        );
      }
      selected ??= cached.firstWhereOrNull((s) => s.isDub == preferDub);
      selected ??= cached.firstOrNull;

      state = state.copyWith(servers: cached, selectedServer: selected);
      AppLogger.d('Using cached servers (${cached.length}) for Ep $epNum');
      return;
    }

    state = state.copyWith(
      addState: EpisodeStreamState.SERVER_LOADING,
      clearError: true,
    );

    try {
      var ep = _epList.episodes.firstWhereOrNull((e) => e.number == epNum);
      ep ??= EpisodeDataModel(
        id: epNum.toString(),
        number: epNum,
        title: _epList.animeTitle ?? 'Episode $epNum',
      );

      var list = await _getRawServers(ep).timeout(const Duration(seconds: 15));
      if (generation != null && generation != _loadGeneration) return;
      if (list.isEmpty) {
        state = state.copyWith(servers: [], selectedServer: null);
        return;
      }

      final preferDub = ref.read(playerSettingsProvider).preferDub;
      final currentServer = state.selectedServer;
      ServerData? selected;
      if (currentServer != null) {
        selected = list.firstWhereOrNull(
          (s) =>
              (s.id == currentServer.id || s.name == currentServer.name) &&
              s.isDub == currentServer.isDub,
        );
      }
      selected ??= list.firstWhereOrNull((s) => s.isDub == preferDub);
      selected ??= list.firstOrNull;

      _serverListCache[cacheKey] = list;
      state = state.copyWith(servers: list, selectedServer: selected);
      AppLogger.success(
        'Fetched ${list.length} servers (Default: ${selected?.name}, Dub: ${selected?.isDub})',
      );
    } catch (e, stack) {
      AppLogger.e("Server fetch failed", e, stack);
    } finally {
      state = state.copyWith(removeState: EpisodeStreamState.SERVER_LOADING);
    }
  }

  Future<void> _playCurrent(Duration startAt, {int? generation}) async {
    final activeGeneration = generation ?? _loadGeneration;
    final epNum = state.selectedEpisode;
    if (epNum == null) return;

    final timing = _PlaybackTiming(episode: epNum);

    state = state.copyWith(
      addState: EpisodeStreamState.SOURCE_LOADING,
      clearError: true,
    );

    try {
      var epModel = _epList.getEpisode(epNum);
      epModel ??= EpisodeDataModel(
        id: epNum.toString(),
        number: epNum,
        title: _epList.animeTitle ?? 'Movie',
        thumbnail: _epList.animeCover,
      );

      BaseSourcesModel? data;
      final streamSw = Stopwatch()..start();
      if (epNum == _prefetchedEpNum && _prefetchedSourceData != null) {
        AppLogger.success('⚡ Using pre-fetched stream data for Episode $epNum');
        data = _prefetchedSourceData;
        _prefetchedEpNum = null;
        _prefetchedSourceData = null;
      } else {
        data = await _fetchSourceData(
          epModel,
          server: state.selectedServer,
          generation: activeGeneration,
        ).timeout(const Duration(seconds: 15));
      }
      streamSw.stop();
      timing.streamResolveMs = streamSw.elapsedMilliseconds;

      if (activeGeneration != _loadGeneration) return;

      if (data == null || data.sources.isEmpty) {
        throw StateError('No playable sources found');
      }
      ref
          .read(aniSkipProvider.notifier)
          .setFallbackFromSource(intro: data.intro, outro: data.outro);
      state = state.copyWith(
        sources: data.sources,
        subtitles: [Subtitle(lang: 'None'), ...data.tracks],
        headers: data.headers?.cast<String, String>(),
      );
      try {
        final playerSw = Stopwatch()..start();
        await _loadSourceStream(
          0,
          startAt: startAt,
          generation: activeGeneration,
        );
        playerSw.stop();
        timing.playerOpenMs = playerSw.elapsedMilliseconds;
        timing.logSummary(
          server: state.selectedServer?.name ?? state.selectedServer?.id,
          provider: _effectiveProvider?.providerName,
        );
        if (activeGeneration != _loadGeneration) return;
      } catch (primaryError) {
        AppLogger.w('Primary stream stalled; trying alternate stream');
        var alternateStarted = false;
        final currentPos = ref.read(playerStateProvider).position;
        final recoveryStartAt = currentPos > Duration.zero
            ? currentPos
            : (_player.lastStablePosition > Duration.zero
                ? _player.lastStablePosition
                : startAt);
        for (var index = 1; index < state.sources.length; index++) {
          try {
            await _loadSourceStream(
              index,
              startAt: recoveryStartAt,
              generation: activeGeneration,
            );
            alternateStarted = true;
            break;
          } catch (_) {}
        }
        if (alternateStarted) return;

        final category = state.selectedServer?.isDub == true ? 'dub' : 'sub';
        BaseSourcesModel? fallback;

        // Try alternate JustAnime server if primary stalled
        if (_isNativeProvider && _effectiveProvider?.providerName == 'justanime') {
          final altServer =
              state.selectedServer?.id == 'megaplay' ? 'zokoanime' : 'megaplay';
          try {
            fallback = await _effectiveProvider!
                .getSources(
                  _justAnimeId,
                  epModel.id ?? epNum.toString(),
                  altServer,
                  category,
                )
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            AppLogger.w('JustAnime alternate server recovery failed: $e');
          }
        }

        fallback ??= await _fetchFallbackNativeSourceData(
          epModel,
          category,
          generation: activeGeneration,
        );
        if (fallback != null && fallback.sources.isNotEmpty) {
          if (activeGeneration != _loadGeneration) return;
          ref
              .read(aniSkipProvider.notifier)
              .setFallbackFromSource(
                intro: fallback.intro,
                outro: fallback.outro,
              );
          state = state.copyWith(
            sources: fallback.sources,
            subtitles: [Subtitle(lang: 'None'), ...fallback.tracks],
            headers: fallback.headers?.cast<String, String>(),
          );
          await _loadSourceStream(
            0,
            startAt: startAt,
            generation: activeGeneration,
          );
          return;
        }

        // Only offer SUB after every available DUB stream/server failed.
        if (state.selectedServer?.isDub == true && _effectiveProvider != null) {
          final targetId = (_effectiveProvider?.providerName == 'justanime')
              ? _justAnimeId
              : (_epList.animeId ?? '');
          final subFallback = await _effectiveProvider!
              .getSources(
                targetId,
                epModel.id ?? epNum.toString(),
                state.selectedServer?.id,
                'sub',
              )
              .timeout(const Duration(seconds: 10));
          if (subFallback.sources.any((source) => !source.isDub)) {
            if (activeGeneration != _loadGeneration) return;
            ref
                .read(aniSkipProvider.notifier)
                .setFallbackFromSource(
                  intro: subFallback.intro,
                  outro: subFallback.outro,
                );
            state = state.copyWith(
              sources: subFallback.sources,
              subtitles: [Subtitle(lang: 'None'), ...subFallback.tracks],
              headers: subFallback.headers?.cast<String, String>(),
              languageNotice:
                  'The English DUB stream could not be loaded for this episode. Japanese SUB is playing.',
            );
            await _loadSourceStream(
              0,
              startAt: startAt,
              generation: activeGeneration,
            );
            return;
          }
        }
        rethrow;
      }
    } catch (e, stack) {
      if (activeGeneration != _loadGeneration) return;
      AppLogger.e('Episode playback failed', e, stack);
      // Pause the player so the previous episode's video doesn't keep playing
      try {
        ref.read(playerStateProvider.notifier).pause();
      } catch (_) {}
      state = state.copyWith(
        error: 'Source not available for this episode. Try another server.',
      );
    } finally {
      state = state.copyWith(removeState: EpisodeStreamState.SOURCE_LOADING);
    }
  }

  Future<({bool sub, bool dub})> checkLanguageAvailability(
    EpisodeDataModel episode,
  ) async {
    final provider = _effectiveProvider;
    final animeId = (provider?.providerName == 'justanime')
        ? _justAnimeId
        : (_epList.animeId ?? _justAnimeId);
    if (provider == null || animeId.isEmpty) {
      return (sub: true, dub: false);
    }
    final episodeId = episode.id ?? episode.number?.toString() ?? '1';

    Future<bool> hasAudio(String audio) async {
      try {
        final result = await provider
            .getSources(animeId, episodeId, null, audio)
            .timeout(const Duration(seconds: 10));
        return audio == 'dub'
            ? result.sources.any((source) => source.isDub)
            : result.sources.any((source) => !source.isDub);
      } catch (_) {
        return false;
      }
    }

    final availability = await Future.wait([hasAudio('sub'), hasAudio('dub')]);
    return (sub: availability[0], dub: availability[1]);
  }

  Future<void> _loadSourceStream(
    int sourceIdx, {
    required Duration startAt,
    int? generation,
  }) async {
    final activeGeneration = generation ?? _loadGeneration;
    if (sourceIdx < 0 || sourceIdx >= state.sources.length) return;
    if (activeGeneration != _loadGeneration) return;

    state = state.copyWith(addState: EpisodeStreamState.QUALITY_LOADING);

    try {
      // Build quality options with Auto and all available discrete qualities
      final allQualities = <Map<String, dynamic>>[];
      final primarySrc = state.sources[sourceIdx];
      final streamHeaders = {...?state.headers, ...?primarySrc.headers};

      allQualities.add({'quality': 'Auto', 'url': primarySrc.url});

      for (final src in state.sources) {
        if (src.url != null &&
            src.url!.isNotEmpty &&
            src.url != primarySrc.url) {
          allQualities.add({
            'quality': src.quality ?? 'Default',
            'url': src.url,
          });
        }
      }

      // Sort discrete qualities: 1080p > 720p > 480p > 360p
      final discrete = allQualities.skip(1).toList();
      discrete.sort((a, b) {
        final aVal =
            int.tryParse(
              (a['quality'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        final bVal =
            int.tryParse(
              (b['quality'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        return bVal.compareTo(aVal);
      });
      allQualities.removeRange(1, allQualities.length);
      allQualities.addAll(discrete);

      // Pick best match for preferred quality
      final prefQuality = ref.read(playerSettingsProvider).defaultQuality;
      int qIdx = 0;
      if (prefQuality.toLowerCase() != 'auto') {
        final matchIdx = allQualities.indexWhere(
          (q) => (q['quality'] as String).toLowerCase().contains(
            prefQuality.toLowerCase(),
          ),
        );
        if (matchIdx != -1) qIdx = matchIdx;
      }

      AppLogger.d(
        'Opening stream: ${allQualities[qIdx]['quality']} '
        '(${allQualities.length} quality options available)',
      );

      // Always hand the original HLS URL to mpv. Saving a live playlist as a
      // local file freezes its segment window and breaks relative segment URLs;
      // after the cached entries run out mpv stalls and reopens near startAt.
      final playbackUrl = allQualities[qIdx]['url'] as String;

      await _player
          .open(
            playbackUrl,
            startAt,
            headers: streamHeaders,
            mediaId: _epList.animeId,
            episode: state.selectedEpisode,
          )
          .timeout(const Duration(seconds: 15));

      if (activeGeneration != _loadGeneration) return;

      final isDub = state.selectedServer?.isDub == true || primarySrc.isDub;
      if (!isDub) {
        final engIdx = state.subtitles.indexWhere(
          (s) => s.lang?.toLowerCase().contains('eng') ?? false,
        );
        if (engIdx != -1) changeSubtitle(engIdx);
      }

      state = state.copyWith(
        qualityOptions: allQualities,
        selectedSourceIdx: sourceIdx,
        selectedQualityIdx: qIdx,
      );

      // Light pre-fetch next episode metadata / stream after initial playback is rolling
      if (ref.read(playerSettingsProvider).prefetchNextEpisode) {
        Future.delayed(const Duration(seconds: 4), () {
          if (activeGeneration == _loadGeneration && !_isPrefetching) {
            prefetchNextEpisode();
          }
        });
      }

      // In background, extract sub-qualities for M3U8 without delaying playback start
      if (primarySrc.isM3U8) {
        _getQualities(primarySrc, streamHeaders)
            .then((extracted) {
              if (extracted.isNotEmpty) {
                final merged = [
                  {'quality': 'Auto', 'url': primarySrc.url},
                  ...extracted,
                  ...state.qualityOptions.where((q) => q['quality'] != 'Auto'),
                ];
                final seenUrls = <String>{};
                final seenNames = <String>{};
                merged.retainWhere((m) {
                  final u = m['url'] as String?;
                  final q = m['quality'] as String?;
                  if (u == null || seenUrls.contains(u)) return false;
                  if (q != null && q != 'Auto' && seenNames.contains(q)) {
                    return false;
                  }
                  seenUrls.add(u);
                  if (q != null) seenNames.add(q);
                  return true;
                });
                state = state.copyWith(qualityOptions: merged);
              }
            })
            .catchError((e) {
              AppLogger.d('Background quality extraction completed: $e');
            });
      }
    } finally {
      state = state.copyWith(removeState: EpisodeStreamState.QUALITY_LOADING);
    }
  }

  Future<BaseSourcesModel?> _fetchSourceData(
    EpisodeDataModel ep, {
    ServerData? server,
    int? generation,
  }) async {
    final activeGeneration = generation ?? _loadGeneration;
    if (activeGeneration != _loadGeneration) return null;

    final playerSettings = ref.read(playerSettingsProvider);
    final isDubRequested = server?.isDub ?? playerSettings.preferDub;
    final effectiveMediaKey = _epList.mediaId ?? _epList.animeId ?? 'unknown';
    final effectiveAnimeKey = _epList.animeId ?? 'unknown';
    final cacheKey =
        '${effectiveMediaKey}_${effectiveAnimeKey}_${ep.number}_${ep.id}_${server?.id}_${isDubRequested ? "dub" : "sub"}';
    final cached = _sourceCache[cacheKey];
    if (cached != null && !cached.isExpired && cached.data.sources.isNotEmpty) {
      AppLogger.success(
        '⚡ Using cached source data for Episode ${ep.number} (${cached.data.sources.length} sources, 0ms latency)',
      );
      return cached.data;
    }

    BaseSourcesModel? saveAndReturn(BaseSourcesModel? model) {
      if (model != null && model.sources.isNotEmpty) {
        _sourceCache[cacheKey] = _CachedSourceEntry(model);
      }
      return model;
    }

    AppLogger.d(
      'Fetching source data via ${server?.name ?? "Default"} (${isDubRequested ? "DUB" : "SUB"})',
    );

    final provider = _effectiveProvider;
    final activeExt =
        ref.read(sourceProvider).activeAnimeSource?.name?.toLowerCase() ?? '';
    final isJustAnime =
        provider?.providerName == 'justanime' ||
        activeExt.contains('justanime');

    final effectiveAnimeId = (isJustAnime &&
            _epList.mediaId != null &&
            int.tryParse(_epList.mediaId!) != null)
        ? _epList.mediaId!
        : (int.tryParse(_epList.animeId ?? '') != null)
            ? _epList.animeId!
            : (_epList.mediaId ?? _epList.animeId ?? '');

    // If JustAnime is active or available, fetch directly with full multi-server & exact intro/outro support!
    if (isJustAnime && provider != null && effectiveAnimeId.isNotEmpty) {
      try {
        final category = isDubRequested ? 'dub' : 'sub';
        final targetEpId =
            (ep.id != null && ep.id!.isNotEmpty)
                ? ep.id!
                : (ep.number?.toString() ?? '1');
        final res = await provider
            .getSources(effectiveAnimeId, targetEpId, server?.id, category)
            .timeout(const Duration(seconds: 15));
        if (res.sources.isNotEmpty) {
          ref
              .read(aniSkipProvider.notifier)
              .setFallbackFromSource(intro: res.intro, outro: res.outro);
          return saveAndReturn(res);
        }
      } catch (e) {
        AppLogger.w('JustAnime direct source fetch failed: $e');
      }
    }

    final epTargetUrl =
        (ep.url != null && ep.url!.isNotEmpty) ? ep.url : (ep.id ?? '');
    if (!_isNativeProvider &&
        _exp.useExtensions &&
        epTargetUrl != null &&
        epTargetUrl.isNotEmpty) {
      try {
        final res = await _srcNotifier
            .getSources(
              DEpisode(episodeNumber: ep.number.toString(), url: epTargetUrl),
            )
            .timeout(const Duration(seconds: 10));
        final extractedHeaders =
            res
                .firstWhereOrNull(
                  (v) => v?.headers != null && v!.headers!.isNotEmpty,
                )
                ?.headers ??
            res.firstOrNull?.headers;

        var sources =
            res.where((s) => s != null && s.url.isNotEmpty).map((s) {
              final item = s!;
              final title = item.title?.trim() ?? '';
              final quality = item.quality.trim();
              final cleanQ =
                  title.isEmpty
                      ? (quality.isEmpty ? 'Default' : quality)
                      : (quality.isEmpty ||
                          title == quality ||
                          title.contains(quality))
                      ? title
                      : (quality.contains(title) ? quality : '$title $quality');

              final isDubSource =
                  item.url.toLowerCase().contains('dub') ||
                  item.title?.toLowerCase().contains('dub') == true ||
                  item.quality.toLowerCase().contains('dub');

              return Source(
                url: item.url,
                isM3U8: item.url.contains('.m3u8'),
                quality: cleanQ,
                headers: item.headers ?? extractedHeaders,
                isDub: isDubSource,
              );
            }).toList();

        if (isDubRequested) {
          final dubSources = sources.where((s) => s.isDub).toList();
          if (dubSources.isNotEmpty) sources = dubSources;
        }

        if (sources.isNotEmpty) {
          final allTracks = <Subtitle>[];
          final seenUrls = <String>{};
          final langCount = <String, int>{};

          for (final v in res) {
            if (v?.subtitles != null) {
              for (final t in v!.subtitles!) {
                if (t.file != null && !seenUrls.contains(t.file)) {
                  seenUrls.add(t.file!);
                  String label = t.label?.trim() ?? 'Unknown';
                  final baseKey = label.toLowerCase();
                  langCount[baseKey] = (langCount[baseKey] ?? 0) + 1;

                  // If there are duplicate languages, disambiguate
                  if (langCount[baseKey]! > 1) {
                    if (t.file!.toLowerCase().contains('sign') ||
                        label.toLowerCase().contains('sign')) {
                      label = '$label (Signs & Songs)';
                    } else {
                      label = '$label (Track ${langCount[baseKey]})';
                    }
                  }

                  allTracks.add(
                    Subtitle(url: t.file, lang: label, isSub: true),
                  );
                }
              }
            }
          }

          return saveAndReturn(
            BaseSourcesModel(
              sources: sources,
              headers: extractedHeaders,
              tracks: allTracks,
            ),
          );
        }
      } catch (err) {
        AppLogger.e(
          'Extension source fetch failed, trying legacy provider: $err',
        );
      }
    }

    final category = isDubRequested ? 'dub' : 'sub';
    final targetEpId =
        (ep.id != null && ep.id!.isNotEmpty)
            ? ep.id!
            : (ep.number?.toString() ?? '');

    final effectiveProvider = _effectiveProvider;
    if (effectiveProvider != null) {
      try {
        final res = await effectiveProvider
            .getSources(effectiveAnimeId, targetEpId, server?.id, category)
            .timeout(const Duration(seconds: 15));
        if (res.sources.isNotEmpty) {
          return saveAndReturn(res);
        }
      } catch (e) {
        AppLogger.e('Native provider direct source fetch failed: $e');
      }

      // If direct animeId failed (e.g. animeId was an AniList ID or URL), resolve by title
      if (_epList.animeTitle != null && _epList.animeTitle!.isNotEmpty) {
        try {
          AppLogger.w(
            'Resolving anime title on ${effectiveProvider.providerName}: "${_epList.animeTitle}"',
          );
          final searchRes = await effectiveProvider
              .getSearch(_epList.animeTitle!, null, 1)
              .timeout(const Duration(seconds: 12));
          final bestMatches = getBestMatches(
            results: searchRes.results,
            title: _epList.animeTitle!,
            nameSelector: (r) => r.name,
            idSelector: (r) => r.id,
            minThreshold: 0.45,
          );
          final bestId =
              bestMatches.firstOrNull?.result.id ??
              searchRes.results.firstOrNull?.id;
          if (bestId != null && bestId != effectiveAnimeId) {
            final res = await effectiveProvider
                .getSources(bestId, targetEpId, server?.id, category)
                .timeout(const Duration(seconds: 15));
            if (res.sources.isNotEmpty) {
              AppLogger.success(
                'Resolved stream on ${effectiveProvider.providerName}',
              );
              return saveAndReturn(res);
            }
          }
        } catch (e) {
          AppLogger.d('Title recovery on active provider failed: $e');
        }
      }
    }

    final fallback = await _fetchFallbackNativeSourceData(
      ep,
      category,
      generation: activeGeneration,
    );
    return saveAndReturn(fallback);
  }

  Future<BaseSourcesModel?> _fetchFallbackNativeSourceData(
    EpisodeDataModel ep,
    String category, {
    int? generation,
  }) async {
    final activeGeneration = generation ?? _loadGeneration;
    if (activeGeneration != _loadGeneration) return null;

    final registry = ref.read(animeSourceRegistryProvider);
    final currentKey = ref.read(selectedProviderKeyProvider)?.toLowerCase();
    final targetEpId =
        (ep.id != null && ep.id!.isNotEmpty)
            ? ep.id!
            : (ep.number?.toString() ?? '1');

    final cleanTitle =
        (_epList.animeTitle ?? '')
            .replaceAll(':', ' ')
            .replaceAll('-', ' ')
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    Future<BaseSourcesModel?> resolveFromKey(String altKey) async {
      try {
        if (activeGeneration != _loadGeneration) return null;
        final altProvider = registry.get(altKey);
        if (altProvider == null) return null;
        AppLogger.w('Trying provider for stream: $altKey');

        final searchCacheKey = '$altKey:$cleanTitle';
        String? altMatchId = (altKey == 'justanime' &&
                _epList.mediaId != null &&
                int.tryParse(_epList.mediaId!) != null)
            ? _epList.mediaId
            : _animeSearchMatchCache[searchCacheKey];
        if (altMatchId == null) {
          final altSearch = await altProvider
              .getSearch(
                cleanTitle.isNotEmpty ? cleanTitle : (_epList.animeTitle ?? ''),
                null,
                1,
              )
              .timeout(const Duration(seconds: 10));
          if (activeGeneration != _loadGeneration) return null;

          final bestMatches = getBestMatches(
            results: altSearch.results,
            title: _epList.animeTitle ?? cleanTitle,
            nameSelector: (r) => r.name,
            idSelector: (r) => r.id,
            minThreshold: 0.55,
          );
          altMatchId = bestMatches.firstOrNull?.result.id;
          if (altMatchId != null) {
            _animeSearchMatchCache[searchCacheKey] = altMatchId;
          }
        }
        if (altMatchId == null) return null;

        String resolvedEpId = ep.number?.toString() ?? targetEpId;
        if (altProvider.providerName != 'justanime') {
          try {
            final episodeCacheKey = '$altKey:$altMatchId';
            var altEpsList = _animeEpisodesCache[episodeCacheKey];
            if (altEpsList == null) {
              final altEps = await altProvider
                  .getEpisodes(altMatchId)
                  .timeout(const Duration(seconds: 5));
              if (activeGeneration != _loadGeneration) return null;
              altEpsList = altEps.episodes;
              if (altEpsList != null) {
                _animeEpisodesCache[episodeCacheKey] = altEpsList;
              }
            }
            final targetEp = altEpsList?.firstWhereOrNull(
              (e) => e.number == ep.number,
            );
            resolvedEpId =
                targetEp?.id ??
                altEpsList?.firstOrNull?.id ??
                resolvedEpId;
          } catch (_) {}
        }

        if (activeGeneration != _loadGeneration) return null;
        final altSources = await altProvider
            .getSources(
              altMatchId,
              resolvedEpId,
              null,
              category,
            )
            .timeout(const Duration(seconds: 12));
        if (activeGeneration != _loadGeneration) return null;
        if (altSources.sources.isNotEmpty) {
          AppLogger.success('Provider $altKey found sources!');
          return altSources;
        }
      } catch (e) {
        AppLogger.d('Provider $altKey stream failed: $e');
      }
      return null;
    }

    // 1. If JustAnime is the active provider, strictly prioritize JustAnime
    // and never let unselected fallbacks preempt it.
    if (currentKey == 'justanime' && registry.has('justanime')) {
      final justResult = await resolveFromKey('justanime');
      if (justResult != null && justResult.sources.isNotEmpty) {
        return justResult;
      }
    }

    // 2. Fallback order for remaining candidates
    final candidateKeys = [
      if (registry.has('justanime') && currentKey != 'justanime') 'justanime',
      ...registry.keys.where((k) => k != currentKey && k != 'justanime'),
    ];

    if (candidateKeys.isEmpty) return null;
    final result = Completer<BaseSourcesModel?>();
    var completed = 0;

    for (final altKey in candidateKeys) {
      () async {
        final res = await resolveFromKey(altKey);
        if (res != null && res.sources.isNotEmpty && !result.isCompleted) {
          result.complete(res);
        }
        completed++;
        if (completed == candidateKeys.length && !result.isCompleted) {
          result.complete(null);
        }
      }().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          completed++;
          if (completed == candidateKeys.length && !result.isCompleted) {
            result.complete(null);
          }
        },
      );
    }

    return result.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
  }

  Future<List<Map<String, dynamic>>> _getQualities(
    Source src,
    Map<String, String>? headers,
  ) async {
    if (src.url == null) return [];
    if (!src.isM3U8) {
      return [
        {'quality': src.quality ?? 'Default', 'url': src.url},
      ];
    }

    try {
      AppLogger.d('Extracting M3U8 qualities...');
      return await extractor.extractQualities(src.url!, headers ?? {}, true);
    } catch (e, stack) {
      AppLogger.e(
        'Quality extraction failed, falling back to default',
        e,
        stack,
      );
      return [
        {'quality': src.quality ?? 'Default', 'url': src.url},
      ];
    }
  }

  void _showLoading(BuildContext context) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  void _showSnack(
    BuildContext context,
    String msg, {
    bool showDownloadsAction = false,
    String? downloadId,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content:
            showDownloadsAction
                ? Row(
                  children: [
                    Expanded(child: Text(msg)),
                    TextButton(
                      onPressed: () {
                        messenger.hideCurrentSnackBar();
                        routerConfig.go('/downloads');
                      },
                      child: const Text('View Downloads'),
                    ),
                  ],
                )
                : Text(msg),
        behavior: SnackBarBehavior.floating,
        action:
            showDownloadsAction
                ? SnackBarAction(
                  label: downloadId == null ? 'View Downloads' : 'Cancel',
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    if (downloadId == null) {
                      routerConfig.go('/downloads');
                    } else {
                      ref
                          .read(downloadsProvider.notifier)
                          .cancelDownload(downloadId);
                    }
                  },
                )
                : null,
      ),
    );
  }

  Future<ServerData?> _showServerSheet(
    BuildContext context,
    List<ServerData> servers,
  ) {
    return showModalBottomSheet<ServerData>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Server',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: servers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = servers[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        s.id ?? 'unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          s.name?.isNotEmpty == true ? Text(s.name!) : null,
                      trailing: Badge(
                        label: Text(s.isDub ? 'DUB' : 'SUB'),
                        backgroundColor:
                            s.isDub
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.primary,
                      ),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
