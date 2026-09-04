import 'package:cached_network_image/cached_network_image.dart';


import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';

class MangaReaderScreen extends StatefulWidget {
  final DEpisode chapter;
  final String mangaTitle;
  final Source mangaSource;

  const MangaReaderScreen({
    super.key,
    required this.chapter,
    required this.mangaTitle,
    required this.mangaSource,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  List<PageUrl> _pages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pages = await widget.mangaSource.methods
          .getPageList(widget.chapter)
          .timeout(const Duration(seconds: 20));

      if (mounted) {
        setState(() {
          _pages = pages;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapter.name ?? 'Chapter',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.mangaTitle,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_pages.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_pages.length} Pages',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading chapter...', style: TextStyle(color: Colors.white70)),
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
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
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
                    itemCount: _pages.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return CachedNetworkImage(
                        imageUrl: page.url,
                        httpHeaders: page.headers,
                        fit: BoxFit.fitWidth,
                        placeholder: (context, url) => Container(
                          height: 350,
                          color: Colors.grey[900],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(strokeWidth: 2),
                                const SizedBox(height: 8),
                                Text(
                                  'Page ${index + 1}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 250,
                          color: Colors.grey[900],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image, color: Colors.redAccent),
                                const SizedBox(height: 4),
                                Text(
                                  'Failed to load page ${index + 1}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
