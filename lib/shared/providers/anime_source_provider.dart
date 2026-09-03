import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:ani_dash/core/registery/anime_source_registery.dart';
import 'package:ani_dash/core/registery/sources/anime/anime_provider.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/main.dart';

// Hive (Depecrated)
const selectedProviderBox = 'selected_provider';
const selectedProviderKey = 'selected_key';
// SharedPreferences
const selectedProvider = 'selected_provider';

final animeSourceRegistryProvider = Provider<AnimeSourceRegistry>((ref) {
  return AnimeSourceRegistry();
});

final selectedProviderKeyProvider =
    NotifierProvider<SelectedProviderKeyNotifier, String?>(
      SelectedProviderKeyNotifier.new,
    );

class SelectedProviderKeyNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Migration
    if (!Hive.isBoxOpen(selectedProviderBox)) {
      final box = Hive.box<String>(selectedProviderBox);
      final key = box.get(selectedProviderKey);
      if (box.isNotEmpty && key != null && key.isNotEmpty) select(key);
      box.delete(selectedProviderKey);
    }
    final selectedKey = sharedPrefs.getString(selectedProvider);
    AppLogger.w("[Registery] Selected $selectedKey");
    return selectedKey;
  }

  void select(String key) {
    sharedPrefs.setString(selectedProvider, key);
    state = key;
  }

  void clear() {
    state = null;
  }
}

final selectedAnimeProvider = Provider<AnimeProvider?>((ref) {
  final registry = ref.watch(animeSourceRegistryProvider);
  final key = ref.watch(selectedProviderKeyProvider);
  if (key != null && key.isNotEmpty) {
    final p = registry.get(key);
    if (p != null) return p;
  }
  return registry.get('hianime') ??
      registry.get('aniwatch') ??
      registry.get('gojo') ??
      registry.values.firstOrNull;
});
