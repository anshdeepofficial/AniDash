import 'dart:async';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/models/settings/notification_sound_model.dart';
import 'package:ani_dash/core/utils/app_logger.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final prefs = await SharedPreferences.getInstance();
  final version = response.payload?.replaceFirst('update:', '').trim() ?? '';
  if (response.actionId == 'update_remind_1h') {
    await prefs.setInt(
      'remind_update_after',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    if (version.isNotEmpty) {
      await prefs.setString('remind_update_version', version);
    }
  } else if (response.actionId == 'update_skip_day') {
    await prefs.setInt(
      'remind_update_after',
      DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
    );
    if (version.isNotEmpty) {
      await prefs.setString('remind_update_version', version);
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> playbackActionController =
      StreamController<String>.broadcast();
  Stream<String> get onPlaybackAction => playbackActionController.stream;

  final StreamController<String> updateTapController =
      StreamController<String>.broadcast();
  Stream<String> get onUpdateTapped => updateTapController.stream;

  static const String _iconName = '@drawable/ic_notification';
  static const String _largeIconName = '@drawable/ic_notification_large';
  static const Color _brandColor = Color(0xFF4CAF50);

  Future<NotificationSoundItem> _getActiveSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundId = prefs.getString('notification_sound_id') ?? 'anidash_biwa';
      return kNotificationSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => kNotificationSounds.first,
      );
    } catch (_) {
      return kNotificationSounds.first;
    }
  }

  Future<void> initialize({bool isBackground = false}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(_iconName);

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'AniDash',
          appUserModelId: 'RoshanKumar.AniDash.App.v2',
          guid: '0516d984-72bf-47d4-bfbc-b2b8fd563479',
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
          windows: initializationSettingsWindows,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final prefs = await SharedPreferences.getInstance();
        final version = response.payload?.replaceFirst('update:', '').trim() ?? '';
        if (response.actionId == 'update_remind_1h') {
          await prefs.setInt(
            'remind_update_after',
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
          );
          if (version.isNotEmpty) {
            await prefs.setString('remind_update_version', version);
          }
        } else if (response.actionId == 'update_skip_day') {
          await prefs.setInt(
            'remind_update_after',
            DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
          );
          if (version.isNotEmpty) {
            await prefs.setString('remind_update_version', version);
          }
        } else if (response.actionId == 'update_now' ||
            (response.payload?.startsWith('update:') == true && response.actionId == null)) {
          _instance.updateTapController.add(version);
        } else if (response.actionId != null) {
          _instance.playbackActionController.add(response.actionId!);
        }
        AppLogger.infoPair('Notification tapped', response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createNotificationChannels();
    if (!isBackground) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> ensureSoundChannelsCreated([String? soundId]) async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    String activeSoundId = soundId ?? 'anidash_biwa';
    if (soundId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        activeSoundId = prefs.getString('notification_sound_id') ?? 'anidash_biwa';
      } catch (_) {}
    }

    final soundItem = kNotificationSounds.firstWhere(
      (s) => s.id == activeSoundId,
      orElse: () => kNotificationSounds.first,
    );

    final sound = (!soundItem.isDefault && soundItem.rawResName != null)
        ? RawResourceAndroidNotificationSound(soundItem.rawResName!)
        : null;

    final newsChannel = AndroidNotificationChannel(
      'AniDash_news_${soundItem.id}',
      'AniDash News',
      description: 'Notifications for latest anime news',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: sound,
    );

    final episodeChannel = AndroidNotificationChannel(
      'AniDash_episodes_${soundItem.id}',
      'Episode Releases',
      description: 'Notifications when new Sub or Dub episodes are released',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: sound,
    );

    final updateChannel = AndroidNotificationChannel(
      'AniDash_updates_${soundItem.id}',
      'App Updates',
      description: 'Notifications when a new AniDash version is available',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: sound,
    );

    final reminderChannel = AndroidNotificationChannel(
      'AniDash_reminders_${soundItem.id}',
      'Continue Watching Reminders',
      description: 'Reminders to continue watching your paused anime',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
      sound: sound,
    );

    await androidImplementation?.createNotificationChannel(newsChannel);
    await androidImplementation?.createNotificationChannel(episodeChannel);
    await androidImplementation?.createNotificationChannel(updateChannel);
    await androidImplementation?.createNotificationChannel(reminderChannel);
  }

  Future<void> _createNotificationChannels() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    // Delete deprecated v1 channels to migrate to custom sound channels
    try {
      await androidImplementation?.deleteNotificationChannel('AniDash_news_channel');
      await androidImplementation?.deleteNotificationChannel('AniDash_episodes_channel');
      await androidImplementation?.deleteNotificationChannel('AniDash_updates_channel');
      await androidImplementation?.deleteNotificationChannel('AniDash_news_channel_v2');
      await androidImplementation?.deleteNotificationChannel('AniDash_episodes_channel_v2');
      await androidImplementation?.deleteNotificationChannel('AniDash_updates_channel_v2');
    } catch (_) {}

    const AndroidNotificationChannel downloadChannel =
        AndroidNotificationChannel(
          'AniDash_downloads_channel',
          'Downloads',
          description: 'Download progress and completed status',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

    const AndroidNotificationChannel playbackChannel =
        AndroidNotificationChannel(
          'AniDash_playback_channel',
          'Media Playback',
          description:
              'Controls for active media playback and lock screen controls',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

    await androidImplementation?.createNotificationChannel(downloadChannel);
    await androidImplementation?.createNotificationChannel(playbackChannel);

    await ensureSoundChannelsCreated();
  }

  AndroidNotificationDetails _buildAndroidDetails({
    required String channelBaseId,
    required String channelName,
    required String channelDescription,
    required NotificationSoundItem soundItem,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    bool playSound = true,
    bool enableVibration = true,
    List<AndroidNotificationAction>? actions,
    StyleInformation? styleInformation,
    Color? color,
  }) {
    final sound = (playSound && !soundItem.isDefault && soundItem.rawResName != null)
        ? RawResourceAndroidNotificationSound(soundItem.rawResName!)
        : null;
    final channelId = playSound
        ? '${channelBaseId}_${soundItem.id}'
        : channelBaseId;

    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: enableVibration,
      sound: sound,
      icon: _iconName,
      largeIcon: const DrawableResourceAndroidBitmap(_largeIconName),
      color: color ?? _brandColor,
      actions: actions,
      styleInformation: styleInformation,
    );
  }

  Future<void> showTestNotification({String? title, String? body}) async {
    final soundItem = await _getActiveSound();
    await ensureSoundChannelsCreated(soundItem.id);

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_updates',
        channelName: 'App Updates',
        channelDescription: 'Notifications when a new AniDash version is available',
        soundItem: soundItem,
        styleInformation: BigTextStyleInformation(
          body ?? 'Playing tone: "${soundItem.name}". Notification sound is active!',
          contentTitle: title ?? 'AniDash Notification Test',
        ),
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      8888,
      title ?? 'AniDash Notification Test',
      body ?? 'Playing tone: "${soundItem.name}". Notification sound is active!',
      details,
    );
  }

  Future<void> showNewsNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final soundItem = await _getActiveSound();
    await ensureSoundChannelsCreated(soundItem.id);

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_news',
        channelName: 'AniDash News',
        channelDescription: 'Notifications for latest anime news',
        soundItem: soundItem,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      1000,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> showDownloadProgressNotification({
    required int id,
    required String animeTitle,
    required int episodeNumber,
    required double progress,
  }) async {
    final percent = (progress * 100).clamp(0, 100).toInt();
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_downloads_channel',
          'Downloads',
          channelDescription: 'Download progress and completed status',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          icon: _iconName,
          largeIcon: const DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      'Downloading EP $episodeNumber - $animeTitle',
      '$percent% completed',
      platformChannelSpecifics,
    );
  }

  Future<void> showDownloadCompletedNotification({
    required int id,
    required String animeTitle,
    required int episodeNumber,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_downloads_channel',
          'Downloads',
          channelDescription: 'Download progress and completed status',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          icon: _iconName,
          largeIcon: DrawableResourceAndroidBitmap(_largeIconName),
          color: _brandColor,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      'Download Complete',
      '$animeTitle - Episode $episodeNumber is ready to watch offline',
      platformChannelSpecifics,
    );
  }

  Future<void> showEpisodeReleaseNotification({
    required String animeTitle,
    required int episodeNumber,
    bool isDub = false,
  }) async {
    final soundItem = await _getActiveSound();
    await ensureSoundChannelsCreated(soundItem.id);

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_episodes',
        channelName: 'Episode Releases',
        channelDescription:
            'Notifications when new Sub or Dub episodes are released',
        soundItem: soundItem,
      ),
    );

    final type = isDub ? 'dub ' : '';
    await flutterLocalNotificationsPlugin.show(
      animeTitle.hashCode ^ episodeNumber,
      'New ${type.toUpperCase()}Episode Released!',
      'New ${type}episode $episodeNumber of $animeTitle has been released. You can watch on AniDash.',
      platformChannelSpecifics,
    );
  }

  Future<void> showContinueWatchingNotification({
    required String animeTitle,
    required int episodeNumber,
  }) async {
    final soundItem = await _getActiveSound();
    await ensureSoundChannelsCreated(soundItem.id);

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_reminders',
        channelName: 'Continue Watching Reminders',
        channelDescription:
            'Reminders to continue watching your paused anime',
        soundItem: soundItem,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      animeTitle.hashCode,
      'Continue Watching',
      'You stopped at Episode $episodeNumber of $animeTitle. Watch more on AniDash!',
      platformChannelSpecifics,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> showUpdateAvailableNotification(String version) async {
    final soundItem = await _getActiveSound();
    await ensureSoundChannelsCreated(soundItem.id);

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_updates',
        channelName: 'App Updates',
        channelDescription:
            'Notifications when a new AniDash version is available',
        soundItem: soundItem,
        styleInformation: const BigTextStyleInformation(
          'A new version has been released on GitHub. Tap to update or snooze.',
          contentTitle: 'AniDash Update Available',
          summaryText: 'New version available',
        ),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'update_now',
            'Update Now',
            cancelNotification: true,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'update_remind_1h',
            'Remind in 1h',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'update_skip_day',
            'Skip for today',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );
    await flutterLocalNotificationsPlugin.show(
      1901,
      'AniDash v$version is available',
      'A new version has been released on GitHub. Tap to update or snooze.',
      details,
      payload: 'update:$version',
    );
  }

  Future<void> showPlaybackNotification({
    required String animeTitle,
    required String episodeTitle,
    required int episodeNumber,
    required bool isPlaying,
    String? posterUrl,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'AniDash_playback_channel',
          'Media Playback',
          channelDescription:
              'Controls for active media playback and lock screen controls',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          color: const Color(0xFFE91E63),
          icon: _iconName,
          styleInformation: const MediaStyleInformation(
            htmlFormatContent: false,
            htmlFormatTitle: false,
          ),
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'prev',
              'Previous',
              cancelNotification: false,
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'play_pause',
              isPlaying ? 'Pause' : 'Play',
              cancelNotification: false,
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'next',
              'Next',
              cancelNotification: false,
              showsUserInterface: false,
            ),
          ],
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      9999,
      '$animeTitle - EP $episodeNumber',
      episodeTitle,
      platformChannelSpecifics,
    );
  }

  Future<void> hidePlaybackNotification() async {
    await flutterLocalNotificationsPlugin.cancel(9999);
  }
}
