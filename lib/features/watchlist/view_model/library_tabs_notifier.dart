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
    if (visible.isEmpty && allTabs.isNotEmpty) {
      return [allTabs.first.status];
    }
    return visible;
  }
}

class LibraryTabsNotifier extends Notifier<LibraryTabsState> {
  static const _prefOrderKey = 'library_custom_tabs_order_v2';
  static const _prefHiddenKey = 'library_custom_tabs_hidden_v2';

  List<String> _availableStatuses = [];

  @override
  LibraryTabsState build() {
    return const LibraryTabsState(allTabs: []);
  }

  Future<void> setAvailableStatuses(List<String> statuses) async {
    if (statuses.isEmpty) return;
    _availableStatuses = List<String>.from(statuses);
    await _applyConfiguration();
  }

  Future<void> _applyConfiguration() async {
    if (_availableStatuses.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_prefOrderKey) ?? [];
      final hiddenList = prefs.getStringList(_prefHiddenKey) ?? [];
      final hiddenSet = hiddenList.map((s) => s.toLowerCase()).toSet();

      // Sort _availableStatuses according to savedOrder
      final sorted = List<String>.from(_availableStatuses);
      if (savedOrder.isNotEmpty) {
        sorted.sort((a, b) {
          final aIdx = savedOrder.indexOf(a.toLowerCase());
          final bIdx = savedOrder.indexOf(b.toLowerCase());
          if (aIdx == -1 && bIdx == -1) return 0;
          if (aIdx == -1) return 1;
          if (bIdx == -1) return -1;
          return aIdx.compareTo(bIdx);
        });
      }

      final tabs = sorted.map((s) {
        final isVis = !hiddenSet.contains(s.toLowerCase());
        return LibraryTabConfig(status: s, isVisible: isVis);
      }).toList();

      state = LibraryTabsState(allTabs: tabs);
    } catch (_) {
      state = LibraryTabsState(
        allTabs: _availableStatuses
            .map((s) => LibraryTabConfig(status: s, isVisible: true))
            .toList(),
      );
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
      if (tab.status.toLowerCase() == status.toLowerCase()) {
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefOrderKey);
      await prefs.remove(_prefHiddenKey);
    } catch (_) {}

    state = LibraryTabsState(
      allTabs: _availableStatuses
          .map((s) => LibraryTabConfig(status: s, isVisible: true))
          .toList(),
    );
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = state.allTabs.map((t) => t.status.toLowerCase()).toList();
      final hidden = state.allTabs
          .where((t) => !t.isVisible)
          .map((t) => t.status.toLowerCase())
          .toList();

      await prefs.setStringList(_prefOrderKey, order);
      await prefs.setStringList(_prefHiddenKey, hidden);
    } catch (_) {}
  }
}

final libraryTabsProvider =
    NotifierProvider<LibraryTabsNotifier, LibraryTabsState>(
  LibraryTabsNotifier.new,
);
