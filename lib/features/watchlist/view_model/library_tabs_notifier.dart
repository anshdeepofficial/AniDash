import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryTabConfig {
  final String status;
  final bool isVisible;

  const LibraryTabConfig({
    required this.status,
    this.isVisible = true,
  });

  LibraryTabConfig copyWith({String? status, bool? isVisible}) {
    return LibraryTabConfig(
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'isVisible': isVisible,
      };

  factory LibraryTabConfig.fromJson(Map<String, dynamic> json) =>
      LibraryTabConfig(
        status: json['status'] as String,
        isVisible: json['isVisible'] as bool? ?? true,
      );
}

class LibraryTabsState {
  final List<LibraryTabConfig> allTabs;

  const LibraryTabsState({required this.allTabs});

  List<String> get visibleStatuses {
    final visible =
        allTabs.where((t) => t.isVisible).map((t) => t.status).toList();
    if (visible.isEmpty) {
      return ['current'];
    }
    return visible;
  }
}

const List<LibraryTabConfig> defaultLibraryTabs = [
  LibraryTabConfig(status: 'current', isVisible: true),
  LibraryTabConfig(status: 'completed', isVisible: true),
  LibraryTabConfig(status: 'paused', isVisible: true),
  LibraryTabConfig(status: 'dropped', isVisible: true),
  LibraryTabConfig(status: 'planning', isVisible: true),
  LibraryTabConfig(status: 'favorites', isVisible: true),
];

class LibraryTabsNotifier extends Notifier<LibraryTabsState> {
  static const _prefKey = 'library_custom_tabs_config_v1';

  @override
  LibraryTabsState build() {
    _loadFromPrefs();
    return const LibraryTabsState(allTabs: defaultLibraryTabs);
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        final loadedTabs =
            list.map((e) => LibraryTabConfig.fromJson(e as Map<String, dynamic>)).toList();
        final existingStatuses = loadedTabs.map((e) => e.status).toSet();
        for (final def in defaultLibraryTabs) {
          if (!existingStatuses.contains(def.status)) {
            loadedTabs.add(def);
          }
        }
        state = LibraryTabsState(allTabs: loadedTabs);
      }
    } catch (_) {
      state = const LibraryTabsState(allTabs: defaultLibraryTabs);
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = List<LibraryTabConfig>.from(state.allTabs);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = LibraryTabsState(allTabs: list);
    await _saveToPrefs();
  }

  Future<void> toggleVisibility(String status) async {
    final list = state.allTabs.map((tab) {
      if (tab.status == status) {
        final visibleCount = state.allTabs.where((t) => t.isVisible).length;
        if (tab.isVisible && visibleCount <= 1) return tab;
        return tab.copyWith(isVisible: !tab.isVisible);
      }
      return tab;
    }).toList();
    state = LibraryTabsState(allTabs: list);
    await _saveToPrefs();
  }

  Future<void> resetToDefault() async {
    state = const LibraryTabsState(allTabs: defaultLibraryTabs);
    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.allTabs.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, jsonStr);
    } catch (_) {}
  }
}

final libraryTabsProvider =
    NotifierProvider<LibraryTabsNotifier, LibraryTabsState>(
  LibraryTabsNotifier.new,
);
