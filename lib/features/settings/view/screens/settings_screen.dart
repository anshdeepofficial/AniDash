import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ani_dash/features/settings/view/screens/data_settings_screen.dart';
import 'package:ani_dash/shared/providers/settings/experimental_notifier.dart';
import 'package:ani_dash/features/settings/view/screens/home_settings_screen.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:go_router/go_router.dart';
import 'package:ani_dash/shared/providers/update_provider.dart';
import 'package:ani_dash/core/utils/updater.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final experimental = ref.watch(experimentalProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Settings'),
        forceMaterialTransparency: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: ListView(
          children: [
            SettingsSection(
              title: 'Account',
              titleColor: colorScheme.primary,
              onTap: () {},
              children: [
                NormalSettingsItem(
                  icon: Icon(Iconsax.user, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Profile Settings',
                  description: 'AniList integration, account preferences',
                  onTap: () => context.push('/settings/account'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SettingsSection(
              title: 'Content & Playback',
              titleColor: colorScheme.primary,
              onTap: () {},
              children: [
                NormalSettingsItem(
                  icon: Icon(Iconsax.setting_2, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Content Settings',
                  description: 'Adult content, smart source persistence',
                  onTap: () => context.push('/settings/content'),
                ),
                NormalSettingsItem(
                  icon: Icon(Icons.sync_rounded, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Tracking & Sync',
                  description: 'Manage tracking services and sync',
                  onTap: () => context.push('/settings/tracking'),
                ),
                NormalSettingsItem(
                  icon: Icon(
                    Iconsax.document_download,
                    color: colorScheme.primary,
                  ),
                  accent: colorScheme.primary,
                  title: 'Download Settings',
                  description: 'Manage download paths and behavior',
                  onTap: () => context.push('/settings/downloads'),
                ),
                NormalSettingsItem(
                  icon: Icon(Icons.data_object, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Data & Storage',
                  description: 'Clear cache, backup & restore',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DataSettingsScreen(),
                    ),
                  ),
                ),
                if (experimental.useExtensions)
                  NormalSettingsItem(
                    icon: Icon(
                      Icons.extension_outlined,
                      color: colorScheme.primary,
                    ),
                    accent: colorScheme.primary,
                    title: 'Extensions (💀)',
                    description: 'Manage your extensions',
                    onTap: () => context.push('/settings/extensions'),
                  ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.video_play, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Video Player',
                  description: 'Manage video player settings',
                  onTap: () => context.push('/settings/player'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SettingsSection(
              title: 'Appearance',
              titleColor: colorScheme.primary,
              onTap: () {},
              children: [
                NormalSettingsItem(
                  icon: Icon(Iconsax.paintbucket, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Theme Settings',
                  description: 'Customize app colors and appearance',
                  onTap: () => context.push('/settings/theme'),
                ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.home_2, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Home Layout',
                  description: 'Customize home screen sections',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeSettingsScreen(),
                    ),
                  ),
                ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.mobile, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'UI Settings',
                  description: 'Customize the interface and layout',
                  onTap: () => context.push('/settings/ui'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SettingsSection(
              title: 'Support',
              titleColor: colorScheme.primary,
              onTap: () {},
              children: [
                NormalSettingsItem(
                  icon: const Icon(Iconsax.coffee, color: Color(0xFFFFDD00)),
                  accent: const Color(0xFFFFDD00),
                  title: 'Buy Me a Coffee',
                  description: 'Support the developer directly',
                  onTap: () => launchUrl(
                    Uri.parse('https://buymeacoffee.com/anshdeepofficial'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                NormalSettingsItem(
                  icon: const Icon(Iconsax.heart, color: Color(0xFFEA4AAA)),
                  accent: const Color(0xFFEA4AAA),
                  title: 'GitHub Sponsors',
                  description: 'Sponsor the development on GitHub',
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/sponsors/anshdeepofficial'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.info_circle, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'About',
                  description: 'App information and licenses',
                  onTap: () => context.push('/settings/about'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Misc',
              titleColor: colorScheme.primary,
              onTap: () {},
              children: [
                if (experimental.debugMode)
                  NormalSettingsItem(
                    icon: Icon(Iconsax.code, color: colorScheme.primary),
                    accent: colorScheme.primary,
                    title: 'Debug Menu',
                    description: 'Developer tools and testing',
                    onTap: () => context.push('/settings/debug'),
                  ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.danger, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Experimental',
                  description: 'Few extra features',
                  onTap: () => context.push('/settings/experimental'),
                ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.key, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Permissions',
                  description: 'Manage app permissions',
                  onTap: () => context.push('/settings/permissions'),
                ),
                NormalSettingsItem(
                  icon: Icon(Iconsax.info_circle, color: colorScheme.primary),
                  accent: colorScheme.primary,
                  title: 'Check for updates',
                  description: 'Manually check for latest release',
                  onTap: () => checkForUpdates(
                    context,
                    debugMode: kDebugMode,
                    useTestReleases: experimental.useTestReleases,
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final isAuto = ref.watch(automaticUpdatesProvider);
                    final updateNotifier = ref.read(
                      automaticUpdatesProvider.notifier,
                    );
                    return ToggleableSettingsItem(
                      icon: Icon(
                        Icons.replay_outlined,
                        color: colorScheme.primary,
                      ),
                      accent: colorScheme.primary,
                      title: 'Automatic updates',
                      description: 'Automatically check for latest release',
                      value: isAuto,
                      onChanged: (val) => updateNotifier.toggle(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
