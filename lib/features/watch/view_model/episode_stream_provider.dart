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
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/features/watch/view/widgets/download_source_selector.dart';
import 'package:ani_dash/features/watch/view_model/episode_list_provider.dart';
import 'package:ani_dash/shared/providers/settings/download_settings_notifier.dart';
import 'package:ani_dash/core/models/settings/experimental_model.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/settings/player_notifier.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'package:ani_dash/core/utils/extractors.dart' as extractor;

part 'episode_stream_provider.g.dart';

enum EpisodeStreamState {
  SOURCE_LOADING,
  SUBTITLE_LOADING,
  SERVER_LOADING,
  QUALITY_LOADING,
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
    bool clearError = false,
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
    );
  }
}

@Riverpod(keepAlive: true)
class EpisodeData extends _$EpisodeData {
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

  @override
  EpisodeDataState build() => const EpisodeDataState();

  Future<void> loadEpisode({
    required int ep,
    bool play = true,
    Duration? startAt,
  }) async {
    if (!_isValidEp(ep)) {
      AppLogger.fail('Invalid episode requested: $ep');
      return;
    }

    AppLogger.section('Loading Episode $ep');
    state = state.copyWith(
      selectedEpisode: ep,
      addState: play ? EpisodeStreamState.SOURCE_LOADING : null,
      clearError: true,
    );

    // Server lists are useful for manual switching, but they must not hold the
    // first frame hostage. Give the preferred provider a short opportunity to
    // resolve them, then start source resolution while it finishes in background.
    if (state.servers.isNotEmpty && state.selectedServer != null) {
      _fetchServers(ep); // refresh in background
    } else {
      try {
        await _fetchServers(ep).timeout(const Duration(milliseconds: 2500));
      } on TimeoutException {
        AppLogger.d('Server discovery continuing in background');
      }
    }

    if (play) await _playCurrent(startAt ?? Duration.zero);
  }

  Future<void> changeEpisode(int? ep, {Duration? startAt, int by = 0}) async {
    final target = by != 0 ? (state.selectedEpisode ?? 1) + by : ep;
    if (target == null || !_isValidEp(target)) return;

    AppLogger.i('Changing to episode: $target');
    await loadEpisode(ep: target, play: true, startAt: startAt);
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
    AppLogger.infoPair('Changing Server', server.name ?? server.id);
    state = state.copyWith(selectedServer: server);
    await _playCurrent(ref.read(playerStateProvider).position);
  }

  Future<void> toggleDubSub() async {
    final current = state.selectedServer;
    final targetIsDub = !(current?.isDub ?? false);

    // 1. Try to find the matching server with the target dub status
    ServerData? alt = state.servers.firstWhereOrNull(
      (s) =>
          s.isDub == targetIsDub &&
          (s.id == current?.id || s.name == current?.name),
    );
    // 2. Otherwise find any server with the target dub status
    alt ??= state.servers.firstWhereOrNull((s) => s.isDub == targetIsDub);

    // 3. If no server in list has target dub status, synthesize or toggle the current one
    alt ??=
        (current != null)
            ? current.copyWith(isDub: targetIsDub)
            : ServerData(id: 'default', name: 'Default', isDub: targetIsDub);

    AppLogger.i(
      'Toggling Dub/Sub to: ${targetIsDub ? "DUB" : "SUB"} on server: ${alt.name ?? alt.id}',
    );
    await changeServer(alt);
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

    final link = ref.keepAlive();
    AppLogger.section('Initializing Download for Ep $epNum');

    try {
      _showLoading(context);
      final servers = await _getRawServers(ep);
      if (!context.mounted) return;
      Navigator.pop(context);

      ServerData? selected;
      if (!_isNativeProvider && _exp.useExtensions) {
        selected = ServerData(name: 'Extension', id: 'ext', isDub: false);
      } else {
        if (servers.isEmpty) {
          AppLogger.warning('No servers available for download');
          return _showSnack(context, "No servers found");
        }
        selected =
            servers.length == 1
                ? servers.first
                : await _showServerSheet(context, servers);
      }

      if (selected == null || !context.mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (c) => DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder:
                  (c, controller) => DownloadSourceSelector(
                    animeTitle: _epList.animeTitle ?? 'Unknown',
                    animeCover: _epList.animeCover,
                    episode: ep,
                    episodeCount: 1,
                    server: selected,
                    fetchSources: () => _fetchSourceData(ep, server: selected),
                    scrollController: controller,
                  ),
            ),
      );
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
      final data = await _fetchSourceData(ep);
      if (!context.mounted) return;
      Navigator.pop(context);

      if (data == null || data.sources.isEmpty) {
        return _showSnack(
          context,
          "No download sources available for Ep $epNum",
        );
      }

      Source? matchedSource;
      if (language == 'hindi') {
        matchedSource = data.sources.firstWhereOrNull(
          (s) =>
              s.quality?.toLowerCase().contains('hindi') == true ||
              s.url?.toLowerCase().contains('hindi') == true,
        );
      } else if (language == 'dub') {
        matchedSource = data.sources.firstWhereOrNull((s) => s.isDub);
      } else {
        matchedSource = data.sources.firstWhereOrNull((s) => !s.isDub);
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
        final data = await _fetchSourceData(ep);
        if (data == null || data.sources.isEmpty) {
          AppLogger.w('Batch download: No sources for Ep $epNum');
          continue;
        }

        Source? source;
        if (targetLang == 'hindi') {
          source = data.sources.firstWhereOrNull(
            (s) =>
                s.quality?.toLowerCase().contains('hindi') == true ||
                s.url?.toLowerCase().contains('hindi') == true,
          );
        } else if (targetLang == 'dub') {
          source = data.sources.firstWhereOrNull((s) => s.isDub);
        } else {
          source = data.sources.firstWhereOrNull((s) => !s.isDub);
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

  void reset() => state = const EpisodeDataState();

  bool _isValidEp(int ep) {
    if (_epList.episodes.isEmpty) {
      // Allow episode 1 for movies/single-episode media
      return ep == 1;
    }
    return _epList.episodes.any((i) => i.number == ep) || (ep == 1 && _epList.episodes.isEmpty);
  }

  Future<List<ServerData>> _getRawServers(EpisodeDataModel ep) async {
    if (!_isNativeProvider && _exp.useExtensions) {
      // Extensions extract their streams directly from the episode URL and
      // do not use native-provider server identifiers.
      return [ServerData(name: 'Extension', id: 'ext', isDub: false)];
    }

    return (await _provider?.getSupportedServers(
          metadata: {
            'id': _epList.animeId,
            'epNumber': ep.number,
            'epId': ep.id,
          },
        ))?.flatten() ??
        [];
  }

  Future<void> _fetchServers(int epNum) async {
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
      if (list.isEmpty) {
        list = [
          ServerData(name: "Default", id: "default", isDub: false),
          ServerData(name: "Default", id: "default", isDub: true),
        ];
      } else {
        final hasDub = list.any((s) => s.isDub);
        final hasSub = list.any((s) => !s.isDub);
        if (!hasDub && hasSub) {
          list = [...list, ...list.map((s) => s.copyWith(isDub: true))];
        }
      }

      final preferDub = ref.read(playerSettingsProvider).preferDub;
      final selected =
          list.firstWhereOrNull((s) => s.isDub == preferDub) ??
          list.firstOrNull;

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

  Future<void> _playCurrent(Duration startAt) async {
    final epNum = state.selectedEpisode;
    if (epNum == null) return;

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
      if (epNum == _prefetchedEpNum && _prefetchedSourceData != null) {
        AppLogger.success('⚡ Using pre-fetched stream data for Episode $epNum');
        data = _prefetchedSourceData;
        _prefetchedEpNum = null;
        _prefetchedSourceData = null;
      } else {
        data = await _fetchSourceData(
          epModel,
          server: state.selectedServer,
        ).timeout(const Duration(seconds: 15));
      }

      if (data == null || data.sources.isEmpty) {
        throw StateError('No playable sources found');
      }
      state = state.copyWith(
        sources: data.sources,
        subtitles: [Subtitle(lang: 'None'), ...data.tracks],
        headers: data.headers?.cast<String, String>(),
      );
      try {
        await _loadSourceStream(0, startAt: startAt);
      } catch (primaryError) {
        AppLogger.w('Primary stream stalled; trying another provider');
        final category = state.selectedServer?.isDub == true ? 'dub' : 'sub';
        final fallback = await _fetchFallbackNativeSourceData(
          epModel,
          category,
        );
        if (fallback == null || fallback.sources.isEmpty) rethrow;
        state = state.copyWith(
          sources: fallback.sources,
          subtitles: [Subtitle(lang: 'None'), ...fallback.tracks],
          headers: fallback.headers?.cast<String, String>(),
        );
        await _loadSourceStream(0, startAt: startAt);
      }
    } catch (e, stack) {
      AppLogger.e('Episode playback failed', e, stack);
      state = state.copyWith(
        error: 'Unable to play episode. Try another server.',
      );
    } finally {
      state = state.copyWith(removeState: EpisodeStreamState.SOURCE_LOADING);
    }
  }

  Future<void> _loadSourceStream(
    int sourceIdx, {
    required Duration startAt,
  }) async {
    if (sourceIdx < 0 || sourceIdx >= state.sources.length) return;

    state = state.copyWith(addState: EpisodeStreamState.QUALITY_LOADING);

    try {
      // Build quality options from ALL available sources
      final allQualities = <Map<String, dynamic>>[];

      // Check if the primary source is M3U8 (master playlist with multiple qualities)
      final primarySrc = state.sources[sourceIdx];
      final streamHeaders = {...?state.headers, ...?primarySrc.headers};

      if (primarySrc.isM3U8) {
        // Start with Auto/primary quality immediately so playback launches in 1-2s
        allQualities.add({
          'quality': primarySrc.quality ?? 'Auto',
          'url': primarySrc.url,
        });
      } else {
        // Non-M3U8 sources: each Source object IS a quality variant
        // Aggregate all sources that share the same dub/sub type
        for (final src in state.sources) {
          if (src.url != null && src.url!.isNotEmpty) {
            allQualities.add({
              'quality': src.quality ?? 'Default',
              'url': src.url,
            });
          }
        }

        // Deduplicate by URL
        final seen = <String>{};
        allQualities.retainWhere((q) {
          final url = q['url'] as String?;
          if (url == null || seen.contains(url)) return false;
          seen.add(url);
          return true;
        });

        // Sort: highest resolution first (e.g. 1080p > 720p > 480p)
        allQualities.sort((a, b) {
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
      }

      if (allQualities.isEmpty) {
        // Fallback: just use the primary source
        allQualities.add({
          'quality': primarySrc.quality ?? 'Default',
          'url': primarySrc.url,
        });
      }

      // Pick best match for preferred quality
      final prefQuality = ref.read(playerSettingsProvider).defaultQuality;
      int qIdx;
      if (prefQuality.toLowerCase() == 'auto' && !primarySrc.isM3U8) {
        // Direct files cannot adapt bitrate like HLS. Start Auto at a
        // network-safe resolution and leave higher qualities user-selectable.
        qIdx = allQualities.indexWhere(
          (q) => RegExp(r'(^|\D)480(\D|$)').hasMatch(q['quality'] as String),
        );
        if (qIdx == -1) {
          qIdx = allQualities.indexWhere(
            (q) => RegExp(r'(^|\D)360(\D|$)').hasMatch(q['quality'] as String),
          );
        }
        if (qIdx == -1 && allQualities.isNotEmpty) {
          qIdx = allQualities.length - 1;
        }
      } else {
        qIdx = allQualities.indexWhere(
          (q) => (q['quality'] as String).contains(prefQuality),
        );
      }
      if (qIdx == -1) qIdx = 0;

      AppLogger.d(
        'Opening stream: ${allQualities[qIdx]['quality']} '
        '(${allQualities.length} quality options available)',
      );

      await _player
          .open(
            allQualities[qIdx]['url'] as String,
            startAt,
            headers: streamHeaders,
          )
          .timeout(const Duration(seconds: 15));

      // Probe stream to detect startup, without blocking playback if buffering
      try {
        await Future.any([
          _player.videoController.player.stream.position.firstWhere(
            (position) => position > Duration.zero,
          ),
          _player.videoController.player.stream.duration.firstWhere(
            (duration) => duration > Duration.zero,
          ),
        ]).timeout(const Duration(milliseconds: 800));
      } catch (_) {
        AppLogger.d('Stream startup probe passed without blocking');
      }

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

      // In background, extract sub-qualities for M3U8 without delaying playback start
      if (primarySrc.isM3U8) {
        _getQualities(primarySrc, streamHeaders)
            .then((extracted) {
              if (extracted.isNotEmpty) {
                final merged = [
                  {'quality': 'Auto', 'url': primarySrc.url},
                  ...extracted,
                ];
                final seenUrls = <String>{};
                merged.retainWhere((m) {
                  final u = m['url'] as String?;
                  if (u == null || seenUrls.contains(u)) return false;
                  seenUrls.add(u);
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
  }) async {
    AppLogger.d(
      'Fetching source data via ${server?.name ?? "Extension"} (${server?.isDub == true ? "DUB" : "SUB"})',
    );
    final epTargetUrl =
        (ep.url != null && ep.url!.isNotEmpty) ? ep.url : (ep.id ?? '');
    if (!_isNativeProvider &&
        _exp.useExtensions &&
        epTargetUrl != null &&
        epTargetUrl.isNotEmpty) {
      try {
        final res = await _srcNotifier.getSources(
          DEpisode(episodeNumber: ep.number.toString(), url: epTargetUrl),
        );
        final isDubRequested = server?.isDub == true;
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

          return BaseSourcesModel(
            sources: sources,
            headers: extractedHeaders,
            tracks: allTracks,
          );
        }
      } catch (err) {
        AppLogger.e(
          'Extension source fetch failed, trying legacy provider: $err',
        );
      }
    }

    final category = server?.isDub == true ? 'dub' : 'sub';
    final targetEpId =
        (ep.id != null && ep.id!.isNotEmpty)
            ? ep.id!
            : (ep.number?.toString() ?? '');

    if (_provider != null) {
      try {
        final res = await _provider!
            .getSources(_epList.animeId ?? '', targetEpId, server?.id, category)
            .timeout(const Duration(seconds: 8));
        if (res.sources.isNotEmpty) {
          return res;
        }
      } catch (e) {
        AppLogger.e('Native provider direct source fetch failed: $e');
      }

      // If direct animeId failed (e.g. animeId was an AniList ID or URL), resolve by title
      if (_epList.animeTitle != null && _epList.animeTitle!.isNotEmpty) {
        try {
          AppLogger.w(
            'Resolving anime title on ${_provider!.providerName}: "${_epList.animeTitle}"',
          );
          final searchRes = await _provider!
              .getSearch(_epList.animeTitle!, null, 1)
              .timeout(const Duration(seconds: 6));
          final best = searchRes.results.firstOrNull;
          if (best != null && best.id != null && best.id != _epList.animeId) {
            final res = await _provider!
                .getSources(best.id!, targetEpId, server?.id, category)
                .timeout(const Duration(seconds: 8));
            if (res.sources.isNotEmpty) {
              AppLogger.success(
                'Resolved stream on ${_provider!.providerName}',
              );
              return res;
            }
          }
        } catch (e) {
          AppLogger.d('Title recovery on active provider failed: $e');
        }
      }
    }

    return _fetchFallbackNativeSourceData(ep, category);
  }

  Future<BaseSourcesModel?> _fetchFallbackNativeSourceData(
    EpisodeDataModel ep,
    String category,
  ) async {
    final registry = ref.read(animeSourceRegistryProvider);
    final currentKey = ref.read(selectedProviderKeyProvider);
    final targetEpId =
        (ep.id != null && ep.id!.isNotEmpty)
            ? ep.id!
            : (ep.number?.toString() ?? '1');

    // Fallback order: put JustAnime first because it has working HLS
    final candidateKeys = [
      if (registry.has('justanime') && currentKey != 'justanime') 'justanime',
      ...registry.keys.where((k) => k != currentKey && k != 'justanime'),
      if (registry.has('justanime') && currentKey == 'justanime') 'justanime',
    ];

    if (candidateKeys.isEmpty) return null;
    final result = Completer<BaseSourcesModel?>();
    var completed = 0;

    final cleanTitle = (_epList.animeTitle ?? '')
        .replaceAll(':', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final altKey in candidateKeys) {
      () async {
        try {
          final altProvider = registry.get(altKey);
          if (altProvider == null) return;
          AppLogger.w('Trying fallback provider for stream: $altKey');
          final altSearch = await altProvider.getSearch(
            cleanTitle.isNotEmpty ? cleanTitle : (_epList.animeTitle ?? ''),
            null,
            1,
          );
          final altMatch = altSearch.results.firstOrNull;
          if (altMatch == null || altMatch.id == null) return;
          final altEps = await altProvider.getEpisodes(altMatch.id!);
          final targetEp = altEps.episodes?.firstWhereOrNull(
            (e) => e.number == ep.number,
          );
          final resolvedEpId =
              targetEp?.id ?? altEps.episodes?.firstOrNull?.id ?? targetEpId;
          final altSources = await altProvider.getSources(
            altMatch.id!,
            resolvedEpId,
            null,
            category,
          );
          if (altSources.sources.isNotEmpty && !result.isCompleted) {
            AppLogger.success('Fallback provider $altKey found sources!');
            result.complete(altSources);
          }
        } catch (e) {
          AppLogger.d('Fallback $altKey stream failed: $e');
        } finally {
          completed++;
          if (completed == candidateKeys.length && !result.isCompleted) {
            result.complete(null);
          }
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
      const Duration(seconds: 12),
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
