import 'package:cached_network_image/cached_network_image.dart';


import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'manga_reader_screen.dart';

class MangaDetailsScreen extends StatefulWidget {
  final DMedia manga;
  final Source mangaSource;

  const MangaDetailsScreen({
    super.key,
    required this.manga,
    required this.mangaSource,
  });

  @override
  State<MangaDetailsScreen> createState() => _MangaDetailsScreenState();
}

class _MangaDetailsScreenState extends State<MangaDetailsScreen> {
  DMedia? _detailedManga;
  bool _isLoading = true;
  String? _error;
  bool _isReversed = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await widget.mangaSource.methods
          .getDetail(widget.manga)
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _detailedManga = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detailedManga = widget.manga;
          _error = 'Could not load full chapter list: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final manga = _detailedManga ?? widget.manga;
    final chapters = manga.episodes ?? [];
    final displayedChapters = _isReversed ? chapters.reversed.toList() : chapters;

    return Scaffold(
      appBar: AppBar(
        title: Text(manga.title ?? 'Manga Details'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _loadDetails,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: manga.cover ?? '',
                                width: 110,
                                height: 160,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 110,
                                  height: 160,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Icon(Iconsax.book, size: 40),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    manga.title ?? 'Untitled',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (manga.author?.isNotEmpty == true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Author: ${manga.author}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.mangaSource.name ?? 'Manga Source',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${chapters.length} Chapters',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (manga.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          Text(
                            manga.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chapters (${chapters.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isReversed ? Iconsax.arrow_up_3 : Iconsax.arrow_down_1,
                                size: 20,
                              ),
                              tooltip: _isReversed ? 'Show First to Last' : 'Show Last to First',
                              onPressed: () => setState(() => _isReversed = !_isReversed),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (displayedChapters.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _error ?? 'No chapters found for this manga',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final chapter = displayedChapters[index];
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            chapter.name ?? 'Chapter ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: chapter.dateUpload?.isNotEmpty == true
                              ? Text(chapter.dateUpload!)
                              : null,
                          trailing: const Icon(Iconsax.arrow_right_3, size: 18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MangaReaderScreen(
                                  chapter: chapter,
                                  mangaTitle: manga.title ?? 'Manga',
                                  mangaSource: widget.mangaSource,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: displayedChapters.length,
                    ),
                  ),
              ],
            ),
    );
  }
}
