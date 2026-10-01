import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class SettingsSearchDelegate extends SearchDelegate<void> {
  SettingsSearchDelegate()
    : super(
        searchFieldLabel: 'Search every setting',
        keyboardType: TextInputType.text,
      );

  static const _entries = <_SettingsSearchEntry>[
    _SettingsSearchEntry(
      'Profile Settings',
      'Account',
      'AniList login account profile MyAnimeList MAL',
      '/settings/account',
      Iconsax.user,
    ),
    _SettingsSearchEntry(
      'Security & Privacy',
      'Account',
      'app lock PIN pattern password biometric fingerprint screenshot privacy auto lock',
      '/settings/security',
      Icons.security_rounded,
    ),
    _SettingsSearchEntry(
      'Content Settings',
      'Content & Playback',
      'adult content mature source persistence content filters',
      '/settings/content',
      Iconsax.setting_2,
    ),
    _SettingsSearchEntry(
      'Tracking & Sync',
      'Content & Playback',
      'AniList MAL tracking sync watch progress',
      '/settings/tracking',
      Icons.sync_rounded,
    ),
    _SettingsSearchEntry(
      'Download Settings',
      'Content & Playback',
      'download path folder quality audio dub sub concurrent downloads preference',
      '/settings/downloads',
      Iconsax.document_download,
    ),
    _SettingsSearchEntry(
      'Data & Storage',
      'Content & Playback',
      'cache clear backup restore database storage',
      '/settings/data',
      Icons.data_object,
    ),
    _SettingsSearchEntry(
      'Extensions',
      'Content & Playback',
      'sources repositories install extension anime manga',
      '/settings/extensions',
      Icons.extension_outlined,
    ),
    _SettingsSearchEntry(
      'Video Player',
      'Content & Playback',
      'auto skip intro outro filler seek buffer controls next episode playback speed fit',
      '/settings/player',
      Iconsax.video_play,
    ),
    _SettingsSearchEntry(
      'Subtitle Customization',
      'Video Player',
      'subtitle font size color background captions',
      '/settings/player/subtitles',
      Icons.subtitles_rounded,
    ),
    _SettingsSearchEntry(
      'Advanced Player Settings',
      'Video Player',
      'buffer cache MPV playback advanced',
      '/settings/player/advanced',
      Icons.tune_rounded,
    ),
    _SettingsSearchEntry(
      'Notifications',
      'Content & Playback',
      'news dub sub release reminder download update notification time',
      '/settings/notifications',
      Iconsax.notification,
    ),
    _SettingsSearchEntry(
      'Theme Settings',
      'Appearance',
      'dark light system theme accent color adaptive app logo',
      '/settings/theme',
      Iconsax.paintbucket,
    ),
    _SettingsSearchEntry(
      'Home Layout',
      'Appearance',
      'spotlight banner card style sections home customize',
      '/settings/home-layout',
      Iconsax.home_2,
    ),
    _SettingsSearchEntry(
      'UI Settings',
      'Appearance',
      'interface layout compact navigation appearance',
      '/settings/ui',
      Iconsax.mobile,
    ),
    _SettingsSearchEntry(
      'Permissions',
      'Misc',
      'notification access storage permission',
      '/settings/permissions',
      Iconsax.key,
    ),
    _SettingsSearchEntry(
      'Experimental',
      'Misc',
      'experimental beta features',
      '/settings/experimental',
      Iconsax.danger,
    ),
    _SettingsSearchEntry(
      'Check for Updates',
      'Misc',
      'update release channel automatic updates schedule',
      '/settings/update',
      Iconsax.refresh,
    ),
    _SettingsSearchEntry(
      'About AniDash',
      'Support',
      'developer Anshdeep Singh GitHub version licenses',
      '/settings/about',
      Iconsax.info_circle,
    ),
  ];

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final terms =
        query
            .toLowerCase()
            .trim()
            .split(RegExp(r'\s+'))
            .where((term) => term.isNotEmpty)
            .toList();
    final matches =
        terms.isEmpty
            ? _entries
            : _entries.where((entry) {
              final haystack =
                  '${entry.title} ${entry.section} ${entry.keywords}'
                      .toLowerCase();
              return terms.every(haystack.contains);
            }).toList();

    if (matches.isEmpty) {
      return const Center(child: Text('No matching setting found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = matches[index];
        return ListTile(
          leading: Icon(entry.icon),
          title: Text(entry.title),
          subtitle: Text(entry.section),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            close(context, null);
            context.push(entry.route);
          },
        );
      },
    );
  }
}

class _SettingsSearchEntry {
  const _SettingsSearchEntry(
    this.title,
    this.section,
    this.keywords,
    this.route,
    this.icon,
  );

  final String title;
  final String section;
  final String keywords;
  final String route;
  final IconData icon;
}
