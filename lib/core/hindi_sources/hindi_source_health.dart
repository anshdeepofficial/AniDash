import 'package:ani_dash/core/utils/app_logger.dart';

class _ProviderHealthStat {
  int consecutiveFailures = 0;
  int? lastLatencyMs;
  DateTime? lastSuccessTime;
  DateTime? lastFailureTime;
  DateTime? cooldownUntil;

  bool get isInCooldown =>
      cooldownUntil != null && DateTime.now().isBefore(cooldownUntil!);
}

class HindiSourceHealthTracker {
  static final HindiSourceHealthTracker instance =
      HindiSourceHealthTracker._();
  HindiSourceHealthTracker._();

  final Map<String, _ProviderHealthStat> _stats = {};

  static const int _maxFailuresBeforeCooldown = 3;
  static const Duration _cooldownDuration = Duration(minutes: 5);

  _ProviderHealthStat _getStat(String providerId) {
    return _stats.putIfAbsent(providerId, () => _ProviderHealthStat());
  }

  void recordSuccess(String providerId, int latencyMs) {
    final stat = _getStat(providerId);
    stat.consecutiveFailures = 0;
    stat.lastLatencyMs = latencyMs;
    stat.lastSuccessTime = DateTime.now();
    stat.cooldownUntil = null;
    AppLogger.d(
      '[Hindi Health] $providerId success in ${latencyMs}ms (failures reset)',
    );
  }

  void recordFailure(String providerId) {
    final stat = _getStat(providerId);
    stat.consecutiveFailures++;
    stat.lastFailureTime = DateTime.now();

    if (stat.consecutiveFailures >= _maxFailuresBeforeCooldown) {
      stat.cooldownUntil = DateTime.now().add(_cooldownDuration);
      AppLogger.w(
        '[Hindi Health] $providerId entered 5-min cooldown (${stat.consecutiveFailures} consecutive failures)',
      );
    } else {
      AppLogger.w(
        '[Hindi Health] $providerId failure count: ${stat.consecutiveFailures}',
      );
    }
  }

  bool isAvailable(String providerId) {
    final stat = _stats[providerId];
    if (stat == null) return true;
    return !stat.isInCooldown;
  }

  int? getLatency(String providerId) => _stats[providerId]?.lastLatencyMs;

  int getConsecutiveFailures(String providerId) =>
      _stats[providerId]?.consecutiveFailures ?? 0;

  DateTime? getCooldownUntil(String providerId) =>
      _stats[providerId]?.cooldownUntil;

  void resetHealth(String providerId) {
    _stats.remove(providerId);
    AppLogger.d('[Hindi Health] Reset health status for $providerId');
  }

  void resetAll() {
    _stats.clear();
  }
}
