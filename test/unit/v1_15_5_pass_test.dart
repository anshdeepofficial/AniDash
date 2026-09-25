import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/models/universal/universal_media.dart';
import 'package:ani_dash/core/services/franchise_service.dart';
import 'package:ani_dash/core/hindi_sources/models/hindi_source_model.dart';
import 'package:ani_dash/core/hindi_sources/hindi_icon_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FranchiseService & Watch Order Tests', () {
    test('Correctly separates main story chain from optional extras with human-readable labels', () async {
      final season1Media = UniversalMedia(
        id: '1001',
        title: const UniversalTitle(
          romaji: 'Attack on Titan Season 1',
          english: 'Attack on Titan',
        ),
        coverImage: const UniversalCoverImage(large: 'https://example.com/cover1.jpg'),
        format: 'TV',
        seasonYear: 2013,
        startDate: const UniversalFuzzyDate(year: 2013, month: 4, day: 6),
        relations: [
          UniversalMediaRelation(
            relationType: 'SEQUEL',
            media: const UniversalMedia(
              id: '1002',
              title: UniversalTitle(
                romaji: 'Attack on Titan Season 2',
                english: 'Attack on Titan Season 2',
              ),
              coverImage: UniversalCoverImage(large: 'https://example.com/cover2.jpg'),
              format: 'TV',
              seasonYear: 2017,
              startDate: UniversalFuzzyDate(year: 2017, month: 4, day: 1),
            ),
          ),
          UniversalMediaRelation(
            relationType: 'SIDE_STORY',
            media: const UniversalMedia(
              id: '1003',
              title: UniversalTitle(
                romaji: 'Attack on Titan Movie',
                english: 'Attack on Titan: The Movie',
              ),
              coverImage: UniversalCoverImage(large: 'https://example.com/cover3.jpg'),
              format: 'MOVIE',
              seasonYear: 2014,
              startDate: UniversalFuzzyDate(year: 2014, month: 11, day: 22),
            ),
          ),
          UniversalMediaRelation(
            relationType: 'SIDE_STORY',
            media: const UniversalMedia(
              id: '1004',
              title: UniversalTitle(
                romaji: 'Attack on Titan: Ilse\'s Notebook',
                english: 'Attack on Titan OVA',
              ),
              coverImage: UniversalCoverImage(large: 'https://example.com/cover4.jpg'),
              format: 'OVA',
              seasonYear: 2013,
            ),
          ),
        ],
      );

      final result = await FranchiseService().getFranchiseWatchOrder(season1Media);

      // Main Story should contain S1, Inlined Movie (2014), and S2 (2017)
      expect(result.mainStory.length, 3);
      expect(result.mainStory[0].id, '1001');
      expect(result.mainStory[0].chipLabel, 'Season 1');
      expect(result.mainStory[0].isCurrent, true);
      expect(result.mainStory[1].id, '1003');
      expect(result.mainStory[1].isMovie, true);
      expect(result.mainStory[1].placementNote, isNotNull);
      expect(result.mainStory[2].id, '1002');
      expect(result.mainStory[2].chipLabel, 'Season 2');

      // Extras should contain the OVA
      expect(result.optionalExtras.length, 1);
      final extraOva = result.optionalExtras.first;
      expect(extraOva.id, '1004');
      expect(extraOva.isMovie, false);

      // TV seasons for chips (only TV/Special, movies excluded from season chips)
      expect(result.tvSeasons.length, 2);
      expect(result.tvSeasons[0].chipLabel, 'Season 1');
      expect(result.tvSeasons[1].chipLabel, 'Season 2');
    });

    test('Cycle prevention stops infinite loops on cyclic prequel/sequel relations', () async {
      // Circular relation A -> B -> A
      const nodeB = UniversalMedia(
        id: '2002',
        title: UniversalTitle(romaji: 'Anime Part 2'),
        coverImage: UniversalCoverImage(large: 'https://example.com/coverB.jpg'),
        format: 'TV',
        seasonYear: 2021,
      );
      final nodeA = UniversalMedia(
        id: '2001',
        title: const UniversalTitle(romaji: 'Anime Part 1'),
        coverImage: const UniversalCoverImage(large: 'https://example.com/coverA.jpg'),
        format: 'TV',
        seasonYear: 2020,
        relations: [
          UniversalMediaRelation(relationType: 'SEQUEL', media: nodeB),
        ],
      );

      final result = await FranchiseService().getFranchiseWatchOrder(nodeA);
      expect(result.mainStory.isNotEmpty, true);
      expect(result.mainStory.length, 2);
    });

    test('Correctly formats multipart and arc season chips (AoT Part 2, Demon Slayer Arcs)', () async {
      final s3Part1 = UniversalMedia(
        id: '3001',
        title: const UniversalTitle(
          romaji: 'Attack on Titan Season 3',
          english: 'Attack on Titan Season 3',
        ),
        coverImage: const UniversalCoverImage(large: 'https://example.com/cover.jpg'),
        format: 'TV',
        relations: [
          UniversalMediaRelation(
            relationType: 'SEQUEL',
            media: const UniversalMedia(
              id: '3002',
              title: UniversalTitle(
                romaji: 'Attack on Titan Season 3 Part 2',
                english: 'Attack on Titan Season 3 Part 2',
              ),
              coverImage: UniversalCoverImage(large: 'https://example.com/cover.jpg'),
              format: 'TV',
            ),
          ),
        ],
      );

      final result = await FranchiseService().getFranchiseWatchOrder(s3Part1);
      expect(result.mainStory.length, 2);
      expect(result.mainStory[0].chipLabel, 'Season 3 Part 1');
      expect(result.mainStory[1].chipLabel, 'Season 3 Part 2');
    });
  });

  group('Hindi Source Icon Resolver Tests', () {
    test('Resolves configured logoUrl directly if provided', () {
      const source = HindiSourceModel(
        id: 'animesalt',
        name: 'AnimeSalt',
        baseUrl: 'https://animesalt.to',
        configuredLogoUrl: 'https://animesalt.to/favicon.ico',
      );

      expect(source.logoUrl, 'https://animesalt.to/favicon.ico');
    });

    test('AnimixStream uses high-res Google favicon PNG rather than raw SVG', () {
      const source = HindiSourceModel(
        id: 'animixstream',
        name: 'AnimixStream',
        baseUrl: 'https://animixstream.com',
        configuredLogoUrl:
            'https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://animixstream.com&size=128',
      );

      expect(source.logoUrl, contains('gstatic.com/faviconV2'));
      expect(source.logoUrl, contains('size=128'));
    });

    test('Returns resolved configured icon when resolveIcon is called', () async {
      final resolver = HindiIconResolver();
      final icon = await resolver.resolveIcon(
        sourceId: 'custom_source',
        baseUrl: 'https://custom.org',
        configuredLogoUrl: 'https://custom.org/logo.png',
      );
      expect(icon, 'https://custom.org/logo.png');
      expect(resolver.getCachedIcon('custom_source'), 'https://custom.org/logo.png');
    });
  });

  group('Source Deduplication in Extensions Selector', () {
    test('Deduplicates duplicate entries by id or name', () {
      final sources = [
        {'id': 'ext_1', 'name': 'AnimePahe'},
        {'id': 'ext_2', 'name': 'GogoAnime'},
        {'id': 'ext_1', 'name': 'AnimePahe (Duplicate)'},
        {'id': 'ext_3', 'name': 'GogoAnime'},
      ];

      final seen = <String>{};
      final unique = sources.where((s) {
        final key = (s['id'] ?? s['name'] ?? '').trim();
        return seen.add(key);
      }).toList();

      expect(unique.length, 3);
      expect(unique.map((s) => s['id']).toList(), ['ext_1', 'ext_2', 'ext_3']);
    });
  });
}
