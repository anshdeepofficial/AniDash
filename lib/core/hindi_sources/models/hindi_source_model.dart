import 'dart:convert';
import 'package:ani_dash/core/hindi_sources/hindi_icon_resolver.dart';

class HindiSourceModel {
  final String id;
  final String name;
  final List<String> language;
  final int priority;
  final bool enabled;
  final bool enabledByDefault;
  final String status; // 'stable', 'backup', 'experimental', 'offline'
  final bool supportsStreaming;
  final bool supportsDownloads;
  final bool supportsMultiAudio;
  final String baseUrl;
  final List<String> mirrors;
  final bool isHealthy;
  final int? lastLatencyMs;
  final int consecutiveFailures;
  final DateTime? lastFailureTime;
  final DateTime? lastTestedTime;
  final String? configuredLogoUrl;

  const HindiSourceModel({
    required this.id,
    required this.name,
    this.language = const ['hi'],
    this.priority = 100,
    this.enabled = true,
    this.enabledByDefault = true,
    this.status = 'stable',
    this.supportsStreaming = true,
    this.supportsDownloads = false,
    this.supportsMultiAudio = true,
    this.baseUrl = '',
    this.mirrors = const [],
    this.isHealthy = true,
    this.lastLatencyMs,
    this.consecutiveFailures = 0,
    this.lastFailureTime,
    this.lastTestedTime,
    this.configuredLogoUrl,
  });

  String get localAssetPath => 'assets/provider_icons/${id.toLowerCase()}.png';

  bool get hasLocalAsset =>
      id.toLowerCase() == 'animesalt' ||
      id.toLowerCase() == 'animixstream' ||
      id.toLowerCase() == 'animedrive' ||
      id.toLowerCase() == 'animelok';

  String get fallbackInitials {
    switch (id.toLowerCase()) {
      case 'animesalt':
        return 'AS';
      case 'animixstream':
        return 'AX';
      case 'animedrive':
        return 'AD';
      case 'animelok':
        return 'AL';
      default:
        final parts = name.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase() : 'H';
    }
  }

  String get logoUrl {
    if (configuredLogoUrl != null && configuredLogoUrl!.trim().isNotEmpty) {
      return configuredLogoUrl!.trim();
    }
    final cached = HindiIconResolver().getCachedIcon(id);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    if (baseUrl.isEmpty) return '';
    final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanUrl/favicon.ico';
  }

  HindiSourceModel copyWith({
    String? id,
    String? name,
    List<String>? language,
    int? priority,
    bool? enabled,
    bool? enabledByDefault,
    String? status,
    bool? supportsStreaming,
    bool? supportsDownloads,
    bool? supportsMultiAudio,
    String? baseUrl,
    List<String>? mirrors,
    bool? isHealthy,
    int? lastLatencyMs,
    int? consecutiveFailures,
    DateTime? lastFailureTime,
    DateTime? lastTestedTime,
    String? configuredLogoUrl,
  }) {
    return HindiSourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      language: language ?? this.language,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      enabledByDefault: enabledByDefault ?? this.enabledByDefault,
      status: status ?? this.status,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsDownloads: supportsDownloads ?? this.supportsDownloads,
      supportsMultiAudio: supportsMultiAudio ?? this.supportsMultiAudio,
      baseUrl: baseUrl ?? this.baseUrl,
      mirrors: mirrors ?? this.mirrors,
      isHealthy: isHealthy ?? this.isHealthy,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastFailureTime: lastFailureTime ?? this.lastFailureTime,
      lastTestedTime: lastTestedTime ?? this.lastTestedTime,
      configuredLogoUrl: configuredLogoUrl ?? this.configuredLogoUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'language': language,
      'priority': priority,
      'enabled': enabled,
      'enabledByDefault': enabledByDefault,
      'status': status,
      'supportsStreaming': supportsStreaming,
      'supportsDownloads': supportsDownloads,
      'supportsMultiAudio': supportsMultiAudio,
      'baseUrl': baseUrl,
      'mirrors': mirrors,
      'isHealthy': isHealthy,
      'lastLatencyMs': lastLatencyMs,
      'consecutiveFailures': consecutiveFailures,
      'lastFailureTime': lastFailureTime?.toIso8601String(),
      'lastTestedTime': lastTestedTime?.toIso8601String(),
      'logoUrl': configuredLogoUrl,
    };
  }

  factory HindiSourceModel.fromMap(Map<String, dynamic> map) {
    return HindiSourceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      language: (map['language'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['hi'],
      priority: (map['priority'] as num?)?.toInt() ?? 100,
      enabled: map['enabled'] ?? map['enabledByDefault'] ?? true,
      enabledByDefault: map['enabledByDefault'] ?? true,
      status: map['status'] ?? 'stable',
      supportsStreaming: map['supportsStreaming'] ?? true,
      supportsDownloads: map['supportsDownloads'] ?? false,
      supportsMultiAudio: map['supportsMultiAudio'] ?? true,
      baseUrl: map['baseUrl'] ?? '',
      mirrors: (map['mirrors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (map['baseUrl'] != null ? [map['baseUrl'].toString()] : const []),
      isHealthy: map['isHealthy'] ?? true,
      lastLatencyMs: (map['lastLatencyMs'] as num?)?.toInt(),
      consecutiveFailures: (map['consecutiveFailures'] as num?)?.toInt() ?? 0,
      lastFailureTime: map['lastFailureTime'] != null
          ? DateTime.tryParse(map['lastFailureTime'])
          : null,
      lastTestedTime: map['lastTestedTime'] != null
          ? DateTime.tryParse(map['lastTestedTime'])
          : null,
      configuredLogoUrl: map['logoUrl'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory HindiSourceModel.fromJson(String source) =>
      HindiSourceModel.fromMap(json.decode(source));
}
