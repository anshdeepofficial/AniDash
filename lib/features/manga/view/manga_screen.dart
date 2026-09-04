import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  List<DMedia> _mangaList = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPopularManga();
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

  Future<void> _loadPopularManga([String query = 'One Piece']) async {
    final source = _getActiveMangaSource();
    if (source == null) {
      setState(() {
        _error = 'No Manga extension installed yet.\nPlease install MangaDex or wait a few moments.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pages = await source.methods.search(query, 1, []).timeout(
        const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _mangaList = pages.list;
          _isLoading = false;
          if (_mangaList.isEmpty) {
            _error = 'No manga found for "$query"';
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

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty) {
        _loadPopularManga(query.trim());
      } else {
        _loadPopularManga('One Piece');
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
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Manga Source',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  ...installedManga.map((src) {
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
                        _loadPopularManga(_searchController.text.isNotEmpty ? _searchController.text : 'One Piece');
                      },
                    );
                  }),
              ],
            ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manga', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: const Icon(Iconsax.book, size: 16),
              label: Text(
                activeSource?.name ?? 'No Source',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showSourceSelector(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search manga (e.g. One Piece, Naruto, Solo Leveling)...',
              leading: const Icon(Iconsax.search_normal),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _loadPopularManga('One Piece');
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
          Expanded(
            child: _isLoading
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
                              ElevatedButton.icon(
                                onPressed: () => _loadPopularManga(
                                  _searchController.text.isNotEmpty ? _searchController.text : 'One Piece',
                                ),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _mangaList.length,
                        itemBuilder: (context, index) {
                          final item = _mangaList[index];
                          return InkWell(
                            onTap: () {
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
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: item.cover ?? '',
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: colorScheme.surfaceContainerHighest,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: colorScheme.surfaceContainerHighest,
                                        child: const Icon(Iconsax.book, size: 30),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.title ?? 'Unknown',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
