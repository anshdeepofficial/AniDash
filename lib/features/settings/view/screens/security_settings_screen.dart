import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:ani_dash/shared/providers/settings/security_notifier.dart';
import 'package:ani_dash/shared/ui/pin_lock_dialog.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final notifier = ref.read(securityProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Security & Privacy'),
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          SettingsSection(
            title: 'App Lock',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              ToggleableSettingsItem(
                icon: Icon(
                  Icons.lock_outline_rounded,
                  color: colorScheme.primary,
                ),
                accent: colorScheme.primary,
                title: 'Lock AniDash App',
                description: 'Require PIN to open the AniDash application',
                value: security.appLockEnabled,
                onChanged: (val) async {
                  if (val) {
                    final pin = await PinLockDialog.showSetup(
                      context: context,
                      title: 'Set App PIN',
                    );
                    if (pin != null && pin.isNotEmpty) {
                      notifier.setAppLock(true, pin);
                    }
                  } else {
                    final verified = await PinLockDialog.showUnlock(
                      context: context,
                      title: 'Verify App PIN',
                      onVerify: (pin) => notifier.verifyAppPin(pin),
                    );
                    if (verified) {
                      notifier.setAppLock(false);
                    }
                  }
                },
              ),
              if (security.appLockEnabled) ...[
                ToggleableSettingsItem(
                  icon: Icon(
                    Icons.fingerprint_rounded,
                    color: colorScheme.primary,
                  ),
                  accent: colorScheme.primary,
                  title: 'Biometric Unlock',
                  description: 'Unlock AniDash using Fingerprint or Face Lock',
                  value: security.appLockBiometrics,
                  onChanged: (val) => notifier.toggleAppLockBiometrics(val),
                ),
                NormalSettingsItem(
                  icon: Icon(
                    Icons.password_rounded,
                    color: colorScheme.primary,
                  ),
                  accent: colorScheme.primary,
                  title: 'Change App PIN',
                  description: 'Update your 4-digit AniDash PIN',
                  onTap: () async {
                    final verified = await PinLockDialog.showUnlock(
                      context: context,
                      title: 'Verify Current PIN',
                      onVerify: (pin) => notifier.verifyAppPin(pin),
                    );
                    if (verified && context.mounted) {
                      final newPin = await PinLockDialog.showSetup(
                        context: context,
                        title: 'Set New App PIN',
                      );
                      if (newPin != null && newPin.isNotEmpty) {
                        notifier.setAppLock(true, newPin);
                      }
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SettingsSection(
            title: 'Privacy Protection',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              ToggleableSettingsItem(
                icon: Icon(Icons.blur_on_rounded, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Recent Apps Privacy Blur',
                description:
                    'Blurs app content in Android app switcher preview thumbnail',
                value: security.recentAppsPrivacy,
                onChanged: notifier.toggleRecentAppsPrivacy,
              ),
              ToggleableSettingsItem(
                icon: Icon(
                  Icons.no_photography_outlined,
                  color: colorScheme.primary,
                ),
                accent: colorScheme.primary,
                title: 'Screenshot Privacy',
                description:
                    'Block screenshots & device screen capture. (Wi-Fi TV casting remains fully functional)',
                value: security.screenshotPrivacy,
                onChanged: notifier.toggleScreenshotPrivacy,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
