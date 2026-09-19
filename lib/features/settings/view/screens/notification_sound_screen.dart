import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ani_dash/core/models/settings/notification_sound_model.dart';
import 'package:ani_dash/core/services/notification_service.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/shared/providers/settings/notification_settings_notifier.dart';

class NotificationSoundScreen extends ConsumerStatefulWidget {
  const NotificationSoundScreen({super.key});

  @override
  ConsumerState<NotificationSoundScreen> createState() =>
      _NotificationSoundScreenState();
}

class _NotificationSoundScreenState
    extends ConsumerState<NotificationSoundScreen> {
  late final Player _player;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        setState(() {
          _currentlyPlayingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _previewSound(NotificationSoundItem sound) async {
    if (sound.assetPath == null) {
      setState(() => _currentlyPlayingId = null);
      return;
    }

    try {
      if (_currentlyPlayingId == sound.id) {
        await _player.stop();
        setState(() => _currentlyPlayingId = null);
        return;
      }

      setState(() => _currentlyPlayingId = sound.id);
      await _player.stop();
      await _player.open(Media('asset:///${sound.assetPath}'));
    } catch (e) {
      AppLogger.e('Failed to play preview', e);
      if (mounted) {
        setState(() => _currentlyPlayingId = null);
      }
    }
  }

  IconData _getIconForSound(String id) {
    switch (id) {
      case 'anime_nezuko':
        return Icons.favorite_rounded;
      case 'anime_biwa':
        return Icons.temple_buddhist_rounded;
      case 'anime_shinobu':
        return Icons.flutter_dash_rounded;
      case 'anime_tanjiro':
        return Icons.local_fire_department_rounded;
      case 'anime_gojo':
        return Icons.visibility_rounded;
      case 'anime_sukuna':
        return Icons.whatshot_rounded;
      case 'anime_denden_mushi':
        return Icons.phone_in_talk_rounded;
      case 'anime_luffy_gear5':
        return Icons.sentiment_very_satisfied_rounded;
      case 'anime_bankai':
        return Icons.flash_on_rounded;
      case 'anime_naruto_jutsu':
        return Icons.wb_sunny_rounded;
      case 'anime_ultra_instinct':
        return Icons.bolt_rounded;
      case 'anime_dbz_teleport':
        return Icons.blur_on_rounded;
      case 'anime_kono_dio_da':
      case 'anime_za_warudo':
        return Icons.hourglass_bottom_rounded;
      case 'anime_megumin':
        return Icons.emergency_share_rounded;
      default:
        return Icons.settings_suggest_rounded;
    }
  }

  Color _getBadgeColor(String anime) {
    switch (anime) {
      case 'Demon Slayer':
        return const Color(0xFFE53935); // Crimson Red
      case 'Jujutsu Kaisen':
        return const Color(0xFF8E24AA); // Purple
      case 'One Piece':
        return const Color(0xFFFFB300); // Strawhat Gold
      case 'Bleach':
        return const Color(0xFF00ACC1); // Spiritual Cyan
      case 'Naruto':
        return const Color(0xFFFF6F00); // Naruto Orange
      case 'Dragon Ball Super':
      case 'Dragon Ball Z':
        return const Color(0xFF3949AB); // Ki Blue
      case "JoJo's Bizarre Adventure":
        return const Color(0xFFD81B60); // JoJo Magenta
      case 'KonoSuba':
        return const Color(0xFFE91E63); // Explosion Crimson
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: const Text('Anime Notification Sounds'),
        forceMaterialTransparency: true,
        actions: [
          IconButton(
            tooltip: 'Send Test Notification',
            onPressed: () async {
              await NotificationService().showTestNotification(
                title: 'AniDash Notification Test',
                body:
                    'Playing anime tone: [${settings.soundItem.anime}] ${settings.soundItem.name}',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Sent test notification with "${settings.soundItem.name}"!',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kNotificationSounds.length,
        itemBuilder: (context, index) {
          final sound = kNotificationSounds[index];
          final isSelected = sound.id == settings.soundId;
          final isPlaying = _currentlyPlayingId == sound.id;
          final badgeColor = _getBadgeColor(sound.anime);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  notifier.setSound(sound.id);
                  _previewSound(sound);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Sound category icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForSound(sound.id),
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title & description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sound.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (!sound.isDefault) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: badgeColor.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      sound.anime,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              sound.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play / Preview Button
                      if (sound.assetPath != null)
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: isPlaying
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: isPlaying
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                          ),
                          icon: Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 22,
                          ),
                          onPressed: () => _previewSound(sound),
                        ),
                      const SizedBox(width: 4),
                      // Selection Indicator
                      Radio<String>(
                        value: sound.id,
                        groupValue: settings.soundId,
                        activeColor: colorScheme.primary,
                        onChanged: (val) {
                          if (val != null) {
                            notifier.setSound(val);
                            _previewSound(sound);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Tone',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${settings.soundItem.name} (${settings.soundItem.anime})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await NotificationService().showTestNotification(
                    title: 'AniDash Notification Test',
                    body:
                        'Playing [${settings.soundItem.anime}] ${settings.soundItem.name}',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Test notification sent! Playing: ${settings.soundItem.name}',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active, size: 18),
                label: const Text('Test Tone'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
