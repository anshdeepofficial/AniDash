import 'package:ani_dash/features/downloads/model/download_item.dart';
import 'package:ani_dash/features/downloads/model/download_status.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadItem _item({
  required int progress,
  int? size,
  int? totalSegments,
  int? downloadedBytes,
}) {
  return DownloadItem(
    downloadUrl: 'https://example.test/episode.m3u8',
    animeTitle: 'Example',
    episodeTitle: 'Episode 1',
    episodeNumber: 1,
    thumbnail: '',
    size: size,
    state: DownloadStatus.downloading,
    progress: progress,
    filePath: 'episode.ts',
    totalSegments: totalSegments,
    downloadedBytes: downloadedBytes,
  );
}

void main() {
  group('Download progress units', () {
    test('HLS percentage uses segment count and remains within 0-100', () {
      final item = _item(
        progress: 250,
        totalSegments: 500,
        downloadedBytes: 50 * 1024 * 1024,
        size: 100 * 1024 * 1024,
      );

      expect(item.progressPercentage, 0.5);
      expect(item.getProgressText(), contains('(50%)'));

      final overrun = item.copyWith(progress: 900);
      expect(overrun.progressPercentage, 1.0);
      expect(overrun.getProgressText(), contains('(100%)'));
    });

    test('direct files continue to use downloaded bytes', () {
      final item = _item(progress: 25, size: 100);
      expect(item.progressPercentage, 0.25);
    });
  });
}
