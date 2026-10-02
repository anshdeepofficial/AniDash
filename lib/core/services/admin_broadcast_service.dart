import 'dart:convert';

import 'package:ani_dash/core/utils/env_loader.dart';
import 'package:http/http.dart' as http;

class AdminBroadcastService {
  const AdminBroadcastService();

  Future<Map<String, int>> loadStats(
    String accessToken,
    String developerPin,
  ) async {
    final response = await http.get(
      Uri.parse('$ANIDASH_ADMIN_API_URL/admin-stats'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Admin-Pin': developerPin,
      },
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? 'Unable to load user statistics');
    }
    return {
      'totalDevices': (json['totalDevices'] as num?)?.toInt() ?? 0,
      'subscribedDevices': (json['subscribedDevices'] as num?)?.toInt() ?? 0,
      'activeToday': (json['activeToday'] as num?)?.toInt() ?? 0,
      'active7Days': (json['active7Days'] as num?)?.toInt() ?? 0,
      'active30Days': (json['active30Days'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> send({
    required String accessToken,
    required String developerPin,
    required String title,
    required String message,
    String route = '/',
  }) async {
    final response = await http.post(
      Uri.parse('$ANIDASH_ADMIN_API_URL/admin-message'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Admin-Pin': developerPin,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': title, 'message': message, 'route': route}),
    );
    if (response.statusCode != 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(json['error'] ?? 'Unable to send announcement');
    }
  }
}
