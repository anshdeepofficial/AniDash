import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class HindiSourcePreferences {
  static final HindiSourcePreferences instance = HindiSourcePreferences._();
  HindiSourcePreferences._();

  static const String _keyOrder = 'hindi_sources_order';
  static const String _keyEnabled = 'hindi_sources_enabled';
  static const String _keyAutoSwitch = 'hindi_sources_auto_switch';
  static const String _keyPreferredProvider = 'hindi_sources_preferred_provider';
  static const String _keyFallbackAudio = 'hindi_sources_fallback_audio';
  static const String _keyAnimeOverrides = 'hindi_sources_anime_overrides';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- SOURCE ORDER ---

  List<String> getOrder() {
    final list = _prefs?.getStringList(_keyOrder);
    return list ?? <String>[];
  }

  Future<void> saveOrder(List<String> order) async {
    await init();
    await _prefs?.setStringList(_keyOrder, order);
    AppLogger.d('[Hindi Prefs] Saved custom order: $order');
  }

  // --- ENABLED MAP ---

  Map<String, bool> getEnabledMap() {
    final raw = _prefs?.getString(_keyEnabled);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return {};
    }
  }

  Future<void> setSourceEnabled(String id, bool enabled) async {
    await init();
    final map = getEnabledMap();
    map[id] = enabled;
    await _prefs?.setString(_keyEnabled, json.encode(map));
    AppLogger.d('[Hindi Prefs] Set $id enabled=$enabled');
  }

  // --- AUTO SWITCH ---

  bool getAutoSwitch() {
    return _prefs?.getBool(_keyAutoSwitch) ?? true;
  }

  Future<void> setAutoSwitch(bool value) async {
    await init();
    await _prefs?.setBool(_keyAutoSwitch, value);
  }

  // --- PREFERRED PROVIDER ---

  String getPreferredProvider() {
    return _prefs?.getString(_keyPreferredProvider) ?? 'auto';
  }

  Future<void> setPreferredProvider(String providerId) async {
    await init();
    await _prefs?.setString(_keyPreferredProvider, providerId);
  }

  // --- FALLBACK AUDIO ---

  String getFallbackAudio() {
    return _prefs?.getString(_keyFallbackAudio) ?? 'dub';
  }

  Future<void> setFallbackAudio(String audio) async {
    await init();
    await _prefs?.setString(_keyFallbackAudio, audio);
  }

  // --- ANIME SPECIFIC OVERRIDES ---

  String? getAnimeProviderOverride(String animeId) {
    final raw = _prefs?.getString(_keyAnimeOverrides);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded[animeId] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setAnimeProviderOverride(String animeId, String providerId) async {
    await init();
    final raw = _prefs?.getString(_keyAnimeOverrides);
    final map = <String, dynamic>{};
    if (raw != null) {
      try {
        map.addAll(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    map[animeId] = providerId;
    await _prefs?.setString(_keyAnimeOverrides, json.encode(map));
  }

  Future<void> clearAnimeProviderOverride(String animeId) async {
    await init();
    final raw = _prefs?.getString(_keyAnimeOverrides);
    if (raw == null) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      map.remove(animeId);
      await _prefs?.setString(_keyAnimeOverrides, json.encode(map));
    } catch (_) {}
  }

  // --- RESET DEFAULTS ---

  Future<void> resetDefaults() async {
    await init();
    await _prefs?.remove(_keyOrder);
    await _prefs?.remove(_keyEnabled);
    await _prefs?.remove(_keyAutoSwitch);
    await _prefs?.remove(_keyPreferredProvider);
    await _prefs?.remove(_keyFallbackAudio);
    AppLogger.i('[Hindi Prefs] Reset Hindi sources to default settings');
  }
}
