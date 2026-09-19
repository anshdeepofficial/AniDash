import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';

/// Checks whether a given [DMedia] manga contains adult / 18+ content.
bool isMangaAdult(DMedia manga, {Source? source}) {
  if (source?.isNsfw == true) return true;

  final sourceName = (source?.name ?? '').toLowerCase();
  final sourceId = (source?.id ?? '').toLowerCase();
  if (sourceName.contains('hentai') ||
      sourceName.contains('18+') ||
      sourceName.contains('adult') ||
      sourceId.contains('hentai') ||
      sourceId.contains('adult')) {
    return true;
  }

  final genres = manga.genre?.map((g) => g.toLowerCase().trim()).toSet() ?? {};
  const adultKeywords = {
    '18+',
    'hentai',
    'adult',
    'erotica',
    'smut',
    'ecchi',
    'mature',
    'pornographic',
    'nsfw',
    'doujinshi',
    'r-18',
    'yaoi',
    'yuri',
    'gore',
  };

  for (final keyword in adultKeywords) {
    if (genres.any((g) => g == keyword || g.contains(keyword))) {
      return true;
    }
  }

  final title = (manga.title ?? '').toLowerCase();
  if (title.contains('[18+]') ||
      title.contains('(18+)') ||
      title.contains(' 18+') ||
      title.contains('hentai')) {
    return true;
  }

  return false;
}

/// A standardized 18+ badge tag to display on manga cards and banners.
Widget build18PlusBadge({
  double fontSize = 10,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.red.shade900.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: Colors.redAccent.withValues(alpha: 0.9),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 4,
          offset: const Offset(0, 1.5),
        ),
      ],
    ),
    child: Text(
      '18+',
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ),
  );
}
