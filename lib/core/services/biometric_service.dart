import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks whether device supports biometrics (fingerprint / face) or device auth
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      AppLogger.w('Error checking biometric support: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns available biometric types (e.g. fingerprint, face)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      AppLogger.w('Error getting biometric types: $e');
      return [];
    }
  }

  /// Human-friendly description of available biometric types
  static Future<String> getBiometricLabel() async {
    try {
      final types = await getAvailableBiometrics();
      if (types.contains(BiometricType.face) && types.contains(BiometricType.fingerprint)) {
        return 'Fingerprint & Face Unlock';
      } else if (types.contains(BiometricType.face)) {
        return 'Face Unlock';
      } else if (types.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      }
    } catch (_) {}
    return 'Biometrics';
  }

  /// Authenticate using biometrics (Fingerprint / Face Unlock)
  static Future<bool> authenticate({
    String reason = 'Authenticate with Fingerprint or Face to unlock',
  }) async {
    try {
      final bool available = await isBiometricAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      AppLogger.w('Biometric auth error: $e');
      return false;
    } catch (e) {
      AppLogger.w('Unexpected biometric auth error: $e');
      return false;
    }
  }
}
