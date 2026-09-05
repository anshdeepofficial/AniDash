import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/main.dart';

class IncognitoService {
  static const String _incognitoPrefix = 'incognito_anime_';
  static final Set<String> _activeSessions = {};

  static Set<String> get activeSessions => _activeSessions;

  static bool isIncognito(String animeId) {
    if (_activeSessions.contains(animeId)) return true;
    return sharedPrefs.getBool('$_incognitoPrefix$animeId') ?? false;
  }

  static void setIncognito(String animeId, bool enabled) {
    if (enabled) {
      _activeSessions.add(animeId);
      sharedPrefs.setBool('$_incognitoPrefix$animeId', true);
    } else {
      _activeSessions.remove(animeId);
      sharedPrefs.remove('$_incognitoPrefix$animeId');
    }
  }

  static bool toggle(String animeId) {
    final next = !isIncognito(animeId);
    setIncognito(animeId, next);
    return next;
  }
}

class IncognitoNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return Set<String>.from(IncognitoService.activeSessions);
  }

  void toggle(String animeId) {
    IncognitoService.toggle(animeId);
    state = Set<String>.from(IncognitoService.activeSessions);
  }

  void set(String animeId, bool value) {
    IncognitoService.setIncognito(animeId, value);
    state = Set<String>.from(IncognitoService.activeSessions);
  }
}

final incognitoNotifierProvider =
    NotifierProvider<IncognitoNotifier, Set<String>>(
  IncognitoNotifier.new,
);

final incognitoProvider = Provider.family<bool, String>((ref, animeId) {
  final active = ref.watch(incognitoNotifierProvider);
  return active.contains(animeId) || IncognitoService.isIncognito(animeId);
});
