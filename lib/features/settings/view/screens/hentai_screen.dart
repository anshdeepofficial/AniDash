import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/features/browse/model/search_filter.dart';
import 'package:ani_dash/shared/providers/anilist_service_provider.dart';
import 'package:ani_dash/shared/providers/incognito_provider.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:ani_dash/features/manga/view/manga_details_screen.dart';
import 'package:ani_dash/main.dart';

class HentaiScreen extends ConsumerStatefulWidget {
  const HentaiScreen({super.key});

  @override
  ConsumerState<HentaiScreen> createState() => _HentaiScreenState();
}

class _HentaiScreenState extends ConsumerState<HentaiScreen> {
  List<UniversalMedia> _matureAnime = [];
  bool _isLoading = true;
  bool _showSearch = false;
  bool _showManga = false;
  final _searchController = TextEditingController();
  List<DMedia> _adultManga = [];
  Source? _adultMangaSource;
  bool _isMangaLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMatureAnime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAdultContentWarning();
    });
  }

  Future<void> _showAdultContentWarning() async {
    const preferenceKey = 'adult_hub_warning_accepted';
    if (!mounted || (sharedPrefs.getBool(preferenceKey) ?? false)) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 42,
              ),
              title: const Text('Adult Content Warning'),
              content: const Text(
                'This section contains mature 18+ anime and manga. By continuing, you confirm that you understand this warning and are permitted to view adult content in your region.',
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    await sharedPrefs.setBool(preferenceKey, true);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('OK, Enter'),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _loadMatureAnime([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(anilistServiceProvider);
      final list = await repo.searchAnime(
        query.trim(),
        page: 1,
        perPage: 30,
        filter: const SearchFilter(isAdult: true, sort: 'POPULARITY_DESC'),
      );
      if (mounted) {
        setState(() {
          _matureAnime = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Source>> _installedAdultSources() async {
    final sources = <Source>[
      ...ref.read(sourceProvider).installedAnimeExtensions,
    ];
    try {
      sources.addAll(
        await ExtensionType.aniyomi.getManager().getInstalledAnimeExtensions(),
      );
    } catch (_) {}
    final unique = <String, Source>{};
    for (final source in sources) {
      final name = (source.name ?? '').toLowerCase();
      if (source.isNsfw == true ||
          name.contains('hanime') ||
          name.contains('hentai')) {
        unique[source.id ?? source.name ?? name] = source;
      }
    }
    return unique.values.toList();
  }

  Future<void> _loadAdultManga([String query = '']) async {
    setState(() => _isMangaLoading = true);
    try {
      final manager = ExtensionType.aniyomi.getManager();
      final installed = await manager.getInstalledMangaExtensions();
      final source = installed.firstWhereOrNull((item) {
        final name = (item.name ?? '').toLowerCase();
        return item.isNsfw == true ||
            name.contains('hentai') ||
            name.contains('adult');
      });
      final pages =
          source == null
              ? null
              : query.trim().isEmpty
              ? await source.methods.getPopular(1)
              : await source.methods.search(query.trim(), 1, const []);
      if (mounted) {
        setState(() {
          _adultMangaSource = source;
          _adultManga = pages?.list ?? [];
          _isMangaLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isMangaLoading = false);
    }
  }

  Future<void> _openAdultAnime(
    BuildContext context,
    UniversalMedia anime,
  ) async {
    final source = (await _installedAdultSources()).firstOrNull;
    if (source != null) {
      ref.read(experimentalProvider.notifier).toggleExtensions(true);
      ref.read(selectedProviderKeyProvider.notifier).clear();
      ref.read(sourceProvider.notifier).setActiveSource(source);
    }
    if (!context.mounted) return;
    context.push('/details?hentaiHub=true', extra: anime);
  }

  Future<void> _openLogin(
    BuildContext context,
    String sourceName,
    String loginUrl,
  ) async {
    try {
      await launchUrl(
        Uri.parse(loginUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $sourceName login page'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openPreferences(BuildContext context, String sourceName) {
    final normalized = sourceName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final source =
        ref
            .read(sourceProvider)
            .installedAnimeExtensions
            .where(
              (item) =>
                  (item.name ?? '').toLowerCase().replaceAll(
                    RegExp(r'[^a-z0-9]'),
                    '',
                  ) ==
                  normalized,
            )
            .firstOrNull;
    if (source == null) {
      context.push('/settings/extensions');
      return;
    }
    context.push('/settings/extensions/extension-preference', extra: source);
  }

  void _openSourceOptions(
    BuildContext context,
    String sourceName,
    String loginUrl,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: Text('Login to $sourceName Account'),
                  subtitle: const Text(
                    'Open official website to log into your account',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openLogin(context, sourceName, loginUrl);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.extension_rounded),
                  title: const Text('Extension Preferences'),
                  subtitle: const Text('Configure sources and credentials'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPreferences(context, sourceName);
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlobalIncognito = ref.watch(global18PlusIncognitoProvider);
    final globalIncognitoNotifier = ref.read(
      global18PlusIncognitoProvider.notifier,
    );
    ref.watch(sourceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title:
            _showSearch
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search 18+ anime',
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted:
                      (query) =>
                          _showManga
                              ? _loadAdultManga(query)
                              : _loadMatureAnime(query),
                )
                : Row(
                  children: [
                    const Text('Hentai Hub'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '18+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
        actions: [
          IconButton(
            tooltip: '18+ Anime & Manga sources',
            icon: const Icon(Icons.extension_rounded),
            onPressed:
                () => context.push('/settings/extensions?adultOnly=true'),
          ),
          IconButton(
            tooltip: _showSearch ? 'Close search' : 'Search',
            icon: Icon(_showSearch ? Icons.close : Iconsax.search_normal_1),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch && _searchController.text.isNotEmpty) {
                _searchController.clear();
                _loadMatureAnime();
              }
            },
          ),
          IconButton(
            tooltip:
                isGlobalIncognito
                    ? '18+ Incognito Active'
                    : '18+ Incognito Inactive',
            icon: Icon(
              isGlobalIncognito
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: isGlobalIncognito ? Colors.purpleAccent : null,
            ),
            onPressed: () {
              globalIncognitoNotifier.toggle();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    !isGlobalIncognito
                        ? '18+ Incognito enabled: History and progress will not be saved'
                        : '18+ Incognito disabled',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.movie_outlined),
                label: Text('Anime'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.menu_book_rounded),
                label: Text('Manga'),
              ),
            ],
            selected: {_showManga},
            onSelectionChanged: (value) {
              final manga = value.first;
              setState(() => _showManga = manga);
              if (manga && _adultManga.isEmpty) _loadAdultManga();
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Source>>(
            future: _installedAdultSources(),
            builder: (context, snapshot) {
              if ((snapshot.data?.isNotEmpty ?? false)) {
                return const SizedBox.shrink();
              }
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.extension_rounded),
                  title: const Text('Set up private 18+ sources'),
                  subtitle: const Text(
                    'Install one source to enable episode playback.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/extensions'),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Pre-installed sources recommendation cards
          if (ModalRoute.of(context)?.settings.name == '__legacy_sources__')
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink.shade700,
                      child: const Text(
                        'H',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: const Text('Hanime.tv'),
                    subtitle: const Text(
                      'Yuzono 18+ Repository • HD Streaming',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.greenAccent.shade400,
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Pre-installed',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.login_rounded, size: 20),
                          tooltip: 'Account / Login',
                          onPressed:
                              () => _openLogin(
                                context,
                                'Hanime.tv',
                                'https://hanime.tv/login',
                              ),
                        ),
                      ],
                    ),
                    onTap:
                        () => _openSourceOptions(
                          context,
                          'Hanime.tv',
                          'https://hanime.tv/login',
                        ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade700,
                      child: const Text(
                        'HH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: const Text('HentaiHaven'),
                    subtitle: const Text(
                      'Yuzono 18+ Repository • Uncensored & Dub',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.greenAccent.shade400,
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Pre-installed',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.login_rounded, size: 20),
                          tooltip: 'Account / Login',
                          onPressed:
                              () => _openLogin(
                                context,
                                'HentaiHaven',
                                'https://hentaihaven.xxx/login',
                              ),
                        ),
                      ],
                    ),
                    onTap:
                        () => _openSourceOptions(
                          context,
                          'HentaiHaven',
                          'https://hentaihaven.xxx/login',
                        ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // 18+ Catalog
          Text(
            _showManga ? '18+ Manga Catalog' : '18+ Anime Catalog',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          if (_showManga)
            _buildMangaCatalog(context, colorScheme)
          else if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_matureAnime.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.movie_outlined,
                      size: 48,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    const Text('No mature anime found right now.'),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _matureAnime.length,
              itemBuilder: (context, index) {
                final anime = _matureAnime[index];
                final coverUrl =
                    anime.coverImage.large ?? anime.coverImage.medium ?? '';
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openAdultAnime(context, anime),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, _, _) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.movie),
                              ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 6,
                          right: 6,
                          child: Text(
                            anime.title.english ?? anime.title.romaji ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '18+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMangaCatalog(BuildContext context, ColorScheme colorScheme) {
    if (_isMangaLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_adultMangaSource == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.extension_rounded),
          title: const Text('Adult Manga repository is ready'),
          subtitle: const Text(
            'Open Hub Sources and choose a manga source to load its catalog.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/settings/extensions?adultOnly=true'),
        ),
      );
    }
    if (_adultManga.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No adult manga found from this source.')),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _adultManga.length,
      itemBuilder: (context, index) {
        final manga = _adultManga[index];
        return InkWell(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => MangaDetailsScreen(
                        manga: manga,
                        mangaSource: _adultMangaSource!,
                      ),
                ),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: manga.cover ?? '',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget:
                        (_, _, _) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.menu_book)),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                manga.title ?? 'Unknown',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
