import 'package:cached_network_image/cached_network_image.dart';
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

class HentaiScreen extends ConsumerStatefulWidget {
  const HentaiScreen({super.key});

  @override
  ConsumerState<HentaiScreen> createState() => _HentaiScreenState();
}

class _HentaiScreenState extends ConsumerState<HentaiScreen> {
  List<UniversalMedia> _matureAnime = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatureAnime();
  }

  Future<void> _loadMatureAnime() async {
    try {
      final repo = ref.read(anilistServiceProvider);
      final list = await repo.searchAnime(
        '',
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

  void _openAdultAnime(BuildContext context, UniversalMedia anime) {
    final source =
        ref.read(sourceProvider).installedAnimeExtensions.where((item) {
          final name = (item.name ?? '').toLowerCase();
          return item.isNsfw == true ||
              name.contains('hanime') ||
              name.contains('hentai');
        }).firstOrNull;
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Install an 18+ source from Manage before playing.',
          ),
          action: SnackBarAction(
            label: 'Manage',
            onPressed: () => context.push('/settings/extensions'),
          ),
        ),
      );
      return;
    }
    ref.read(experimentalProvider.notifier).toggleExtensions(true);
    ref.read(selectedProviderKeyProvider.notifier).clear();
    ref.read(sourceProvider.notifier).setActiveSource(source);
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
    final adultSourceCount =
        ref.watch(sourceProvider).installedAnimeExtensions.where((source) {
          final name = (source.name ?? '').toLowerCase();
          return source.isNsfw == true ||
              name.contains('hanime') ||
              name.contains('hentai');
        }).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: Row(
          children: [
            const Text('Hentai Hub'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          // 18+ Extensions Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '18+ Source Extensions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/settings/extensions'),
                icon: const Icon(Icons.extension_rounded, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_rounded),
              title: const Text('Private 18+ sources'),
              subtitle: Text(
                adultSourceCount == 0
                    ? 'Open Manage to install sources from the 18+ repository.'
                    : '$adultSourceCount adult sources ready',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/extensions'),
            ),
          ),
          const SizedBox(height: 12),

          // Pre-installed sources recommendation cards
          if (adultSourceCount == -1)
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
            '18+ Anime Catalog',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoading)
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
}
