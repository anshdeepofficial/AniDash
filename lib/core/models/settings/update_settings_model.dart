import 'dart:convert';

class UpdateSettingsModel {
  final bool autoCheckEnabled;
  final int checkIntervalMinutes;
  final int startHour;
  final int endHour;
  final String? skippedVersion;

  const UpdateSettingsModel({
    this.autoCheckEnabled = true,
    this.checkIntervalMinutes = 15,
    this.startHour = 20,
    this.endHour = 6,
    this.skippedVersion,
  });

  UpdateSettingsModel copyWith({
    bool? autoCheckEnabled,
    int? checkIntervalMinutes,
    int? startHour,
    int? endHour,
    String? skippedVersion,
  }) {
    return UpdateSettingsModel(
      autoCheckEnabled: autoCheckEnabled ?? this.autoCheckEnabled,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      skippedVersion: skippedVersion ?? this.skippedVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoCheckEnabled': autoCheckEnabled,
      'checkIntervalMinutes': checkIntervalMinutes,
      'startHour': startHour,
      'endHour': endHour,
      'skippedVersion': skippedVersion,
    };
  }

  factory UpdateSettingsModel.fromMap(Map<String, dynamic> map) {
    return UpdateSettingsModel(
      autoCheckEnabled: map['autoCheckEnabled'] ?? true,
      checkIntervalMinutes: map['checkIntervalMinutes']?.toInt() ?? 15,
      startHour: map['startHour']?.toInt() ?? 20,
      endHour: map['endHour']?.toInt() ?? 6,
      skippedVersion: map['skippedVersion'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UpdateSettingsModel.fromJson(String source) => 
      UpdateSettingsModel.fromMap(json.decode(source));
}
