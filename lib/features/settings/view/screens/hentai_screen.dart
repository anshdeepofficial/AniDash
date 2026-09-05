import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/features/browse/model/search_filter.dart';
import 'package:ani_dash/shared/providers/anime_repo_provider.dart';
import 'package:ani_dash/shared/providers/incognito_provider.dart';

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
      final repo = ref.read(animeRepositoryProvider);
      final list = await repo.searchAnime(
        '',
        page: 1,
        perPage: 30,
        filter: const SearchFilter(genres: ['Hentai']),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlobalIncognito = ref.watch(global18PlusIncognitoProvider);
    final globalIncognitoNotifier =
        ref.read(global18PlusIncognitoProvider.notifier);

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
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Global Incognito Toggle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade900.withValues(alpha: 0.6),
                  colorScheme.surfaceContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isGlobalIncognito
                    ? Colors.purpleAccent
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isGlobalIncognito ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isGlobalIncognito
                        ? Colors.purpleAccent.withValues(alpha: 0.2)
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGlobalIncognito
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: isGlobalIncognito
                        ? Colors.purpleAccent
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Global 18+ Incognito',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Never save watch progress or history for any 18+ anime.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isGlobalIncognito,
                  activeColor: Colors.purpleAccent,
                  onChanged: (val) => globalIncognitoNotifier.set(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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

          // Pre-installed sources recommendation cards
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.pink.shade700,
                    child: const Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Hanime.tv'),
                  subtitle: const Text('Yuzono 18+ Repository • HD Streaming'),
                  trailing: const Chip(
                    label: Text('Available', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onTap: () => context.push('/settings/extensions'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade700,
                    child: const Text('HH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('HentaiHaven'),
                  subtitle: const Text('Yuzono 18+ Repository • Uncensored & Dub'),
                  trailing: const Chip(
                    label: Text('Available', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onTap: () => context.push('/settings/extensions'),
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
                    Icon(Icons.movie_outlined, size: 48, color: colorScheme.outline),
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
                  onTap: () => context.push('/details/', extra: anime),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
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
