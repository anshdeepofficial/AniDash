import 'package:ani_dash/core/models/settings/player_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('online player buffer policy', () {
    test('new installs genuinely default to English dub', () {
      expect(PlayerModel().preferredAudioLanguage, 'dub');
      expect(PlayerModel.fromMap({}).preferredAudioLanguage, 'dub');
    });

    test('an explicit Japanese sub preference is preserved', () {
      expect(
        PlayerModel.fromMap({
          'preferredAudioLanguage': 'sub',
        }).preferredAudioLanguage,
        'sub',
      );
    });

    test('new installs use a 100 MiB cache capacity', () {
      expect(PlayerModel().bufferSize, 100);
    });

    test('legacy small cache settings migrate to 100 MiB', () {
      expect(PlayerModel.fromMap({'bufferSize': 32}).bufferSize, 100);
    });

    test('custom cache is retained within the supported range', () {
      expect(PlayerModel.fromMap({'bufferSize': 160}).bufferSize, 160);
      expect(PlayerModel.fromMap({'bufferSize': 512}).bufferSize, 256);
    });
  });
}
