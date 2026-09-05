import 'package:ani_dash/core/utils/misc.dart';
import 'package:ani_dash/features/downloads/model/download_status.dart';

class DownloadItem {
  final String id;
  final String animeTitle;
  final String episodeTitle;
  final int episodeNumber;
  final String thumbnail;
  final int? size;
  final DownloadStatus state;
  final int progress;
  final String downloadUrl;
  final String quality;
  final String filePath;
  final Map<dynamic, dynamic> headers;
  final String? contentType;
  final List<dynamic>? subtitles;
  final int? totalSegments;
  final int? downloadedBytes;

  final int speed;
  final Duration? eta;
  final dynamic error;
  final bool isAdult;

  DownloadItem({
    String? id,
    this.quality = 'Default',
    required this.downloadUrl,
    required this.animeTitle,
    required this.episodeTitle,
    required this.episodeNumber,
    required this.thumbnail,
    this.size,
    required this.state,
    required this.progress,
    required this.filePath,
    this.headers = const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    },
    this.speed = 0,
    this.eta,
    this.contentType,
    this.error,
    this.subtitles,
    this.totalSegments,
    this.downloadedBytes,
    this.isAdult = false,
  }) : id = id ?? randomId();

  DownloadItem copyWith({
    String? id,
    String? animeTitle,
    String? episodeTitle,
    int? episodeNumber,
    String? thumbnail,
    int? size,
    DownloadStatus? state,
    int? progress,
    String? filePath,
    String? downloadUrl,
    String? quality,
    Map<dynamic, dynamic>? headers,
    int? speed,
    Duration? eta,
    dynamic error,
    String? contentType,
    int? totalSegments,
    int? downloadedBytes,
    List<dynamic>? subtitles,
    bool? isAdult,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      animeTitle: animeTitle ?? this.animeTitle,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      thumbnail: thumbnail ?? this.thumbnail,
      size: size ?? this.size,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      quality: quality ?? this.quality,
      headers: headers ?? this.headers,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      error: error ?? this.error,
      contentType: contentType ?? this.contentType,
      totalSegments: totalSegments ?? this.totalSegments,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      subtitles: subtitles ?? this.subtitles,
      isAdult: isAdult ?? this.isAdult,
    );
  }

  @override
  String toString() {
    return 'DownloadItem(id: $id, animeTitle: $animeTitle, episodeTitle: $episodeTitle, episodeNumber: $episodeNumber, state: $state, progress: $progress, speed: $speed)';
  }
}

extension DownloadItemLogic on DownloadItem {
  bool get isM3U8 =>
      contentType == 'video/MP2T' ||
      contentType == 'application/vnd.apple.mpegurl' ||
      contentType == 'application/x-mpegurl' ||
      downloadUrl.contains('.m3u8');

  bool get hasByteSize => size != null && size! > 0;
  bool get hasSegmentCount => totalSegments != null && totalSegments! > 0;
  bool get hasError => error != null;

  double get progressPercentage {
    if (hasByteSize) {
      return (progress / size!).clamp(0.0, 1.0);
    } else if (hasSegmentCount) {
      return (progress / totalSegments!).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String getProgressText() {
    if (hasByteSize) {
      final currentMB = (progress / 1024 / 1024).toStringAsFixed(1);
      final totalMB = (size! / 1024 / 1024).toStringAsFixed(1);
      return '$currentMB / $totalMB MB';
    } else if (downloadedBytes != null && downloadedBytes! > 0) {
      final currentMB = (downloadedBytes! / 1024 / 1024).toStringAsFixed(1);
      if (hasSegmentCount && progress > 0) {
        final estTotal = (downloadedBytes! / progress * totalSegments! / 1024 / 1024).toStringAsFixed(1);
        return '$currentMB / $estTotal MB';
      }
      return '$currentMB MB';
    } else if (hasSegmentCount) {
      final percent = ((progress / totalSegments!) * 100).toStringAsFixed(0);
      return '$percent%';
    }
    return 'Downloading...';
  }
}
