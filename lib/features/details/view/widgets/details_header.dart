import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ani_dash/core/models/tracker/tracker_type.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/core/services/auth_provider_enum.dart';
import 'package:ani_dash/features/details/view/widgets/tracker/track_bottom_sheet.dart';
import 'package:ani_dash/features/watchlist/view_model/watchlist_notifier.dart';
import 'package:ani_dash/shared/auth/providers/auth_notifier.dart';
import 'package:ani_dash/shared/providers/tracker/media_tracker_notifier.dart';
import 'package:ani_dash/features/browse/view/section_screen.dart';
import 'package:ani_dash/features/browse/model/search_filter.dart';
import 'package:ani_dash/shared/providers/anime_repo_provider.dart';
import 'package:ani_dash/core/models/universal/universal_page_response.dart';
import 'package:ani_dash/shared/providers/incognito_provider.dart';

class DetailsHeader extends ConsumerStatefulWidget {
  final UniversalMedia anime;
  final String tag;

  const DetailsHeader({super.key, required this.anime, required this.tag});

  @override
  ConsumerState<DetailsHeader> createState() => _DetailsHeaderState();
}

class _DetailsHeaderState extends ConsumerState<DetailsHeader> {
  bool isFavorite = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  void _checkFavorite() {
    final auth = ref.read(authProvider);
    Future.microtask(() async {
      if (auth.isAniListAuthenticated) {
        final watchlist = ref.read(watchlistProvider.notifier);
        isFavorite = await watchlist.ensureFavorite(widget.anime.id);
      } else {
        isFavorite = await ref
            .read(mediaTrackerProvider(widget.anime.id).notifier)
            .isFavorite(widget.anime.id);
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> toggleFavorite() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final auth = ref.read(authProvider);
      if (auth.isAniListAuthenticated) {
        await ref.read(watchlistProvider.notifier).toggleFavorite(widget.anime);
        setState(() => isFavorite = !isFavorite);
      } else {
        final newStatus = await ref
            .read(mediaTrackerProvider(widget.anime.id).notifier)
            .toggleFavorite(widget.anime);
        setState(() => isFavorite = newStatus);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getHighResImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.contains('anilist.co')) {
      return url
          .replaceAll('/medium/', '/extraLarge/')
          .replaceAll('/large/', '/extraLarge/');
    }
    return url;
  }

  void _openFullscreenPoster(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Save to Gallery',
                onPressed: () async {
                  await _saveImageToGallery(context, imageUrl, title);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                placeholder: (_, _) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveImageToGallery(
    BuildContext context,
    String imageUrl,
    String animeTitle,
  ) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download image (HTTP ${response.statusCode})',
        );
      }

      Directory? targetDir;
      if (Platform.isAndroid) {
        final picturesDir = Directory('/storage/emulated/0/Pictures/AniDash');
        if (await picturesDir.exists()) {
          targetDir = picturesDir;
        } else {
          try {
            targetDir = await picturesDir.create(recursive: true);
          } catch (_) {
            targetDir = await getExternalStorageDirectory();
          }
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final sanitizedTitle =
          animeTitle.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim();
      final fileName =
          '${sanitizedTitle}_poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${targetDir!.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Poster saved to Pictures/AniDash/$fileName'),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade900,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save poster: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highResBanner = _getHighResImageUrl(
      widget.anime.bannerImage != null && widget.anime.bannerImage!.isNotEmpty
          ? widget.anime.bannerImage!
          : widget.anime.coverImage.large ?? widget.anime.coverImage.medium,
    );

    return SliverAppBar(
      expandedHeight: 420,
      pinned: false,
      floating: true,
      elevation: 0,
      backgroundColor: colorScheme.surfaceContainerLowest,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: highResBanner,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              placeholder:
                  (_, _) => Container(color: colorScheme.surfaceContainer),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    colorScheme.surfaceContainerLowest,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      final posterUrl = _getHighResImageUrl(
                        widget.anime.coverImage.large ??
                            widget.anime.coverImage.medium,
                      );
                      if (posterUrl.isNotEmpty) {
                        _openFullscreenPoster(
                          context,
                          posterUrl,
                          widget.anime.title.english ??
                              widget.anime.title.romaji ??
                              'Poster',
                        );
                      }
                    },
                    child: Hero(
                      tag: widget.tag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CachedNetworkImage(
                              imageUrl:
                                  widget.anime.coverImage.large ??
                                  widget.anime.coverImage.medium ??
                                  '',
                              width: 105,
                              height: 160,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.anime.title.english ??
                              widget.anime.title.romaji ??
                              '',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.anime.title.native != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.anime.title.native!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (widget.anime.isMature) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '18+  MATURE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(
                                            Icons.explicit_rounded,
                                            color: Colors.pinkAccent,
                                          ),
                                          SizedBox(width: 8),
                                          Text('18+ Content Notice'),
                                        ],
                                      ),
                                      content: const Text(
                                        'This anime contains mature / 18+ content. You can manage 18+ extensions (Hanime, HentaiHaven) and enable Global Incognito under:\n\nSettings > Experimental Features > Hentai Hub',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Close'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            context.push(
                                              '/settings/experimental/hentai',
                                            );
                                          },
                                          child: const Text('Open Hentai Hub'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.help_outline_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              ),
                              _IncognitoToggleBadge(mediaId: widget.anime.id),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Metadata Row
                        Row(
                          children: [
                            if (widget.anime.averageScore != null) ...[
                              Icon(
                                Iconsax.star1,
                                color: theme.colorScheme.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (widget.anime.averageScore! / 10)
                                    .toStringAsFixed(1),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                [
                                  widget.anime.seasonYear?.toString(),
                                  widget.anime.format,
                                  widget.anime.episodes != null
                                      ? '${widget.anime.episodes} eps'
                                      : null,
                                  widget.anime.status,
                                ].whereType<String>().join(' • '),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GenreTags(genres: widget.anime.genres),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_1, color: Colors.white, size: 30),
        onPressed: () => context.pop(),
      ),
      actions: [
        TrackerStatusWidget(anime: widget.anime),
        const SizedBox(width: 4),
        isLoading
            ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
            : IconButton(
              icon: Icon(
                isFavorite ? Iconsax.heart5 : Iconsax.heart,
                color: Colors.white,
                size: 30,
              ),
              tooltip:
                  isFavorite ? 'Remove from favourites' : 'Add to favourites',
              onPressed: toggleFavorite,
            ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Widget for displaying genre tags and status
class GenreTags extends StatelessWidget {
  final List<String> genres;

  const GenreTags({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            genres
                .map(
                  (genre) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GenreTag(text: genre),
                  ),
                )
                .toList(),
      ),
    );
  }
}

/// Individual tag widget for genres and status
class GenreTag extends ConsumerWidget {
  final String text;
  final Color? color;
  final bool isStatus;

  const GenreTag({
    super.key,
    required this.text,
    this.color,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        color != null
            ? color!.withValues(alpha: 0.25)
            : (isDark
                ? Colors.black54
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.9));

    final textColor = color ?? (isDark ? Colors.white : colorScheme.onSurface);

    final tagContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              color?.withValues(alpha: 0.5) ??
              (isDark
                  ? Colors.white24
                  : colorScheme.outlineVariant.withValues(alpha: 0.6)),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (isStatus) return tagContainer;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => SectionScreen(
                  title: text,
                  fetchItems: ({page = 1, perPage = 25}) async {
                    final repo = ref.read(animeRepositoryProvider);
                    final list = await repo.searchAnime(
                      '',
                      page: page,
                      perPage: perPage,
                      filter: SearchFilter(genres: [text]),
                    );
                    return UniversalPageResponse(
                      pageInfo: UniversalPageInfo(
                        total: list.length,
                        perPage: perPage,
                        currentPage: page,
                        lastPage: list.length >= perPage ? page + 1 : page,
                        hasNextPage: list.length >= perPage,
                      ),
                      data: list,
                    );
                  },
                ),
          ),
        );
      },
      child: tagContainer,
    );
  }
}

class TrackerStatusWidget extends ConsumerWidget {
  final UniversalMedia anime;

  const TrackerStatusWidget({super.key, required this.anime});

  String _formatStatus(String status) {
    final clean = status.replaceAll('_', ' ').toLowerCase();
    return clean[0].toUpperCase() + clean.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackerState = ref.watch(mediaTrackerProvider(anime.id));
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final activePlatform = authState.activePlatform;
    final trackerType =
        activePlatform == AuthPlatform.anilist
            ? TrackerType.anilist
            : TrackerType.mal;

    final entry = trackerState.entries[trackerType];

    Widget content;
    bool isActive = false;

    if (trackerState.isLoading && !trackerState.remoteLoaded) {
      content = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (entry != null) {
      isActive = true;
      final statusText = _formatStatus(entry.status);
      final progressText = entry.progress > 0 ? ' ${entry.progress}' : '';
      final totalEps = anime.episodes != null ? '/${anime.episodes}' : '';
      final displayProgress =
          entry.progress > 0 ? '$progressText$totalEps' : '';

      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.bookmark_25, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '$statusText$displayProgress',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.add, size: 16, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            'Track',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () => TrackBottomSheet.show(context, anime),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// Floating watch button widget
class WatchButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const WatchButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final navHeight = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 16 + navHeight,
      left: 16,
      right: 16,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        label: Text(
          'Watch Now',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        icon:
            isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
                : const Icon(Iconsax.play_circle),
      ),
    );
  }
}

class _IncognitoToggleBadge extends ConsumerWidget {
  final String mediaId;

  const _IncognitoToggleBadge({required this.mediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncognito = ref.watch(incognitoProvider(mediaId));

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        ref.read(incognitoNotifierProvider.notifier).toggle(mediaId);
        final nowActive = !isIncognito;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: nowActive ? Colors.deepPurple.shade900 : Colors.grey.shade900,
            content: Row(
              children: [
                Icon(
                  nowActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: nowActive ? Colors.purpleAccent : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nowActive
                        ? '🕶️ Incognito Mode ON: No watch history or progress will be saved.'
                        : 'Incognito Mode OFF: Watch progress will be saved.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isIncognito
              ? Colors.purple.shade900.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isIncognito ? Colors.purpleAccent : Colors.white30,
            width: 1.0,
          ),
          boxShadow: isIncognito
              ? [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIncognito ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: isIncognito ? Colors.purpleAccent : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              isIncognito ? 'INCOGNITO: ON' : 'Incognito: OFF',
              style: TextStyle(
                color: isIncognito ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

