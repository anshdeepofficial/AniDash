import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/models/manga/manga_reading_progress_model.dart';
import 'package:ani_dash/core/repositories/manga_reading_progress_repository.dart';
import 'package:ani_dash/features/manga/utils/manga_helpers.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final DEpisode chapter;
  final String mangaTitle;
  final Source mangaSource;
  final DMedia? manga;
  final String? mangaCover;
  final String? mangaUrl;
  final int initialPage;
  final bool isAdult;

  const MangaReaderScreen({
    super.key,
    required this.chapter,
    required this.mangaTitle,
    required this.mangaSource,
    this.manga,
    this.mangaCover,
    this.mangaUrl,
    this.initialPage = 1,
    this.isAdult = false,
  });

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  List<PageUrl> _pages = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
    _scrollController.addListener(_onScroll);
    _loadPages();
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_pages.isEmpty || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final current = _scrollController.position.pixels;
    final fraction = (current / max).clamp(0.0, 1.0);
    final page = (fraction * (_pages.length - 1)).round() + 1;
    if (page != _currentPage && page >= 1 && page <= _pages.length) {
      setState(() {
        _currentPage = page;
      });
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    if (_pages.isEmpty) return;
    try {
      final url = widget.manga?.url ?? widget.mangaUrl ?? widget.mangaTitle;
      final isAdultContent = widget.isAdult ||
          (widget.manga != null &&
              isMangaAdult(widget.manga!, source: widget.mangaSource));

      final entry = MangaReadingProgressEntry(
        mangaUrl: url,
        mangaTitle: widget.manga?.title ?? widget.mangaTitle,
        mangaCover: widget.manga?.cover ?? widget.mangaCover,
        sourceId: widget.mangaSource.id,
        sourceName: widget.mangaSource.name,
        chapterUrl: widget.chapter.url,
        chapterTitle: widget.chapter.name ??
            'Chapter ${widget.chapter.episodeNumber}',
        chapterNumber: widget.chapter.episodeNumber,
        pageIndex: _currentPage,
        totalPages: _pages.length,
        lastReadTime: DateTime.now(),
        isAdult: isAdultContent,
        isCompleted: _currentPage >= _pages.length,
        mangaJson: widget.manga?.toJson(),
        chapterJson: widget.chapter.toJson(),
      );

      await ref
          .read(mangaReadingProgressRepositoryProvider)
          .saveProgress(entry);
    } catch (_) {}
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pages = await widget.mangaSource.methods
          .getPageList(widget.chapter)
          .timeout(const Duration(seconds: 25));

      if (mounted) {
        setState(() {
          _pages = pages;
          _isLoading = false;
        });

        // If resuming a page, jump to it after layout
        if (widget.initialPage > 1 && pages.length > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients &&
                _scrollController.position.maxScrollExtent > 0) {
              final targetFraction =
                  (widget.initialPage - 1) / (pages.length - 1);
              final targetOffset = targetFraction *
                  _scrollController.position.maxScrollExtent;
              _scrollController.jumpTo(
                targetOffset.clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                ),
              );
            }
          });
        }
        _saveProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load chapter pages: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdult = widget.isAdult ||
        (widget.manga != null &&
            isMangaAdult(widget.manga!, source: widget.mangaSource));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Manga Viewer
          GestureDetector(
            onTap: _toggleControls,
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading chapter...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadPages,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.5,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _pages.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final page = _pages[index];
                            return CachedNetworkImage(
                              imageUrl: page.url,
                              httpHeaders: page.headers,
                              fit: BoxFit.fitWidth,
                              placeholder: (context, url) => Container(
                                height: 400,
                                color: Colors.grey[900],
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white60,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Page ${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 280,
                                color: Colors.grey[900],
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.broken_image,
                                        color: Colors.redAccent,
                                        size: 36,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load page ${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Top App Bar Controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top,
                left: 8,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.chapter.name ??
                                    'Chapter ${widget.chapter.episodeNumber}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAdult) ...[
                              const SizedBox(width: 8),
                              build18PlusBadge(fontSize: 9),
                            ],
                          ],
                        ),
                        Text(
                          widget.mangaTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_pages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_currentPage / ${_pages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Floating Page Pill
          if (_pages.isNotEmpty && !_isLoading)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      'Page $_currentPage of ${_pages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
