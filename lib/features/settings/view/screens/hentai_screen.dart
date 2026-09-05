import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/data/hive/models/anime_watch_progress_model.dart';
import 'package:ani_dash/core/repositories/watch_progress_repository.dart';
import 'package:ani_dash/features/browse/model/search_filter.dart';
import 'package:ani_dash/shared/providers/anilist_service_provider.dart';
import 'package:ani_dash/shared/providers/incognito_provider.dart';
import 'package:ani_dash/shared/providers/settings/source_notifier.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/shared/providers/anime_source_provider.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:ani_dash/features/manga/view/manga_details_screen.dart';
import 'package:ani_dash/features/downloads/view/downloads_screen.dart';
import 'package:ani_dash/features/home/view/widget/spotlight_section.dart';
import 'package:ani_dash/features/home/view/widget/continue_section.dart';
import 'package:ani_dash/features/home/view/widget/home_section.dart';
import 'package:ani_dash/helpers/navigation.dart';
import 'package:ani_dash/main.dart';
import 'package:ani_dash/shared/providers/settings/security_notifier.dart';
import 'package:ani_dash/shared/ui/pin_lock_dialog.dart';

class HentaiScreen extends ConsumerStatefulWidget {
  const HentaiScreen({super.key});

  @override
  ConsumerState<HentaiScreen> createState() => _HentaiScreenState();
}

class _HentaiScreenState extends ConsumerState<HentaiScreen> {
  List<UniversalMedia> _trendingAnime = [];
  List<UniversalMedia> _topRatedAnime = [];
  List<UniversalMedia> _recentAnime = [];
  List<UniversalMedia> _searchAnime = [];
  bool _isLoading = true;
  bool _showSearch = false;
  bool _showManga = false;
  final _searchController = TextEditingController();
  int _exploreSortIndex = 0;
  List<DMedia> _adultManga = [];
  Source? _adultMangaSource;
  bool _isMangaLoading = false;

  @override
  void initState() {
    super.initState();
    final accepted = sharedPrefs.getBool('adult_hub_warning_accepted') ?? false;
    if (accepted) {
      _loadMatureAnime();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAdultContentWarning();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitHub() {
    ref.read(securityProvider.notifier).lockHentai();
    context.pop();
  }

  Future<void> _showAdultContentWarning() async {
    const preferenceKey = 'adult_hub_warning_accepted';
    if (!mounted || (sharedPrefs.getBool(preferenceKey) ?? false)) return;
    final confirmed = await showDialog<bool>(
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
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Exit'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('OK, Enter'),
                ),
              ],
            ),
          ),
    );

    if (confirmed == true) {
      await sharedPrefs.setBool(preferenceKey, true);
      if (mounted) _loadMatureAnime();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _loadMatureAnime([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(anilistServiceProvider);
      if (query.trim().isNotEmpty) {
        final results = await repo.searchAnime(
          query.trim(),
          page: 1,
          perPage: 30,
          filter: const SearchFilter(isAdult: true, sort: 'POPULARITY_DESC'),
        );
        if (mounted) {
          setState(() {
            _searchAnime = results;
            _isLoading = false;
          });
        }
        return;
      }

      final results = await Future.wait([
        repo.searchAnime(
          '',
          page: 1,
          perPage: 20,
          filter: const SearchFilter(isAdult: true, sort: 'POPULARITY_DESC'),
        ),
        repo.searchAnime(
          '',
          page: 1,
          perPage: 20,
          filter: const SearchFilter(isAdult: true, sort: 'SCORE_DESC'),
        ),
        repo.searchAnime(
          '',
          page: 1,
          perPage: 20,
          filter: const SearchFilter(isAdult: true, sort: 'START_DATE_DESC'),
        ),
      ]);

      if (mounted) {
        setState(() {
          _trendingAnime = results[0];
          _topRatedAnime = results[1];
          _recentAnime = results[2];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      final aniyomiManager = ExtensionType.aniyomi.getManager();
      final mangayomiManager = ExtensionType.mangayomi.getManager();
      final installed = [
        ...await aniyomiManager.getInstalledMangaExtensions(),
        ...await mangayomiManager.getInstalledMangaExtensions(),
        ...ref.read(sourceProvider).installedMangaExtensions,
      ];
      final unique = <String, Source>{};
      for (final s in installed) {
        unique[s.id ?? s.name ?? ''] = s;
      }
      final source = unique.values.firstWhereOrNull((item) {
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
    navigateToDetail(context, anime, 'hentai-${anime.id}', fromHentaiHub: true);
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
      context.push('/settings/extensions?adultOnly=true');
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

  void _navigateToCategory(String title, List<UniversalMedia> list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _CategoryViewScreen(
              title: title,
              animeList: list,
              onOpen: (anime) => _openAdultAnime(context, anime),
            ),
      ),
    );
  }

  void _showAccountBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final isIncognito = ref.watch(global18PlusIncognitoProvider);
            final activeSource = ref.watch(sourceProvider).activeAnimeSource;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle,
                          size: 28,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Hentai Hub Accounts & Settings',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Incognito Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        isIncognito
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: isIncognito ? Colors.purpleAccent : null,
                      ),
                      title: const Text('Incognito Mode'),
                      subtitle: const Text(
                        'Do not save watch history or progress for 18+ titles',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isIncognito,
                      onChanged: (val) {
                        ref
                            .read(global18PlusIncognitoProvider.notifier)
                            .toggle();
                      },
                    ),
                    const Divider(height: 20),
                    // Account Logins
                    Text(
                      'Account Management',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
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
                      title: const Text('Hanime.tv Account'),
                      subtitle: const Text(
                        'Log in to sync favorites & watchlists',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Login'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openLogin(
                            context,
                            'Hanime.tv',
                            'https://hanime.tv/login',
                          );
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
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
                      title: const Text('HentaiHaven Account'),
                      subtitle: const Text(
                        'Log in to sync favorites & library',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Login'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openLogin(
                            context,
                            'HentaiHaven',
                            'https://hentaihaven.xxx/login',
                          );
                        },
                      ),
                    ),
                    const Divider(height: 20),
                    // Active Source Selector
                    FutureBuilder<List<Source>>(
                      future: _installedAdultSources(),
                      builder: (context, snapshot) {
                        final sources = snapshot.data ?? [];
                        if (sources.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active 18+ Source',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children:
                                  sources.map((s) {
                                    final isSelected =
                                        activeSource?.id == s.id ||
                                        activeSource?.name == s.name;
                                    return ChoiceChip(
                                      label: Text(s.name ?? 'Source'),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          ref
                                              .read(sourceProvider.notifier)
                                              .setActiveSource(s);
                                        }
                                      },
                                    );
                                  }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    if (security.hentaiLockEnabled && !security.isHentaiUnlocked) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton.filledTonal(
            onPressed: () => context.pop(),
            icon: const Icon(Iconsax.arrow_left_2),
          ),
          title: const Text('Adult Hub Locked'),
        ),
        body: PinLockDialog(
          title: 'Adult Hub Locked',
          subtitle: 'Enter your 4-digit PIN to access this section',
          enableBiometrics: security.hentaiLockBiometrics,
          onBiometricSuccess: () {
            ref.read(securityProvider.notifier).unlockHentai();
          },
          onVerify: (pin) {
            return ref.read(securityProvider.notifier).verifyHentaiPin(pin);
          },
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ref.watch(sourceProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitHub();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton.filledTonal(
            onPressed: _exitHub,
            icon: const Icon(Iconsax.arrow_left_2),
          ),
          title:
              _showSearch
                  ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search 18+ anime & manga...',
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Hentai Hub', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
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
              tooltip: '18+ Downloads',
              icon: const Icon(Iconsax.document_download),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DownloadsScreen(isAdult: true),
                    ),
                  ),
            ),
            IconButton(
              tooltip: '18+ Sources & Extensions',
              icon: const Icon(Icons.extension_rounded),
              onPressed:
                  () => context.push('/settings/extensions?adultOnly=true'),
            ),
            IconButton(
              tooltip: _showSearch ? 'Close search' : 'Search',
              icon: Icon(_showSearch ? Icons.close : Iconsax.search_normal_1),
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchController.clear();
                  _searchAnime.clear();
                  _loadMatureAnime();
                }
              },
            ),
            IconButton(
              tooltip: 'Hub Accounts & Settings',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => _showAccountBottomSheet(context),
            ),
            const SizedBox(width: 4),
          ],
          forceMaterialTransparency: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (_showManga) {
              await _loadAdultManga(_searchController.text);
            } else {
              await _loadMatureAnime(_searchController.text);
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SegmentedButton<bool>(
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
              ),
              const SizedBox(height: 12),

              if (_showManga)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildMangaCatalog(context, colorScheme),
                )
              else if (_showSearch && _searchController.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildSearchGrid(context, colorScheme),
                )
              else if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Spotlight carousel banner
                if (_trendingAnime.isNotEmpty)
                  SpotlightSection(
                    spotlightAnime: _trendingAnime.take(10).toList(),
                  ),

                // Dedicated Hentai Hub Continue Watching section
                const _HentaiContinueWatchingSection(),

                // Horizontal Category Sections
                if (_trendingAnime.isNotEmpty)
                  HomeSectionWidget(
                    title: 'Trending 18+',
                    mediaList: _trendingAnime,
                    fromHentaiHub: true,
                    onTitleTap:
                        () =>
                            _navigateToCategory('Trending 18+', _trendingAnime),
                  ),

                if (_topRatedAnime.isNotEmpty)
                  HomeSectionWidget(
                    title: 'Top Rated 18+',
                    mediaList: _topRatedAnime,
                    fromHentaiHub: true,
                    onTitleTap:
                        () => _navigateToCategory(
                          'Top Rated 18+',
                          _topRatedAnime,
                        ),
                  ),

                if (_recentAnime.isNotEmpty)
                  HomeSectionWidget(
                    title: 'Recent Releases',
                    mediaList: _recentAnime,
                    fromHentaiHub: true,
                    onTitleTap:
                        () => _navigateToCategory(
                          'Recent Releases',
                          _recentAnime,
                        ),
                  ),

                // Explore All Catalog with Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    'Explore All 18+ Anime',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Popularity'),
                          selected: _exploreSortIndex == 0,
                          onSelected: (val) {
                            if (val) setState(() => _exploreSortIndex = 0);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Top Rated'),
                          selected: _exploreSortIndex == 1,
                          onSelected: (val) {
                            if (val) setState(() => _exploreSortIndex = 1);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Recent'),
                          selected: _exploreSortIndex == 2,
                          onSelected: (val) {
                            if (val) setState(() => _exploreSortIndex = 2);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildPreinstalledSourcesCard(context, colorScheme),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildAnimeGrid(
                    context,
                    colorScheme,
                    _exploreSortIndex == 1
                        ? _topRatedAnime
                        : _exploreSortIndex == 2
                        ? _recentAnime
                        : _trendingAnime,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreinstalledSourcesCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: Colors.amber.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fast Streaming & Login',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pre-configured high definition 18+ sources with quick account access.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildSourceItem(
              context: context,
              title: 'Hanime.tv',
              subtitle: 'Yuzono 18+ Repository • HD Streaming',
              avatarLetter: 'H',
              avatarBg: Colors.pink.shade700,
              loginUrl: 'https://hanime.tv/login',
            ),
            const Divider(height: 16),
            _buildSourceItem(
              context: context,
              title: 'HentaiHaven',
              subtitle: 'Yuzono 18+ Repository • Uncensored & Dub',
              avatarLetter: 'HH',
              avatarBg: Colors.purple.shade700,
              loginUrl: 'https://hentaihaven.xxx/login',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String avatarLetter,
    required Color avatarBg,
    required String loginUrl,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: avatarBg,
        child: Text(
          avatarLetter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            tooltip: 'Account Login',
            onPressed: () => _openLogin(context, title, loginUrl),
          ),
        ],
      ),
      onTap: () => _openSourceOptions(context, title, loginUrl),
    );
  }

  Widget _buildSearchGrid(BuildContext context, ColorScheme colorScheme) {
    if (_searchAnime.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 8),
              const Text('No 18+ content matched your search.'),
            ],
          ),
        ),
      );
    }
    return _buildAnimeGrid(context, colorScheme, _searchAnime);
  }

  Widget _buildAnimeGrid(
    BuildContext context,
    ColorScheme colorScheme,
    List<UniversalMedia> list,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final anime = list[index];
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

class _HentaiContinueWatchingSection extends ConsumerWidget {
  const _HentaiContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(watchProgressStreamProvider);

    return progressAsync.when(
      data: (list) {
        final adultEntries =
            list
                .whereType<AnimeWatchProgressEntry>()
                .where((e) => e.isAdult)
                .toList()
              ..sort(
                (a, b) => (b.lastUpdated ?? DateTime(0)).compareTo(
                  a.lastUpdated ?? DateTime(0),
                ),
              );

        if (adultEntries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: ContinueSection(
            allProgress: adultEntries.take(15).toList(),
            isAdult: true,
          ),
        );
      },
      loading: () {
        List<AnimeWatchProgressEntry> syncList = [];
        try {
          syncList =
              ref
                  .read(watchProgressRepositoryProvider)
                  .getAllProgress()
                  .where((e) => e.isAdult)
                  .toList()
                ..sort(
                  (a, b) => (b.lastUpdated ?? DateTime(0)).compareTo(
                    a.lastUpdated ?? DateTime(0),
                  ),
                );
        } catch (_) {}
        if (syncList.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ContinueSection(
              allProgress: syncList.take(15).toList(),
              isAdult: true,
            ),
          );
        }
        return const SizedBox.shrink();
      },
      error: (_, _) {
        List<AnimeWatchProgressEntry> syncList = [];
        try {
          syncList =
              ref
                  .read(watchProgressRepositoryProvider)
                  .getAllProgress()
                  .where((e) => e.isAdult)
                  .toList()
                ..sort(
                  (a, b) => (b.lastUpdated ?? DateTime(0)).compareTo(
                    a.lastUpdated ?? DateTime(0),
                  ),
                );
        } catch (_) {}
        if (syncList.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ContinueSection(
              allProgress: syncList.take(15).toList(),
              isAdult: true,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _CategoryViewScreen extends StatelessWidget {
  final String title;
  final List<UniversalMedia> animeList;
  final void Function(UniversalMedia anime) onOpen;

  const _CategoryViewScreen({
    required this.title,
    required this.animeList,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: Text(title),
        forceMaterialTransparency: true,
      ),
      body:
          animeList.isEmpty
              ? const Center(child: Text('No titles found'))
              : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: animeList.length,
                  itemBuilder: (context, index) {
                    final anime = animeList[index];
                    final coverUrl =
                        anime.coverImage.large ?? anime.coverImage.medium ?? '';
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onOpen(anime),
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
              ),
    );
  }
}
