import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/shared/providers/settings/security_notifier.dart';
import 'package:ani_dash/shared/ui/pin_lock_dialog.dart';

class SecurityGate extends ConsumerStatefulWidget {
  final Widget child;
  const SecurityGate({super.key, required this.child});

  @override
  ConsumerState<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends ConsumerState<SecurityGate>
    with WidgetsBindingObserver {
  bool _isBackgrounded = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final security = ref.read(securityProvider);

    // CRITICAL: Never lock or blur on 'inactive' state!
    // 'inactive' occurs transiently when taking a screenshot, pulling the
    // notification tray, or adjusting volume. Only 'paused' represents leaving the app.
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      if (security.recentAppsPrivacy) {
        setState(() => _isBackgrounded = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _isBackgrounded = false);

      // If app was genuinely backgrounded/minimized and app lock is enabled, re-lock
      if (security.appLockEnabled && _pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        if (elapsed.inMilliseconds > 1500) {
          ref.read(securityProvider.notifier).lockApp();
        }
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final isLocked = security.appLockEnabled && !security.isAppUnlocked;
    final showPrivacyCover = _isBackgrounded && security.recentAppsPrivacy;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,

        // Recent Apps Frosted Blur Screen
        if (showPrivacyCover && !isLocked)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/anidash_logo_light.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AniDash Protected',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Fullscreen App Lock Screen
        if (isLocked)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: PinLockDialog(
                title: 'AniDash Locked',
                subtitle: 'Enter your 4-digit PIN to unlock',
                enableBiometrics: security.appLockBiometrics,
                onBiometricSuccess: () {
                  ref.read(securityProvider.notifier).unlockApp();
                },
                onVerify: (pin) {
                  return ref.read(securityProvider.notifier).verifyAppPin(pin);
                },
              ),
            ),
          ),
      ],
    );
  }
}
