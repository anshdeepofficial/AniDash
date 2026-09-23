import 'dart:async';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ani_dash/core/utils/app_logger.dart';
import 'package:ani_dash/core/services/notification_inbox_service.dart';

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
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await prefs.setInt('remind_update_after', tomorrow.millisecondsSinceEpoch);
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
        final version =
            response.payload?.replaceFirst('update:', '').trim() ?? '';
        if (response.actionId == 'update_remind_1h') {
          await prefs.setInt(
            'remind_update_after',
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
          );
          if (version.isNotEmpty) {
            await prefs.setString('remind_update_version', version);
          }
        } else if (response.actionId == 'update_skip_day') {
          final now = DateTime.now();
          final tomorrow = DateTime(now.year, now.month, now.day + 1);
          await prefs.setInt(
            'remind_update_after',
            tomorrow.millisecondsSinceEpoch,
          );
          if (version.isNotEmpty) {
            await prefs.setString('remind_update_version', version);
          }
        } else if (response.actionId == 'update_now' ||
            (response.payload?.startsWith('update:') == true &&
                response.actionId == null)) {
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

  Future<void> ensureSoundChannelsCreated([String? ignoredSoundId]) async {
    final androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    const newsChannel = AndroidNotificationChannel(
      'AniDash_news',
      'AniDash News',
      description: 'Notifications for latest anime news',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const episodeChannel = AndroidNotificationChannel(
      'AniDash_episodes',
      'Episode Releases',
      description: 'Notifications when new Sub or Dub episodes are released',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const updateChannel = AndroidNotificationChannel(
      'AniDash_updates',
      'App Updates',
      description: 'Notifications when a new AniDash version is available',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      'AniDash_reminders',
      'Continue Watching Reminders',
      description: 'Reminders to continue watching your paused anime',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
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
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_news_channel',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_episodes_channel',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_updates_channel',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_news_channel_v2',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_episodes_channel_v2',
      );
      await androidImplementation?.deleteNotificationChannel(
        'AniDash_updates_channel_v2',
      );
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
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    bool playSound = true,
    bool enableVibration = true,
    List<AndroidNotificationAction>? actions,
    StyleInformation? styleInformation,
    Color? color,
  }) {
    return AndroidNotificationDetails(
      channelBaseId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: enableVibration,
      icon: _iconName,
      largeIcon: const DrawableResourceAndroidBitmap(_largeIconName),
      color: color ?? _brandColor,
      actions: actions,
      styleInformation: styleInformation,
    );
  }

  Future<void> showTestNotification({String? title, String? body}) async {
    await ensureSoundChannelsCreated();

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_updates',
        channelName: 'App Updates',
        channelDescription:
            'Notifications when a new AniDash version is available',
        styleInformation: BigTextStyleInformation(
          body ?? 'Notifications are enabled and using your system sound.',
          contentTitle: title ?? 'AniDash Notification Test',
        ),
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      8888,
      title ?? 'AniDash Notification Test',
      body ?? 'Notifications are enabled and using your system sound.',
      details,
    );
  }

  Future<void> showNewsNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await NotificationInboxService().add(
      title: title,
      body: body,
      route: payload,
      dedupeKey: 'news:${payload ?? title}',
    );
    await ensureSoundChannelsCreated();

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_news',
        channelName: 'AniDash News',
        channelDescription: 'Notifications for latest anime news',
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
    await NotificationInboxService().add(
      title: 'Download Complete',
      body: '$animeTitle - Episode $episodeNumber is ready offline',
      route: '/downloads',
      dedupeKey: 'download:$animeTitle:$episodeNumber',
    );
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
    await NotificationInboxService().add(
      title: 'New ${isDub ? 'Dub ' : 'Sub '}Episode',
      body: 'Episode $episodeNumber of $animeTitle is now available.',
      dedupeKey: 'release:$animeTitle:$episodeNumber:$isDub',
    );
    await ensureSoundChannelsCreated();

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_episodes',
        channelName: 'Episode Releases',
        channelDescription:
            'Notifications when new Sub or Dub episodes are released',
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
    await NotificationInboxService().add(
      title: 'Continue Watching',
      body: 'Resume $animeTitle from Episode $episodeNumber.',
      dedupeKey: 'continue:$animeTitle:$episodeNumber',
    );
    await ensureSoundChannelsCreated();

    final platformChannelSpecifics = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_reminders',
        channelName: 'Continue Watching Reminders',
        channelDescription: 'Reminders to continue watching your paused anime',
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
    await NotificationInboxService().add(
      title: 'AniDash v$version is available',
      body: 'A new stable version is ready to install.',
      route: '/settings/update',
      dedupeKey: 'update:$version',
    );
    await ensureSoundChannelsCreated();

    final details = NotificationDetails(
      android: _buildAndroidDetails(
        channelBaseId: 'AniDash_updates',
        channelName: 'App Updates',
        channelDescription:
            'Notifications when a new AniDash version is available',
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
