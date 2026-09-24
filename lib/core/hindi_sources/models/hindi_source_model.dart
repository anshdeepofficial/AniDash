import 'dart:convert';

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
  });

  String get logoUrl {
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
    );
  }

  String toJson() => json.encode(toMap());

  factory HindiSourceModel.fromJson(String source) =>
      HindiSourceModel.fromMap(json.decode(source));
}
