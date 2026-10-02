import 'dart:convert';

import 'package:ani_dash/core/utils/env_loader.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeveloperAccessService {
  const DeveloperAccessService();

  static const _unlockedKey = 'developer_broadcast_unlocked_8013267';
  static const _blockedKey = 'developer_broadcast_blocked_8013267';
  static const _attemptsKey = 'developer_broadcast_attempts_8013267';
  static const _pinKey = 'developer_broadcast_pin_8013267';
  static const _secureStorage = FlutterSecureStorage();

  Future<String?> savedPin() => _secureStorage.read(key: _pinKey);

  Future<bool> isUnlocked() async =>
      (await SharedPreferences.getInstance()).getBool(_unlockedKey) ?? false;

  Future<bool> isBlocked() async =>
      (await SharedPreferences.getInstance()).getBool(_blockedKey) ?? false;

  Future<int> remainingAttempts() async {
    final used =
        (await SharedPreferences.getInstance()).getInt(_attemptsKey) ?? 0;
    return (3 - used).clamp(0, 3);
  }

  Future<bool> verify({
    required String accessToken,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_blockedKey) ?? false) return false;
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$ANIDASH_ADMIN_API_URL/admin-unlock'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const DeveloperVerificationUnavailable();
    }
    if (response.statusCode == 200) {
      await prefs.setBool(_unlockedKey, true);
      await prefs.remove(_attemptsKey);
      await _secureStorage.write(key: _pinKey, value: pin);
      return true;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      final used = (prefs.getInt(_attemptsKey) ?? 0) + 1;
      await prefs.setInt(_attemptsKey, used);
      if (used >= 3) await prefs.setBool(_blockedKey, true);
    }
    String? message;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message =
            decoded['error']?.toString() ?? decoded['message']?.toString();
      }
    } catch (_) {}
    if (response.statusCode != 401 && response.statusCode != 403) {
      throw DeveloperVerificationUnavailable(message);
    }
    throw Exception(message ?? 'The developer PIN was not accepted');
  }
}

class DeveloperVerificationUnavailable implements Exception {
  const DeveloperVerificationUnavailable([this.details]);

  final String? details;

  @override
  String toString() =>
      details?.trim().isNotEmpty == true
          ? 'Developer verification is temporarily unavailable: $details'
          : 'Developer verification is temporarily unavailable. Please try again later.';
}
