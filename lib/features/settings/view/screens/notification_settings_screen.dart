import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_item.dart';
import 'package:ani_dash/features/settings/view/widgets/settings_section.dart';
import 'package:ani_dash/shared/providers/settings/notification_settings_notifier.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Notifications'),
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          SettingsSection(
            title: 'Anime News',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              ToggleableSettingsItem(
                icon: Icon(Iconsax.document_text, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'News Notifications',
                description: 'Get notified about the latest anime news and announcements',
                value: settings.enableNews,
                onChanged: (val) => notifier.updateSettings(
                  (s) => s.copyWith(enableNews: val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SettingsSection(
            title: 'Episode Releases',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              ToggleableSettingsItem(
                icon: Icon(Iconsax.video_play, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'New Episode Alerts',
                description: 'Notify when new episodes of your watching anime are available',
                value: settings.enableEpisodeReleases,
                onChanged: (val) => notifier.updateSettings(
                  (s) => s.copyWith(enableEpisodeReleases: val),
                ),
              ),
              ToggleableSettingsItem(
                icon: Icon(Iconsax.translate, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Dub Releases',
                description: 'Receive notifications when English/Hindi dubs release',
                value: settings.enableDubReleases,
                onChanged: (val) => notifier.updateSettings(
                  (s) => s.copyWith(enableDubReleases: val),
                ),
              ),
              ToggleableSettingsItem(
                icon: Icon(Icons.subtitles_rounded, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Sub Releases',
                description: 'Receive notifications when Japanese sub releases',
                value: settings.enableSubReleases,
                onChanged: (val) => notifier.updateSettings(
                  (s) => s.copyWith(enableSubReleases: val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SettingsSection(
            title: 'Reminders & Downloads',
            titleColor: colorScheme.primary,
            onTap: () {},
            children: [
              ToggleableSettingsItem(
                icon: Icon(Iconsax.clock, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Continue Watching Reminders',
                description: 'Reminds you: "You stopped here, watch more!" for paused shows',
                value: settings.enableContinueWatching,
                onChanged: (val) => notifier.updateSettings(
                  (s) => s.copyWith(enableContinueWatching: val),
                ),
              ),
              ToggleableSettingsItem(
                icon: Icon(Iconsax.document_download, color: colorScheme.primary),
                accent: colorScheme.primary,
                title: 'Download Notifications',
                description: 'Show live download progress and completion notifications',
                value: settings.enableDownloads,
                onChanged: (val) => notifier.updateSettings(
                  (s) => s.copyWith(enableDownloads: val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
