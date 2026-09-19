import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'manga_details_screen.dart';

class MangaScreen extends ConsumerStatefulWidget {
  const MangaScreen({super.key});

  @override
  ConsumerState<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends ConsumerState<MangaScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DMedia> _spotlightList = [];
  List<DMedia> _latestList = [];
  List<DMedia> _popularList = [];
  List<DMedia> _searchList = [];
  int _selectedTabIndex = 0; // 0: Latest Updates, 1: Popular
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMangaContent();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Source? _getActiveMangaSource() {
    final sourceState = ref.read(sourceProvider);
    return sourceState.activeMangaSource ??
        sourceState.installedMangaExtensions.firstOrNull;
  }

  Future<void> _loadMangaContent() async {
    final source = _getActiveMangaSource();
    if (source == null) {
      if (mounted) {
        setState(() {
          _error = 'No Manga extension installed yet.\nPlease install MangaDex or add a repository in settings.';
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Concurrently fetch latest updates and popular
      Pages? latestPages;
      Pages? popularPages;

      await Future.wait([
        source.methods
            .getLatestUpdates(1)
            .timeout(const Duration(seconds: 15))
            .then((res) {
              latestPages = res;
            })
            .catchError((_) {}),
        source.methods
            .getPopular(1)
            .timeout(const Duration(seconds: 15))
            .then((res) {
              popularPages = res;
            })
            .catchError((_) {}),
      ]);

      final latest = latestPages?.list ?? <DMedia>[];
      final popular = popularPages?.list ?? <DMedia>[];

      // Fallbacks if one is empty
      final finalLatest = latest.isNotEmpty ? latest : popular;
      final finalPopular = popular.isNotEmpty ? popular : latest;

      final spotlightCandidates = finalPopular.isNotEmpty ? finalPopular : finalLatest;
      final spotlight = spotlightCandidates.take(6).toList();

      if (mounted) {
        setState(() {
          _latestList = finalLatest;
          _popularList = finalPopular;
          _spotlightList = spotlight;
          _isLoading = false;
          if (_latestList.isEmpty && _popularList.isEmpty) {
            _error = 'No manga found from ${source.name ?? "this extension"}.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load manga: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchManga(String query) async {
    final source = _getActiveMangaSource();
    if (source == null || query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchList = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final pages = await source.methods.search(query.trim(), 1, []).timeout(
        const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _searchList = pages.list;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchList = [];
          _isSearching = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _searchManga(query.trim());
      } else {
        if (mounted) {
          setState(() {
            _searchList = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  void _showSourceSelector(BuildContext context) {
    final sourceState = ref.read(sourceProvider);
    final installedManga = sourceState.installedMangaExtensions;
    final activeSource = _getActiveMangaSource();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Manga Source',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/settings/extensions');
                        },
                        icon: const Icon(Icons.extension_outlined, size: 18),
                        label: const Text('Manage'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (installedManga.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('No Manga extensions installed yet.\nAuto-installing in background...'),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: installedManga.length,
                      itemBuilder: (context, i) {
                        final src = installedManga[i];
                        final isSelected = activeSource?.id == src.id;
                        return ListTile(
                          leading: const Icon(Iconsax.book),
                          title: Text(src.name ?? 'Unknown'),
                          subtitle: Text('v${src.version ?? '0.0.1'} • ${src.lang?.toUpperCase() ?? 'EN'}'),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            ref.read(sourceProvider.notifier).setActiveSource(src);
                            Navigator.pop(ctx);
                            _searchController.clear();
                            _searchList = [];
                            _loadMangaContent();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMangaDetails(DMedia item) {
    final activeSource = _getActiveMangaSource();
    if (activeSource != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MangaDetailsScreen(
            manga: item,
            mangaSource: activeSource,
          ),
        ),
      );
    }
  }

  Widget _buildSpotlightBanner(BuildContext context, ColorScheme colorScheme) {
    if (_spotlightList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: CarouselSlider.builder(
        options: CarouselOptions(
          height: 190,
          autoPlay: _spotlightList.length > 1,
          autoPlayInterval: const Duration(seconds: 6),
          enableInfiniteScroll: _spotlightList.length > 1,
          enlargeCenterPage: true,
          viewportFraction: 0.92,
          enlargeStrategy: CenterPageEnlargeStrategy.scale,
        ),
        itemCount: _spotlightList.length,
        itemBuilder: (context, index, realIndex) {
          final item = _spotlightList[index];
          return GestureDetector(
            onTap: () => _openMangaDetails(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Cover
                  if (item.cover != null && item.cover!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.cover!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Iconsax.book, size: 40),
                      ),
                    )
                  else
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Icon(Iconsax.book, size: 40),
                    ),

                  // Gradient Dark Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),

                  // Content Overlay
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Small poster thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 60,
                            height: 85,
                            child: CachedNetworkImage(
                              imageUrl: item.cover ?? '',
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.black45,
                                child: const Icon(Iconsax.book, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Titles and Read Button
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.title ?? 'Unknown Title',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              if (item.artist != null && item.artist!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _openMangaDetails(item),
                          icon: const Icon(Iconsax.book, size: 16),
                          label: const Text('Read'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMangaGrid(List<DMedia> list, ColorScheme colorScheme) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.book, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No manga items available',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return InkWell(
          onTap: () => _openMangaDetails(item),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.cover ?? '',
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Iconsax.book, size: 30),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 35,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title ?? 'Unknown',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeSource = _getActiveMangaSource();
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manga', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: const Icon(Iconsax.book, size: 16),
              label: Text(
                activeSource?.name ?? 'Select Source',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showSourceSelector(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search manga (e.g. Naruto, Bleach, Berserk)...',
              leading: const Icon(Iconsax.search_normal, size: 18),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchList = [];
                        _isSearching = false;
                      });
                    },
                  ),
              ],
              onChanged: _onSearchChanged,
              elevation: const WidgetStatePropertyAll(1.0),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: hasSearchQuery
                ? _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'No manga found for "${_searchController.text}"',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: Text(
                                    'Search Results (${_searchList.length})',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                _buildMangaGrid(_searchList, colorScheme),
                                const SizedBox(height: 30),
                              ],
                            ),
                          )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.book, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () => context.push('/settings/extensions'),
                                        icon: const Icon(Icons.extension_outlined),
                                        label: const Text('Install Extensions'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _loadMangaContent,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMangaContent,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Spotlight Section
                                  _buildSpotlightBanner(context, colorScheme),

                                  // Category / Tab Chips
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    child: Row(
                                      children: [
                                        ChoiceChip(
                                          avatar: const Icon(Iconsax.clock, size: 15),
                                          label: const Text('Latest Updates'),
                                          selected: _selectedTabIndex == 0,
                                          onSelected: (val) {
                                            if (val) setState(() => _selectedTabIndex = 0);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          avatar: const Icon(Iconsax.trend_up, size: 15),
                                          label: const Text('Popular'),
                                          selected: _selectedTabIndex == 1,
                                          onSelected: (val) {
                                            if (val) setState(() => _selectedTabIndex = 1);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Manga Grid for selected tab
                                  _buildMangaGrid(
                                    _selectedTabIndex == 0 ? _latestList : _popularList,
                                    colorScheme,
                                  ),
                                  const SizedBox(height: 60),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
