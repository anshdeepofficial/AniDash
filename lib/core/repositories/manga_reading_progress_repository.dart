import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/core/models/manga/manga_reading_progress_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/main.dart';

final mangaReadingProgressRepositoryProvider =
    Provider<MangaReadingProgressRepository>((ref) {
  return MangaReadingProgressRepository();
});

final mangaReadingProgressStreamProvider =
    StreamProvider<List<MangaReadingProgressEntry>>((ref) {
  final repo = ref.watch(mangaReadingProgressRepositoryProvider);
  return repo.watchAllProgress();
});

final mangaReadingProgressProvider =
    Provider<List<MangaReadingProgressEntry>>((ref) {
  final asyncValue = ref.watch(mangaReadingProgressStreamProvider);
  return asyncValue.maybeWhen(
    data: (data) => data,
    orElse: () => ref.read(mangaReadingProgressRepositoryProvider).getAllProgress(),
  );
});

class MangaReadingProgressRepository {
  static const String _prefsKey = 'manga_reading_progress_list_v1';

  final StreamController<List<MangaReadingProgressEntry>> _streamController =
      StreamController<List<MangaReadingProgressEntry>>.broadcast();

  Map<String, MangaReadingProgressEntry>? _cache;

  MangaReadingProgressRepository() {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    try {
      final jsonStr = sharedPrefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr) as List<dynamic>;
        _cache = {
          for (final item in decoded)
            if (item is Map<String, dynamic>)
              MangaReadingProgressEntry.fromMap(item).mangaUrl:
                  MangaReadingProgressEntry.fromMap(item)
        };
      } else {
        _cache = {};
      }
    } catch (e) {
      AppLogger.e('Error loading manga reading progress: $e');
      _cache = {};
    }
  }

  Future<void> _persist() async {
    try {
      if (_cache == null) return;
      final list = _cache!.values.map((e) => e.toMap()).toList();
      await sharedPrefs.setString(_prefsKey, json.encode(list));
      _streamController.add(getAllProgress());
    } catch (e) {
      AppLogger.e('Error saving manga reading progress: $e');
    }
  }

  List<MangaReadingProgressEntry> getAllProgress() {
    if (_cache == null) _loadFromPrefs();
    final list = _cache!.values.toList();
    list.sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));
    return list;
  }

  MangaReadingProgressEntry? getProgress(String mangaUrl) {
    if (_cache == null) _loadFromPrefs();
    return _cache![mangaUrl];
  }

  Future<void> saveProgress(MangaReadingProgressEntry entry) async {
    if (_cache == null) _loadFromPrefs();
    _cache![entry.mangaUrl] = entry;
    await _persist();
  }

  Future<void> removeProgress(String mangaUrl) async {
    if (_cache == null) _loadFromPrefs();
    if (_cache!.containsKey(mangaUrl)) {
      _cache!.remove(mangaUrl);
      await _persist();
    }
  }

  Future<void> markCompleted(String mangaUrl) async {
    if (_cache == null) _loadFromPrefs();
    final existing = _cache![mangaUrl];
    if (existing != null) {
      _cache![mangaUrl] = existing.copyWith(
        isCompleted: true,
        lastReadTime: DateTime.now(),
      );
      await _persist();
    }
  }

  Future<void> clearAll() async {
    _cache = {};
    await _persist();
  }

  Stream<List<MangaReadingProgressEntry>> watchAllProgress() async* {
    yield getAllProgress();
    yield* _streamController.stream;
  }
}
