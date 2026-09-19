import 'dart:convert';

class MangaReadingProgressEntry {
  final String mangaUrl;
  final String mangaTitle;
  final String? mangaCover;
  final String? sourceId;
  final String? sourceName;
  final String? chapterUrl;
  final String chapterTitle;
  final String chapterNumber;
  final int pageIndex; // 1-based page number
  final int totalPages;
  final DateTime lastReadTime;
  final bool isAdult;
  final bool isCompleted;
  final Map<String, dynamic>? mangaJson;
  final Map<String, dynamic>? chapterJson;

  const MangaReadingProgressEntry({
    required this.mangaUrl,
    required this.mangaTitle,
    this.mangaCover,
    this.sourceId,
    this.sourceName,
    this.chapterUrl,
    required this.chapterTitle,
    required this.chapterNumber,
    this.pageIndex = 1,
    this.totalPages = 1,
    required this.lastReadTime,
    this.isAdult = false,
    this.isCompleted = false,
    this.mangaJson,
    this.chapterJson,
  });

  double get progressValue {
    if (totalPages <= 0) return 0.0;
    return (pageIndex / totalPages).clamp(0.0, 1.0);
  }

  bool get isFinished =>
      isCompleted || (totalPages > 0 && pageIndex >= totalPages);

  MangaReadingProgressEntry copyWith({
    String? mangaUrl,
    String? mangaTitle,
    String? mangaCover,
    String? sourceId,
    String? sourceName,
    String? chapterUrl,
    String? chapterTitle,
    String? chapterNumber,
    int? pageIndex,
    int? totalPages,
    DateTime? lastReadTime,
    bool? isAdult,
    bool? isCompleted,
    Map<String, dynamic>? mangaJson,
    Map<String, dynamic>? chapterJson,
  }) {
    return MangaReadingProgressEntry(
      mangaUrl: mangaUrl ?? this.mangaUrl,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      mangaCover: mangaCover ?? this.mangaCover,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      pageIndex: pageIndex ?? this.pageIndex,
      totalPages: totalPages ?? this.totalPages,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      isAdult: isAdult ?? this.isAdult,
      isCompleted: isCompleted ?? this.isCompleted,
      mangaJson: mangaJson ?? this.mangaJson,
      chapterJson: chapterJson ?? this.chapterJson,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaUrl': mangaUrl,
      'mangaTitle': mangaTitle,
      'mangaCover': mangaCover,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'chapterUrl': chapterUrl,
      'chapterTitle': chapterTitle,
      'chapterNumber': chapterNumber,
      'pageIndex': pageIndex,
      'totalPages': totalPages,
      'lastReadTime': lastReadTime.toIso8601String(),
      'isAdult': isAdult,
      'isCompleted': isCompleted,
      'mangaJson': mangaJson,
      'chapterJson': chapterJson,
    };
  }

  factory MangaReadingProgressEntry.fromMap(Map<String, dynamic> map) {
    return MangaReadingProgressEntry(
      mangaUrl: map['mangaUrl'] as String? ?? '',
      mangaTitle: map['mangaTitle'] as String? ?? '',
      mangaCover: map['mangaCover'] as String?,
      sourceId: map['sourceId'] as String?,
      sourceName: map['sourceName'] as String?,
      chapterUrl: map['chapterUrl'] as String?,
      chapterTitle: map['chapterTitle'] as String? ?? 'Chapter 1',
      chapterNumber: map['chapterNumber']?.toString() ?? '1',
      pageIndex: (map['pageIndex'] as num?)?.toInt() ?? 1,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      lastReadTime: map['lastReadTime'] != null
          ? DateTime.tryParse(map['lastReadTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      isAdult: map['isAdult'] as bool? ?? false,
      isCompleted: map['isCompleted'] as bool? ?? false,
      mangaJson: map['mangaJson'] != null
          ? Map<String, dynamic>.from(map['mangaJson'] as Map)
          : null,
      chapterJson: map['chapterJson'] != null
          ? Map<String, dynamic>.from(map['chapterJson'] as Map)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MangaReadingProgressEntry.fromJson(String source) =>
      MangaReadingProgressEntry.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
