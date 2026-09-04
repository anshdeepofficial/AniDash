// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/models/universal/universal_news.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';

import 'package:ani_dash/main.dart';
import 'package:ani_dash/core/models/anime/page_model.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/core/models/universal/universal_page_response.dart';
import 'package:ani_dash/core/repositories/watch_progress_repository.dart';
import 'package:ani_dash/features/home/model/home_section.dart';
import 'package:ani_dash/shared/providers/settings/home_layout_notifier.dart';
import 'package:ani_dash/features/home/view/widget/continue_section.dart';
import 'package:ani_dash/features/home/view_model/homepage_notifier.dart';
import 'package:ani_dash/features/home/view/widget/header_section.dart';
import 'package:ani_dash/features/home/view/widget/home_section.dart';
import 'package:ani_dash/features/home/view/widget/spotlight_section.dart';
import 'package:ani_dash/features/browse/view/section_screen.dart';
import 'package:ani_dash/shared/providers/anime_repo_provider.dart';
import 'package:ani_dash/features/news/view_model/news_provider.dart';
import 'package:ani_dash/features/watchlist/view_model/watchlist_notifier.dart';
import 'package:ani_dash/shared/auth/providers/auth_notifier.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final ProviderSubscription<AsyncValue<List<UniversalNews>>>
  _newsListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNewsListener();
    Future.microtask(_syncAccountWatchProgress);
  }

  void _setupNewsListener() {
    _newsListener = ref.listenManual(newsProvider, (previous, next) {
      if (previous is AsyncData && next is AsyncData) {
        if (!mounted) return;
        final router = GoRouter.of(context);
        final String currentLocation =
            router.routerDelegate.currentConfiguration.last.matchedLocation;
        const mainTabs = {'/', '/browse', '/downloads', '/watchlist'};

        if (!mainTabs.contains(currentLocation)) return;

        final oldList = previous?.value ?? [];
        final newList = next.value ?? [];
        final oldUrls = oldList.map((e) => e.url).toSet();
        final newItems =
            newList.where((e) => !oldUrls.contains(e.url)).toList();

        if (newItems.isNotEmpty) {
          final count = newItems.length;
          final message =
              count == 1
                  ? 'New Article: ${newItems.first.title ?? "Check it out!"}'
                  : '$count New Articles Available!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              action: SnackBarAction(
                label: 'VIEW',
                onPressed: () => context.push('/news'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _newsListener.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // let background tasks know if we're actually looking at the app
  Future<void> _setAppOpenStatus(bool isOpen) async {
    await sharedPrefs.setBool('is_app_open', isOpen);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isOpen = state == AppLifecycleState.resumed;
    _setAppOpenStatus(isOpen);
    if (isOpen) {
      _syncAccountWatchProgress();
    }
  }

  Future<void> _syncAccountWatchProgress() async {
    try {
      final auth = ref.read(authProvider);
      if (!auth.isAniListAuthenticated && !auth.isMalAuthenticated) return;

      final repo = ref.read(animeRepositoryProvider);
      final response = await repo.getUserAnimeList(
        type: 'ANIME',
        status: 'CURRENT',
        page: 1,
        perPage: 50,
      );

      if (response.data.isEmpty) return;

      final progressRepo = ref.read(watchProgressRepositoryProvider);

      for (final entry in response.data) {
        final media = entry.media;
        final mediaId = media.id;
        final targetProgress = entry.progress;

        if (targetProgress <= 0) continue;

        final local = progressRepo.getProgress(mediaId);

        if (local != null && local.currentEpisode >= targetProgress) {
          continue;
        }

        final episodesMap =
            Map<int, EpisodeProgress>.from(local?.episodesProgress ?? {});

        for (int i = 1; i <= targetProgress; i++) {
          final existing = episodesMap[i];
          if (existing == null || !existing.isCompleted) {
            episodesMap[i] = EpisodeProgress(
              episodeNumber: i,
              episodeTitle: existing?.episodeTitle ?? 'Episode $i',
              episodeThumbnail: existing?.episodeThumbnail,
              progressInSeconds: existing?.progressInSeconds ?? 1440,
              durationInSeconds: existing?.durationInSeconds ?? 1440,
              isCompleted: true,
              watchedAt: existing?.watchedAt ?? DateTime.now(),
            );
          }
        }

        final title = media.title.english ??
            media.title.romaji ??
            media.title.native ??
            '';
        final cover =
            media.coverImage.large ?? media.coverImage.medium ?? '';

        final updated = (local ??
                AnimeWatchProgressEntry(
                  animeId: mediaId,
                  animeTitle: title,
                  animeFormat: media.format,
                  animeCover: cover,
                  totalEpisodes: media.episodes ?? 0,
                  episodesProgress: episodesMap,
                  lastUpdated: DateTime.now(),
                  currentEpisode: targetProgress,
                  status: 'watching',
                ))
            .copyWith(
              episodesProgress: episodesMap,
              currentEpisode: targetProgress,
              lastUpdated: DateTime.now(),
              status: 'watching',
              animeTitle: title.isNotEmpty ? title : null,
              animeCover: cover.isNotEmpty ? cover : null,
            );

        await progressRepo.saveProgress(updated);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homepageProvider);
    final layout = ref.watch(homeLayoutProvider);
    final sections = layout.where((s) => s.enabled).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(homepageProvider.notifier).fetchHomePage(),
            _syncAccountWatchProgress(),
          ]);
        },
        child: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: sections.length + 2,
              itemBuilder: (context, index) {
                if (index == 0)
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: HeaderSection(isDesktop: false),
                  );

                if (state.isLoading)
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                if (state.error != null)
                  return Center(child: Text('Error: ${state.error}'));

                final home = state.homePage;
                if (home == null) return const SizedBox.shrink();

                // bottom spacer so the nav bar doesn't choke the content
                if (index == sections.length + 1)
                  return const SizedBox(height: 80);

                return _HomeSectionRenderer(
                  section: sections[index - 1],
                  home: home,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

//  handles the switching logic so the main build isn't a mess
class _HomeSectionRenderer extends ConsumerWidget {
  final HomeSection section;
  final HomePage home;

  const _HomeSectionRenderer({required this.section, required this.home});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (section.type) {
      case HomeSectionType.spotlight:
        if (home.trendingAnime.data.isEmpty) return const SizedBox.shrink();
        return SpotlightSection(spotlightAnime: home.trendingAnime.data);

      case HomeSectionType.continueWatching:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: _ContinueWatchingSection(),
        );

      case HomeSectionType.standard:
        final mediaResponse = _getStandardMedia(section.dataId, home);
        if (mediaResponse == null || mediaResponse.data.isEmpty)
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: HomeSectionWidget(
            title: section.title,
            mediaList: mediaResponse.data,
            onTitleTap: () {
              final repo = ref.read(animeRepositoryProvider);
              final fetcher = switch (section.dataId) {
                'trending' => repo.getTrendingAnime,
                'popular' => repo.getPopularAnime,
                'top_rated' => repo.getTopRatedAnime,
                'recently_updated' => repo.getRecentlyUpdatedAnime,
                'upcoming' => repo.getUpcomingAnime,
                'most_favorite' => repo.getMostFavoriteAnime,
                _ => null,
              };
              if (fetcher != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => SectionScreen(
                          title: section.title,
                          fetchItems: fetcher,
                        ),
                  ),
                );
              }
            },
          ),
        );

      case HomeSectionType.watchlist:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _WatchlistHomeSection(
            title: section.title,
            status: section.dataId!,
          ),
        );
    }
  }

  // mapping the dynamic data IDs to the actual home page lists
  UniversalPageResponse<UniversalMedia>? _getStandardMedia(
    String? id,
    HomePage home,
  ) {
    return switch (id) {
      'trending' => home.trendingAnime,
      'popular' => home.popularAnime,
      'most_favorite' => home.mostFavoriteAnime,
      'most_watched' => home.mostWatchedAnime,
      'top_rated' => home.topRatedAnime,
      'recently_updated' => home.recentlyUpdated,
      'upcoming' => home.upcomingAnime,
      _ => null,
    };
  }
}

class _WatchlistHomeSection extends ConsumerStatefulWidget {
  final String title;
  final String status;

  const _WatchlistHomeSection({required this.title, required this.status});

  @override
  ConsumerState<_WatchlistHomeSection> createState() =>
      _WatchlistHomeSectionState();
}

class _WatchlistHomeSectionState extends ConsumerState<_WatchlistHomeSection> {
  @override
  void initState() {
    super.initState();
    _fetchListIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _WatchlistHomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _fetchListIfNeeded();
    }
  }

  void _fetchListIfNeeded() {
    final state = ref.read(watchlistProvider);
    final list = state.listFor(widget.status);

    if (list.isEmpty && !state.loadingStatuses.contains(widget.status)) {
      ref.read(watchlistProvider.notifier).fetchListForStatus(widget.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(
      watchlistProvider.select((state) => state.listFor(widget.status)),
    );

    if (list.isEmpty) {
      return const SizedBox.shrink();
    }

    return HomeSectionWidget(
      title: widget.title,
      mediaList: list.map((e) => e.media).toList(),
    );
  }
}

final sortedWatchProgressProvider =
    Provider<AsyncValue<List<AnimeWatchProgressEntry>>>((ref) {
      return ref.watch(watchProgressStreamProvider).whenData((list) {
        if (list.isEmpty) return [];
        return list.whereType<AnimeWatchProgressEntry>().toList()..sort(
          (a, b) => (b.lastUpdated ?? DateTime(0)).compareTo(
            a.lastUpdated ?? DateTime(0),
          ),
        );
      });
    });

class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sortedWatchProgressProvider)
        .when(
          data: (sorted) {
            if (sorted.isEmpty) return const SizedBox.shrink();
            return ContinueSection(allProgress: sorted.take(15).toList());
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}
