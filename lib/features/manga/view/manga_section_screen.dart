import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/features/manga/utils/manga_helpers.dart';
import 'manga_details_screen.dart';

class MangaSectionScreen extends StatefulWidget {
  final String title;
  final List<DMedia> mangaList;
  final Source mangaSource;

  const MangaSectionScreen({
    super.key,
    required this.title,
    required this.mangaList,
    required this.mangaSource,
  });

  @override
  State<MangaSectionScreen> createState() => _MangaSectionScreenState();
}

class _MangaSectionScreenState extends State<MangaSectionScreen> {
  final TextEditingController _filterController = TextEditingController();
  List<DMedia> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = widget.mangaList;
    _filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    final query = _filterController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredList = widget.mangaList;
      } else {
        _filteredList = widget.mangaList.where((m) {
          final title = (m.title ?? '').toLowerCase();
          final author = (m.author ?? '').toLowerCase();
          return title.contains(query) || author.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: 'Filter ${widget.title.toLowerCase()}...',
                prefixIcon: const Icon(Iconsax.search_normal, size: 18),
                suffixIcon: _filterController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _filterController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.book, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No manga found',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      final isAdult = isMangaAdult(item, source: widget.mangaSource);

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MangaDetailsScreen(
                                manga: item,
                                mangaSource: widget.mangaSource,
                              ),
                            ),
                          );
                        },
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
                                    if (isAdult)
                                      Positioned(
                                        top: 5,
                                        left: 5,
                                        child: build18PlusBadge(fontSize: 9),
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
                  ),
          ),
        ],
      ),
    );
  }
}
