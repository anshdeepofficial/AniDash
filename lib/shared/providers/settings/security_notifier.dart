import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'package:ani_dash/main.dart';

class SecurityState {
  final bool appLockEnabled;
  final String? appLockPinHash;
  final bool appLockBiometrics;
  final String appLockType;
  final int appLockDelaySeconds;
  final bool hentaiLockEnabled;
  final String? hentaiLockPinHash;
  final bool hentaiLockBiometrics;
  final bool recentAppsPrivacy;
  final bool screenshotPrivacy;
  final bool isAppUnlocked;
  final bool isHentaiUnlocked;

  const SecurityState({
    this.appLockEnabled = false,
    this.appLockPinHash,
    this.appLockBiometrics = true,
    this.appLockType = 'pin4',
    this.appLockDelaySeconds = 0,
    this.hentaiLockEnabled = false,
    this.hentaiLockPinHash,
    this.hentaiLockBiometrics = true,
    this.recentAppsPrivacy = true,
    this.screenshotPrivacy = false,
    this.isAppUnlocked = false,
    this.isHentaiUnlocked = false,
  });

  SecurityState copyWith({
    bool? appLockEnabled,
    String? appLockPinHash,
    bool? appLockBiometrics,
    String? appLockType,
    int? appLockDelaySeconds,
    bool? hentaiLockEnabled,
    String? hentaiLockPinHash,
    bool? hentaiLockBiometrics,
    bool? recentAppsPrivacy,
    bool? screenshotPrivacy,
    bool? isAppUnlocked,
    bool? isHentaiUnlocked,
  }) {
    return SecurityState(
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPinHash: appLockPinHash ?? this.appLockPinHash,
      appLockBiometrics: appLockBiometrics ?? this.appLockBiometrics,
      appLockType: appLockType ?? this.appLockType,
      appLockDelaySeconds: appLockDelaySeconds ?? this.appLockDelaySeconds,
      hentaiLockEnabled: hentaiLockEnabled ?? this.hentaiLockEnabled,
      hentaiLockPinHash: hentaiLockPinHash ?? this.hentaiLockPinHash,
      hentaiLockBiometrics: hentaiLockBiometrics ?? this.hentaiLockBiometrics,
      recentAppsPrivacy: recentAppsPrivacy ?? this.recentAppsPrivacy,
      screenshotPrivacy: screenshotPrivacy ?? this.screenshotPrivacy,
      isAppUnlocked: isAppUnlocked ?? this.isAppUnlocked,
      isHentaiUnlocked: isHentaiUnlocked ?? this.isHentaiUnlocked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appLockEnabled': appLockEnabled,
      'appLockPinHash': appLockPinHash,
      'appLockBiometrics': appLockBiometrics,
      'appLockType': appLockType,
      'appLockDelaySeconds': appLockDelaySeconds,
      'hentaiLockEnabled': hentaiLockEnabled,
      'hentaiLockPinHash': hentaiLockPinHash,
      'hentaiLockBiometrics': hentaiLockBiometrics,
      'recentAppsPrivacy': recentAppsPrivacy,
      'screenshotPrivacy': screenshotPrivacy,
    };
  }

  factory SecurityState.fromMap(Map<String, dynamic> map) {
    final appLock = map['appLockEnabled'] == true;
    final hentaiLock = map['hentaiLockEnabled'] == true;
    return SecurityState(
      appLockEnabled: appLock,
      appLockPinHash: map['appLockPinHash'],
      appLockBiometrics: map['appLockBiometrics'] ?? true,
      appLockType: map['appLockType'] ?? 'pin4',
      appLockDelaySeconds: map['appLockDelaySeconds'] ?? 0,
      hentaiLockEnabled: hentaiLock,
      hentaiLockPinHash: map['hentaiLockPinHash'],
      hentaiLockBiometrics: map['hentaiLockBiometrics'] ?? true,
      recentAppsPrivacy: map['recentAppsPrivacy'] ?? true,
      screenshotPrivacy: map['screenshotPrivacy'] ?? false,
      isAppUnlocked: !appLock,
      isHentaiUnlocked: !hentaiLock,
    );
  }

  String toJson() => json.encode(toMap());
  factory SecurityState.fromJson(String source) =>
      SecurityState.fromMap(json.decode(source));
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(
  SecurityNotifier.new,
);

class SecurityNotifier extends Notifier<SecurityState> {
  static const _prefsKey = 'ani_security_settings';
  static const _channel = MethodChannel('shonenx/security');

  @override
  SecurityState build() {
    final raw = sharedPrefs.getString(_prefsKey);
    final initial =
        raw != null ? SecurityState.fromJson(raw) : const SecurityState();
    _applySecureFlag(initial.screenshotPrivacy);
    return initial;
  }

  String hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  bool verifyAppPin(String pin) {
    if (state.appLockPinHash == null) return true;
    final match = hashPin(pin) == state.appLockPinHash;
    if (match) {
      state = state.copyWith(isAppUnlocked: true);
    }
    return match;
  }

  bool verifyHentaiPin(String pin) {
    if (state.hentaiLockPinHash == null) return true;
    final match = hashPin(pin) == state.hentaiLockPinHash;
    if (match) {
      state = state.copyWith(isHentaiUnlocked: true);
    }
    return match;
  }

  void unlockApp() {
    state = state.copyWith(isAppUnlocked: true);
  }

  void lockApp() {
    if (state.appLockEnabled) {
      state = state.copyWith(isAppUnlocked: false);
    }
  }

  void unlockHentai() {
    state = state.copyWith(isHentaiUnlocked: true);
  }

  void lockHentai() {
    if (state.hentaiLockEnabled) {
      state = state.copyWith(isHentaiUnlocked: false);
    }
  }

  void setAppLock(bool enabled, [String? pin]) {
    final pinHash = pin != null ? hashPin(pin) : state.appLockPinHash;
    state = state.copyWith(
      appLockEnabled: enabled,
      appLockPinHash: pinHash,
      isAppUnlocked: !enabled,
    );
    _save();
  }

  void setHentaiLock(bool enabled, [String? pin]) {
    final pinHash = pin != null ? hashPin(pin) : state.hentaiLockPinHash;
    state = state.copyWith(
      hentaiLockEnabled: enabled,
      hentaiLockPinHash: pinHash,
      isHentaiUnlocked: !enabled,
    );
    _save();
  }

  void toggleAppLockBiometrics(bool val) {
    state = state.copyWith(appLockBiometrics: val);
    _save();
  }

  void setAppLockType(String type, String credential) {
    state = state.copyWith(
      appLockType: type,
      appLockPinHash: hashPin(credential),
      isAppUnlocked: true,
    );
    _save();
  }

  void setPreferredAppLockType(String type) {
    state = state.copyWith(appLockType: type);
    _save();
  }

  void setAppLockDelay(int seconds) {
    state = state.copyWith(appLockDelaySeconds: seconds);
    _save();
  }

  void toggleHentaiLockBiometrics(bool val) {
    state = state.copyWith(hentaiLockBiometrics: val);
    _save();
  }

  void toggleRecentAppsPrivacy(bool val) {
    state = state.copyWith(recentAppsPrivacy: val);
    _save();
  }

  void toggleScreenshotPrivacy(bool val) {
    state = state.copyWith(screenshotPrivacy: val);
    _applySecureFlag(val);
    _save();
  }

  void _applySecureFlag(bool enable) {
    try {
      _channel.invokeMethod('setSecureFlag', {'enable': enable});
    } catch (_) {}
  }

  void _save() {
    sharedPrefs.setString(_prefsKey, state.toJson());
  }
}
