import 'package:ani_dash/features/watch/view_model/player/player_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video fit modes keep the requested tap-cycle order', () {
    expect(VideoFitMode.values, const [
      VideoFitMode.fitScreen,
      VideoFitMode.fill,
      VideoFitMode.ratio16x9,
      VideoFitMode.ratio4x3,
      VideoFitMode.center,
      VideoFitMode.bestFit,
    ]);
    expect(VideoFitMode.values.map((mode) => mode.label), const [
      'Fit Screen',
      'Fill',
      '16:9',
      '4:3',
      'Center',
      'Best Fit',
    ]);
  });
}
