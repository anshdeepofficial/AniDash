import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/shared/ui/cards/anime/anime_card_components.dart';
import 'package:flutter_test/flutter_test.dart';

UniversalMedia media(String title, {String format = 'TV'}) => UniversalMedia(
  id: title,
  title: UniversalTitle(english: title),
  coverImage: const UniversalCoverImage(),
  format: format,
);

void main() {
  group('anime season badges', () {
    test('defaults a TV series to season one', () {
      expect(animeSeasonBadge(media('SPY x FAMILY')), 'S1');
    });

    test('labels split cours and explicit seasons', () {
      expect(animeSeasonBadge(media('SPY x FAMILY Part 2')), 'S1-2');
      expect(animeSeasonBadge(media('SPY x FAMILY Season 2')), 'S2');
      expect(animeSeasonBadge(media('Example Season 3 Part 2')), 'S3-2');
    });

    test('presents movies with a compact M badge', () {
      expect(
        animeSeasonBadge(media('SPY x FAMILY CODE: White', format: 'MOVIE')),
        'M',
      );
    });

    test('provides stable franchise ordering', () {
      final entries = [
        media('Example Season 3'),
        media('Example Part 2'),
        media('Example'),
        media('Example Season 2'),
      ]..sort((a, b) => animeSeasonSortKey(a).compareTo(animeSeasonSortKey(b)));

      expect(entries.map(animeSeasonBadge), ['S1', 'S1-2', 'S2', 'S3']);
    });
  });

  group('card media type labels', () {
    test('leaves movie metadata to the dedicated M badge', () {
      final movie = media(
        'Kaiju No. 8 Mission Recon',
        format: 'MOVIE',
      ).copyWith(episodes: 1);

      expect(formatEpisodeText(anime: movie), isNull);
      expect(formatEpisodeText(anime: movie, compact: true), isNull);
    });
  });
}
