import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/core/services/anime_filler_service.dart';
import 'package:ani_dash/core/services/franchise_service.dart';

class WatchGuideBottomSheet extends StatefulWidget {
  final FranchiseWatchOrderItem item;
  final VoidCallback? onOpenDetails;

  const WatchGuideBottomSheet({
    super.key,
    required this.item,
    this.onOpenDetails,
  });

  static Future<void> show(
    BuildContext context, {
    required FranchiseWatchOrderItem item,
    VoidCallback? onOpenDetails,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WatchGuideBottomSheet(
        item: item,
        onOpenDetails: onOpenDetails,
      ),
    );
  }

  @override
  State<WatchGuideBottomSheet> createState() => _WatchGuideBottomSheetState();
}

class _WatchGuideBottomSheetState extends State<WatchGuideBottomSheet> {
  late Future<AnimeFillerInfo> _fillerFuture;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final altTitles = [
      item.media.title.english,
      item.media.title.romaji,
      item.media.title.userPreferred,
    ].whereType<String>().where((t) => t.isNotEmpty).toList();

    _fillerFuture = AnimeFillerService().getFillerInfo(
      title: item.displayTitle,
      malId: item.idMal,
      alternateTitles: altTitles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.coverImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.coverImage,
                        width: 70,
                        height: 100,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          width: 70,
                          height: 100,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Iconsax.video_play),
                        ),
                      )
                    : Container(
                        width: 70,
                        height: 100,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Iconsax.video_play),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isCurrent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CURRENT SELECTION',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      item.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (item.seasonNumber != null)
                          _buildBadge(
                            context,
                            'Season ${item.seasonNumber}',
                            colorScheme.primaryContainer,
                            colorScheme.onPrimaryContainer,
                          ),
                        if (item.format != null)
                          _buildBadge(
                            context,
                            item.format!,
                            colorScheme.surfaceContainerHighest,
                            colorScheme.onSurface,
                          ),
                        if (item.episodes != null && item.episodes! > 0)
                          _buildBadge(
                            context,
                            '${item.episodes} Episodes',
                            colorScheme.surfaceContainerHighest,
                            colorScheme.onSurface,
                          ),
                        if (item.year != null)
                          _buildBadge(
                            context,
                            '${item.year}',
                            colorScheme.surfaceContainerHighest,
                            colorScheme.onSurface,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Placement / Notes section
          if (item.placementNote != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.info_circle,
                    size: 18,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.placementNote!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Filler / Skip Guide section
          Text(
            'Filler & Skip Guide',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          FutureBuilder<AnimeFillerInfo>(
            future: _fillerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Checking verified filler data...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final fillerInfo = snapshot.data;
              final hasFillers = fillerInfo != null &&
                  (fillerInfo.fillers.isNotEmpty || fillerInfo.mixed.isNotEmpty);

              if (!hasFillers) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.shield_tick,
                        size: 18,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No verified filler/skip information available.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fillerInfo.fillers.isNotEmpty) ...[
                    _buildFillerRow(
                      context,
                      label: 'Filler (Can Skip):',
                      episodes: _formatRanges(fillerInfo.fillers),
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (fillerInfo.mixed.isNotEmpty) ...[
                    _buildFillerRow(
                      context,
                      label: 'Mixed Canon/Filler:',
                      episodes: _formatRanges(fillerInfo.mixed),
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildFillerRow(
                    context,
                    label: 'Canon (Must Watch):',
                    episodes: 'All remaining episodes',
                    color: Colors.green,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Action Button: Open Anime Details
          if (widget.onOpenDetails != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenDetails!();
                },
                icon: const Icon(Iconsax.info_circle, size: 20),
                label: const Text(
                  'Open Anime Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String text,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFillerRow(
    BuildContext context, {
    required String label,
    required String episodes,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          '$label ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            episodes,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRanges(Set<int> numbers) {
    if (numbers.isEmpty) return 'None';
    final sorted = numbers.toList()..sort();
    final ranges = <String>[];
    int? start;
    int? prev;

    for (final num in sorted) {
      if (start == null) {
        start = num;
        prev = num;
      } else if (num == prev! + 1) {
        prev = num;
      } else {
        ranges.add(start == prev ? '$start' : '$start–$prev');
        start = num;
        prev = num;
      }
    }

    if (start != null && prev != null) {
      ranges.add(start == prev ? '$start' : '$start–$prev');
    }

    return ranges.join(', ');
  }
}
